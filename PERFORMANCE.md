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

## Recommended follow-ups (not applied here)

These need a device/SDK to validate and were intentionally left out to keep the
build safe:

- **Inference thread count.** Pin llama.cpp to the number of *performance*
  cores (e.g. `Platform.numberOfProcessors`, clamped, minus the little cores)
  via the `llamadart` model/generation params. Letting it spread across
  efficiency cores hurts both speed and thermals on big.LITTLE phones. Confirm
  the exact `ModelParams` field name against the installed `llamadart` version
  before wiring it up.
- **Run model load off the UI isolate** (or show a determinate progress state)
  so the first-load stall doesn't freeze the UI.
- **Gate the remaining decorative `..repeat()` controllers** (`you_screen.dart`,
  parts of `voice_screen.dart`) behind `PerformanceService.isLowEnd` the same
  way as the backdrops.
- **Lower `batchSize`/`microBatchSize` on <=4 GB devices** if you observe
  prompt-processing OOM pressure (trades a little prompt speed for stability).
