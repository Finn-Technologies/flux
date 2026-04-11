# Flux

**Flux** is a private, offline-first AI assistant that runs local language models directly on your Android device. No accounts, no cloud, no data leaving your phone.

> **Status:** Core UI scaffold complete. On-device inference and Hugging Face API integration are scaffolded with `TODO` comments, ready for implementation.

---

## Features

### Chat
A full conversational interface with streaming responses. Conversations are saved locally and accessible via a slide-up panel. Attach photos, documents, or use your camera. Pick which downloaded model to chat with.

### Assistant
A voice-first quick-action layer. Tap to speak and execute common tasks like setting timers, summarizing pages, toggling the flashlight, or creating notes. Works completely offline.

### Model Library
Browse available models with search and capability filters. View model details including size, speed, and quality metrics.

### Downloads
Track storage usage and manage downloaded models. Monitor download progress with pause/resume controls.

### Settings
Clear cache and view app information.

---

## Technical Overview

```
lib/
├── main.dart                          # App entry, Material 3 theme, GoRouter, onboarding
├── core/
│   ├── models/
│   │   └── hf_model.dart              # Model data class
│   ├── services/
│   │   ├── hf_api_service.dart        # HF API client (TODO: implement)
│   │   ├── inference_service.dart       # Streaming inference (TODO: implement)
│   │   └── model_manager.dart          # Model lifecycle (TODO: implement)
│   └── widgets/
│       ├── flux_shell.dart             # Navigation shell with bottom nav
│       ├── flux_drawer.dart            # Side drawer navigation
│       └── model_card.dart             # Model library card
├── features/
│   ├── onboarding/                   # Onboarding + model selection
│   ├── chat/                         # Chat UI with conversation history
│   ├── assistant/                    # Voice quick actions
│   ├── models/                       # Model library browser
│   ├── downloads/                    # Download management
│   └── settings/                     # App settings
└── l10n/                            # English + Italian localization
```

### Stack

| Concern | Choice |
|---|---|
| Framework | Flutter |
| State | Riverpod (`StateNotifier`, `StateProvider`) |
| Navigation | go_router |
| Persistence | Hive / SharedPreferences scaffolded |
| Theming | Material 3, `ThemeMode.system` (adaptive light/dark) |
| Downloads | background_downloader scaffolded |
| Voice | speech_to_text + record scaffolded |

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

- **No account** — Flux never asks for email, phone, or any identifying information
- **100% on-device** — All inference, storage, and processing happens locally
- **Zero telemetry** — No analytics, no crash reporting, no external services
- **Open source** — Full source available for audit

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
| `flutter_animate` | ^4.5.0 | UI animations |

---

## License

MIT License — see [LICENSE](LICENSE) for details.
