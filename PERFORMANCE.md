# Flux performance improvements

This document summarizes the performance work focused on **low-tier devices**,
where the app previously suffered from janky/missing animations, slow loading,
and very slow inference.

## What was changed

### 1. Inference: stop flushing on every single token
`lib/core/services/inference_service.dart`

The main chat path (`streamChat`) generated with
`streamBatchTokenThreshold: 1` / `streamBatchByteThreshold: 1`, meaning **every
single token** crossed the native (llama.cpp) -> Dart boundary and triggered
downstream work. On low-end CPUs the marshalling + UI churn cost more than the
actual token generation, so throughput collapsed and the device thermally
throttled.

Tokens are now batched (`6` tokens / `256` bytes per flush). Streaming still
looks live, but per-token overhead drops by roughly an order of magnitude.

### 2. UI: throttle streaming text updates to ~20fps
`lib/features/chat/chat_screen.dart`

The streaming bubble rebuilt with the **entire growing response** on every
token. Combined with #1 this saturated the UI thread, which is why animations
"sometimes don't play" — the frame pipeline never got a free frame. Updates are
now coalesced to at most one every 50ms, with a final flush so the complete
text is always shown. The text the user sees is unchanged.

### 3. Animations: make always-on full-screen backdrops adaptive
`lib/core/services/performance_service.dart` (new),
`lib/core/widgets/flux_widgets.dart`, `lib/core/widgets/flux_animations.dart`,
`lib/main.dart`

Two effects repainted the **entire screen every frame for the whole lifetime of
the screen**:

- `FluxBackdrop` — the drifting aurora behind the chat screen (a 28s loop that
  never stops).
- `FluxAuraBackground` — the onboarding aura (an 83ms timer redrawing two
  full-screen radial gradients).

These are the biggest cause of constant frame drops and battery drain on weak
GPUs, and they steal the frames that interactive animations need. A new
`PerformanceService` detects the device tier once at startup (RAM <= 4 GB on
mobile = low tier). On low-tier devices these backdrops now render **statically**
instead of animating; on capable hardware they animate exactly as before.

Net effect on low-end devices: the constant background load is removed, so page
transitions, taps, and the typing indicator get the frames they need and play
smoothly.

### 4. Prompt evaluation: do not submit the newest message twice
`lib/features/chat/chat_screen.dart`

The composer adds the current user message to Riverpod before starting
inference. That same message was then copied into `history` and also supplied
as the new `prompt`, so every turn evaluated the newest prompt twice. The
history builder now excludes that visible, just-added message. This reduces
prompt work, context consumption, and improves llama.cpp prefix-cache reuse.

### 5. Model runtime: tier batches, threads, and context by hardware
`lib/core/services/inference_service.dart`

- <=4 GB mobile devices use 128/64 batch and micro-batch sizes.
- 5-8 GB devices use 256/128; larger devices retain the throughput-oriented
  desktop settings.
- Generation threads leave CPU headroom for Flutter's UI and raster threads.
- The lightweight model now correctly receives the 4096-token mid-tier
  context profile (its file is about 533 MB; the previous 300 MB cutoff could
  never match it).
- Native-to-Dart token batches and UI flush cadence scale with device tier.

### 6. Scrolling and entrances: remove avoidable low-tier layers
`lib/features/chat/chat_screen.dart`,
`lib/core/widgets/flux_animations.dart`

Constrained phones skip the conversation-wide `ShaderMask` save-layer and
staggered entrance controllers. Content and interaction remain identical; the
decorative edge fade and entrance motion remain enabled on capable devices.

## Validation

`flutter analyze` completes without errors. Actual speedup varies by model,
prompt length, quantization, thermal state, and device. A 3x claim must be
validated on target hardware using release/profile builds and the existing
prompt/output token-per-second metrics; it cannot be guaranteed from static
analysis or a desktop build.

## Recommended follow-ups

These need a device/SDK to validate and were intentionally left out to keep the
build safe:

- **Run model load off the UI isolate** (or show a determinate progress state)
  so the first-load stall doesn't freeze the UI.
- **Lower `batchSize`/`microBatchSize` on <=4 GB devices** if you observe
  prompt-processing OOM pressure (trades a little prompt speed for stability).

### Follow-up completed

- **Gate the remaining decorative `..repeat()` controllers** (`you_screen.dart`,
  parts of `voice_screen.dart`) — `you_screen.dart`'s orbit and central-pulse
  controllers were already gated behind `isLowEnd`; the voice orb's continuous
  phase loop (`voice_screen.dart`) now follows the same `isConstrained` gate as
  the aurora backdrops, so on phones the orb renders once at its rest position
  instead of repainting its `CustomPainter` every frame.
