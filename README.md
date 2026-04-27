<div align="center">
  <img src="assets/icon/app_icon.png" width="100" alt="Flux Logo">
  <h1 align="center">Flux</h1>
  <p align="center">Your private AI assistant — entirely on-device, entirely yours.</p>

  <p align="center">
    <a href="https://github.com/Finn-Technologies/flux/releases"><img src="https://img.shields.io/badge/version-0.1.6-blue.svg" alt="Version"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
  </p>
</div>

---

## Overview

Flux is a **fully offline AI assistant** for Android. It runs quantized LLMs directly on your device using `llamadart` (llama.cpp bindings). No accounts, no cloud, no data leaving your phone — ever.

But it can also **search the web** when you want it to, combining the privacy of local inference with the freshness of live search results.

---

## Features

### Offline AI Chat

| Model | Size | RAM | What it's good at |
|-------|------|-----|-------------------|
| **Flux Lite** | 533 MB | 4 GB+ | Quick answers, low-end devices |
| **Flux Creative** | 890 MB | 4 GB+ | HTML/CSS/JS mini-app generation |
| **Flux Steady** | 1.3 GB | 6 GB+ | Balanced reasoning and speed |
| **Flux Smart** | 2.7 GB | 8 GB+ | Complex reasoning, deep analysis |

All models are GGUF quantizations of **Qwen 3.5**, downloaded directly from Hugging Face inside the app.

### Web Search

Toggle the globe icon in the chat bar and Flux will:
1. Fetch live results from DuckDuckGo
2. Inject them into the model's context as authoritative sources
3. Show a **"Searched"** badge and the actual **source chips** you can tap

When search is off, everything runs 100% offline.

### App Builder ("Creations")

Describe an HTML/CSS/JS mini-app in natural language and Flux Creative will build it. The app gets a live preview, auto-saves to your collection, and you can run, edit, or delete creations.

### Conversation History

Every chat auto-saves. The history sidebar lets you browse, rename, or delete past conversations. When you tap an old chat, the model used for that conversation is automatically restored.

### Context Management

Flux compacts its context window every 4 messages — older turns are summarized so the prompt stays lean. The model never claims it "doesn't remember" because its system prompt explicitly tells it: *"You have perfect memory of this conversation."*

### Long Responses Without Crashing

Streaming is throttled to ~6 UI updates per second instead of hundreds. Responses longer than 8,000 tokens automatically continue in the background (up to 3 continuations) so no output gets cut off.

### Localized UI

The entire interface is translated into **6 languages**:

| Language | Locale |
|----------|--------|
| English | `en` |
| Spanish | `es` |
| French | `fr` |
| German | `de` |
| Italian | `it` |
| Chinese | `zh` |

---



## Getting Started

### Prerequisites

- Android device with **4 GB+ RAM** (8 GB recommended for Flux Smart)
- **Flutter SDK** (≥3.0) for development
- Android Studio, VS Code, or IntelliJ

### Installation

```bash
# Clone
git clone https://github.com/Finn-Technologies/flux.git
cd flux

# Dependencies
flutter pub get

# Run on a connected device
flutter run

# Build a release APK
flutter build apk --release --split-per-abi
```

---

## Architecture

```
lib/
├── main.dart                    # Entry point, GoRouter, theming
├── core/
│   ├── constants/               # AppVersion, etc.
│   ├── models/
│   │   ├── hf_model.dart        # AI model data structures
│   │   └── chat_session.dart    # Conversation persistence
│   ├── services/
│   │   ├── inference_service.dart   # llama.cpp streaming inference
│   │   ├── model_service.dart       # RAM-filtered model listing
│   │   └── search_service.dart      # DuckDuckGo HTML scraping
│   ├── providers/
│   │   ├── download_provider.dart   # Download state management
│   │   └── model_provider.dart      # Selected model state
│   ├── theme/                   # FluxColors, light/dark themes
│   └── widgets/                 # Shared UI components
├── features/
│   ├── onboarding/              # Welcome flow + model selection
│   ├── chat/                    # Main chat + message list + streaming
│   ├── models/                  # Download library + storage info
│   ├── creations/               # App builder gallery, editor, preview
│   └── settings/                # Cache, about, version
├── l10n/                        # ARB + generated Dart (6 languages)
└── assets/
    ├── images/                  # SVG icons
    └── icon/                    # App icon (PNG)
```

### Tech Stack

| Layer | Choice |
|-------|--------|
| Framework | Flutter 3.x |
| State | Riverpod 2.x |
| Routing | go_router |
| Local DB | Hive + SharedPreferences |
| AI Engine | llama.cpp via `llamadart` |
| Downloads | `background_downloader` |
| Search | DuckDuckGo HTML (no API key needed) |
| WebView | `webview_flutter` |
| Fonts | Instrument Sans (Google Fonts) |
| Icons | Custom SVGs + Material Symbols |

---

---

## Privacy

Flux is built with privacy as a hard requirement:

- **No account** — download and start using immediately
- **No cloud** — inference runs locally via llama.cpp
- **No telemetry** — zero analytics, zero tracking
- **No internet needed** — fully offline when search is toggled off
- **Open source** — every line of code is auditable

---

## Roadmap

- [x] Offline AI chat with 4 model sizes
- [x] Web search with source display
- [x] HTML/CSS/JS app builder (Creations)
- [x] Conversation history with model restoration
- [x] Context window compaction
- [x] 6-language localization
- [x] Performance: throttled streaming, continuations, debouncing
- [ ] Image / vision model support
- [ ] Voice input
- [ ] Export conversations (JSON / text)
- [ ] iOS version

---

## License

MIT License — see [LICENSE](LICENSE).

---

<div align="center">
  <strong>Made with ❤️ by Finn Technologies</strong>
</div>
