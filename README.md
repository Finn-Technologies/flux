# Flux

**Flux** is an offline-first, private AI assistant that runs local Hugging Face models directly on your Android device. No accounts, no cloud, no data leaving your phone.

Unlike cloud-based AI apps, Flux downloads compact language models to your device and runs inference locally — meaning your conversations are never sent to any server. It targets Android 10+ (SDK 29+) with a modern Material 3 interface and supports English and Italian out of the box.

> ⚠️ **Status:** This is a complete UI scaffold with mock data. Real on-device inference (via `llama.cpp` / `fllama` / `mlc-llm`) and Hugging Face API integration are stubbed with `TODO` comments, ready to be implemented.

---

## What Flux Does

**Chat** — A full conversational interface where you can chat with a local model. Send text messages, attach photos or documents, pick which downloaded model to use, and get streaming responses. Conversations are persisted locally.

**Assistant** — A voice-first shortcut layer for common actions: set a timer, summarize a page, toggle the flashlight, or create a quick note. Works without any network connection.

**Model Library** — Browse and filter available Hugging Face models by capability (Chat, Vision, Audio, Tools). See size, speed, and quality ratings before downloading.

**Downloads** — Manage your downloaded models. See storage usage, track download progress, and pause or resume downloads at any time.

**Settings** — Control storage (clear cache, delete models), switch language, and view app info.

**Onboarding** — A 3-slide intro followed by a model picker on first launch. Skips automatically on return visits.

---

## Technical Overview

```
lib/
├── main.dart                          # App entry, Material 3 theme, GoRouter, onboarding gate
├── core/
│   ├── services/
│   │   ├── hf_api_service.dart        # Stubbed HF API client (TODO: huggingface_hub)
│   │   ├── inference_service.dart     # Stubbed streaming inference (TODO: llama.cpp)
│   │   └── model_manager.dart         # Stubbed model lifecycle (TODO: background_downloader)
│   └── widgets/
│       ├── flux_drawer.dart           # Full-screen sidebar navigation
│       ├── chat_bubble.dart            # Chat message bubble
│       └── model_card.dart             # Model library card with metrics
├── constants/
│   └── mock_models.dart               # 8 mock HFModel instances
├── features/
│   ├── onboarding/                    # 3-slide intro + model picker
│   ├── chat/                          # Conversational UI + Riverpod state
│   ├── assistant/                     # Voice-first quick actions
│   ├── models/                        # Browse / search / filter models
│   ├── downloads/                      # Download queue + storage overview
│   └── settings/                       # Storage, language, about
└── l10n/                             # English + Italian ARB localization
```

### Stack
| Concern | Choice |
|---|---|
| Framework | Flutter |
| State | Riverpod (`StateNotifier`, `StateProvider`) |
| Navigation | go_router (7 routes) |
| Persistence | Hive / SharedPreferences scaffolded |
| Theming | Material 3, `ThemeMode.system` (OS-adaptive) |
| Downloads | background_downloader (scaffolded) |
| Voice input | speech_to_text + record (scaffolded) |

---

## Getting Started

```bash
# Clone
git clone https://github.com/Finn-Technologies/flux.git
cd flux

# Install dependencies
flutter pub get

# Run
flutter run
```

```bash
# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

---

## Privacy by Design

- **No account** — Flux never asks for an email, phone number, or any identifying information
- **100% on-device** — All inference, storage, and processing happens locally
- **Zero telemetry** — No analytics, no crash reporting, no external services of any kind
- **Open source** — The full source is here for anyone to audit

---

## Roadmap

- [ ] Integrate `huggingface_hub` for real HF API access
- [ ] Integrate `llama.cpp` / `fllama` / `mlc-llm` for on-device inference
- [ ] Wire up `background_downloader` for real model downloads
- [ ] Wire up `speech_to_text` for real voice input
- [ ] Persist chat history with Hive
- [ ] Add image upload support for vision models

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.1.0 | State management |
| `go_router` | ^6.0.0 | Declarative routing |
| `hive_flutter` | ^1.1.0 | Local persistence |
| `shared_preferences` | ^2.2.0 | Key-value settings |
| `background_downloader` | ^9.5.4 | Background downloads |
| `file_picker` | ^9.0.0 | Attachment file picking |
| `record` | ^6.2.0 | Audio recording |
| `speech_to_text` | ^7.0.0 | Voice input |
| `flutter_localizations` | SDK | i18n (EN/IT) |

---

## License

MIT License — see [LICENSE](LICENSE) for details.
