# Flux

**Flux** is an offline-first, privacy-focused mobile AI chat application built with Flutter. All conversations and model interactions happen entirely on-device — no data ever leaves your phone. Flux is designed for users who want the power of AI without sacrificing privacy.

> ⚠️ **Status:** This repository contains the complete UI scaffold and mock data implementation. Real Hugging Face model integration (via `llama.cpp` / `fllama` / `mlc-llm`) and actual on-device inference are stubbed out with `TODO` placeholders, ready to be wired up.

---

## Features

### Chat Mode
- Full conversational UI with streaming mock responses
- Prompt presets on the welcome screen for quick-start conversations
- Message bubbles with sender avatars, timestamps, and auto-scroll
- Attachment support: attach photos, documents, or capture from camera via a bottom sheet
- Model selector in the app bar (tap to switch between downloaded models)
- Clear chat action

### Assistant Mode
- Voice-first interface with a large, animated mic button
- Pulsing glow effect while listening, with "Tap to stop" hint
- Quick action grid: Set a timer, Summarize, Flashlight, Quick note
- Action history with timestamped result cards
- Works entirely offline — no network required for local actions

### Model Library
- Browse available Hugging Face models with search and capability filters (Chat, Vision, Audio, Tools)
- Model cards displaying: name, size, description, capability tags, speed & quality bars
- Install / Use / Delete / Pause actions per model

### Downloads
- Visual storage bar showing used vs. free space
- Active download list with progress indicators
- Pause / resume / cancel download controls
- Completed models marked "Ready to use"

### Settings
- Storage management: view usage, clear cache, delete all models
- Language selection: English / Italiano (via ARB localization files)
- About sheet with version info

### Onboarding
- 3-slide introduction explaining Flux's privacy-first approach
- Model selection screen to pick a default model before first use
- Skips automatically on subsequent launches (persisted via `SharedPreferences`)

---

## Architecture

```
lib/
├── main.dart                          # App entry, theme, GoRouter, onboarding gate
├── core/
│   ├── services/
│   │   ├── hf_api_service.dart        # Stubbed Hugging Face API client
│   │   ├── inference_service.dart     # Stubbed streaming inference engine
│   │   └── model_manager.dart         # Stubbed model download & lifecycle manager
│   └── widgets/
│       ├── flux_drawer.dart           # Full-screen sidebar navigation
│       ├── chat_bubble.dart            # Reusable chat bubble widget
│       └── model_card.dart             # Model library card widget
├── constants/
│   └── mock_models.dart               # 8 mock HFModel instances with realistic data
├── features/
│   ├── onboarding/
│   │   ├── onboarding_page.dart       # 3-slide intro
│   │   └── choose_model_screen.dart   # First-launch model picker
│   ├── chat/
│   │   └── chat_screen.dart           # Chat UI + Riverpod state
│   ├── assistant/
│   │   └── assistant_screen.dart      # Voice-first assistant UI
│   ├── models/
│   │   └── model_library_screen.dart  # Browse / search / filter models
│   ├── downloads/
│   │   └── downloads_screen.dart      # Download queue & storage management
│   └── settings/
│       └── settings_screen.dart        # Storage, language, about
└── l10n/
    ├── app_localizations.dart          # Generated localization delegate
    ├── en.arb                          # English strings
    └── it.arb                           # Italian strings
```

### State Management
- **Riverpod** for global state (`chatMessagesProvider`, `isStreamingProvider`, `localeProvider`)
- Chat state lives in a `StateNotifier` so the New Chat button in the drawer can clear it from any screen

### Navigation
- **go_router** with routes: `/` (redirect), `/onboarding`, `/home` (Chat), `/assistant`, `/models`, `/downloads`, `/settings`
- FluxDrawer uses `context.go()` for navigation after closing

### Theming
- **Material 3** with `ThemeMode.system` — adapts automatically to OS light/dark setting
- Dark mode is the default and intended experience
- Consistent appBar styling (icon + title), card borders, and color tokens across all screens

---

## Getting Started

### Prerequisites
- Flutter SDK 3.x
- Android SDK (API 29+)
- Dart 3.x

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/flux.git
cd flux

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Build APK

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-debug.apk`.

---

## Privacy

Flux is built with privacy as a first-class concern:

- **No account required** — no sign-up, no email, no phone number
- **All data stays on-device** — messages, models, and preferences are stored locally
- **No telemetry** — no analytics, no crash reporting, no external services
- **Open source** — inspect the code to verify the claims

---

## Roadmap

- [ ] Wire up `huggingface_hub` package for real HF API access
- [ ] Integrate `llama.cpp` / `fllama` / `mlc-llm` for on-device inference
- [ ] Implement real model downloads via `background_downloader`
- [ ] Add real speech-to-text via `speech_to_text` package
- [ ] Persist chat history with Hive or Isar
- [ ] Add image upload / vision model support
- [ ] iOS support (currently Android-only in scaffold)

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.1.0 | State management |
| `go_router` | ^6.0.0 | Declarative routing |
| `hive_flutter` | ^1.1.0 | Local persistence (scaffold) |
| `shared_preferences` | ^2.2.0 | Simple key-value storage |
| `background_downloader` | ^9.5.4 | Background model downloads |
| `file_picker` | ^9.0.0 | Attachment file picking |
| `record` | ^6.2.0 | Audio recording |
| `speech_to_text` | ^7.0.0 | Voice input |
| `flutter_localizations` | SDK | i18n support |

---

## License

MIT License — see [LICENSE](LICENSE) for details.
