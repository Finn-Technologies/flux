# Flux

Your private AI assistant that runs entirely offline on your device. No accounts, no cloud, no data leaving your phone—ever.

<p align="center">
  <img src="assets/icon/app_icon.png" width="120" alt="Flux Logo">
</p>

<p align="center">
  <a href="https://github.com/Finn-Technologies/flux/releases"><img src="https://img.shields.io/badge/version-0.1.4-blue.svg" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
</p>

## What is Flux?

Flux is a fully offline AI chat assistant for Android. Unlike other AI apps that send your conversations to the cloud, Flux keeps everything on your device using local AI models powered by Qwen 3.5.

### Key Features

- **🤖 Three AI Models** — Choose the right balance for your device:
  - **Flux Lite** (500MB) — Ultra-fast, works on 4GB RAM devices
  - **Flux Steady** (1.3GB) — Balanced performance, requires 6GB RAM
  - **Flux Smart** (2.6GB) — Maximum capability, requires 8GB+ RAM

- **💬 Beautiful Chat Interface** — Clean, minimalist design with smooth animations.

- **📚 Conversation History** — Automatically saves chats with easy access via slide-in sidebar

- **🔒 100% Private** — No accounts, no tracking, no internet required for inference

## Download Models

Flux downloads AI models directly from Hugging Face. Models are optimized for your device's RAM:

| Model | Size | Required RAM | Best For |
|-------|------|--------------|----------|
| Flux Lite | 500 MB | 4 GB | Quick answers, older devices |
| Flux Steady | 1.3 GB | 6 GB | Daily tasks, balanced use |
| Flux Smart | 2.6 GB | 8 GB+ | Complex reasoning, maximum quality |

## Getting Started

### Prerequisites
- Android device with 4GB+ RAM
- Flutter SDK (for development)
- Android Studio or VS Code

### Installation

```bash
# Clone the repository
git clone https://github.com/Finn-Technologies/flux.git
cd flux

# Install dependencies
flutter pub get

# Run on device or emulator
flutter run

# Build release APK
flutter build apk --release
```

## Architecture

```
lib/
├── main.dart                    # App entry, GoRouter navigation
├── core/
│   ├── models/
│   │   ├── hf_model.dart        # AI model data structures
│   │   └── chat_session.dart    # Conversation persistence
│   ├── services/
│   │   ├── model_service.dart   # Model management & RAM filtering
│   │   └── inference_service.dart # On-device inference
│   ├── providers/
│   │   ├── download_provider.dart  # Download state management
│   │   └── model_provider.dart     # Selected model state
│   └── widgets/
│       └── flux_shell.dart      # Bottom navigation shell
├── features/
│   ├── onboarding/              # 5-step onboarding flow
│   │   ├── onboarding_page.dart
│   │   └── choose_model_screen.dart
│   ├── chat/                  # Main chat interface
│   │   └── chat_screen.dart
│   ├── models/                # Model download & management
│   │   └── models_screen.dart
│   └── settings/              # App settings
│       └── settings_screen.dart
└── assets/
    ├── images/                # SVG icons
    └── icon/                  # App icon
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.x |
| State Management | Riverpod 2.x |
| Navigation | go_router |
| Local Storage | Hive + SharedPreferences |
| Downloads | background_downloader |
| AI Inference | llama.cpp (integrated) |
| Styling | Material 3 with custom design |
| Animations | Built-in Flutter (TweenAnimationBuilder, AnimatedScale) |

## Design Philosophy

Flux follows a **minimalist, Apple-inspired design**:

- **Color palette**: Clean whites, soft grays, and deep blacks
- **Typography**: Instrument Sans font throughout
- **Animations**: Smooth 350ms transitions with easeOutCubic curves
- **Navigation**: Simple 2-tab bottom bar (Home + Settings)
- **Spacing**: Generous 20px margins, consistent 15px card radius

## Privacy

Flux is built with privacy as the foundation:

- ✅ **No account required** — Start using immediately
- ✅ **No internet needed** — Works completely offline
- ✅ **No data collection** — Zero analytics or tracking
- ✅ **Open source** — Audit the full source code
- ✅ **Local storage only** — All data stays on your device

## Roadmap

- [x] Redesigned UI with smooth animations
- [x] Three-tier model system (Lite/Steady/Smart)
- [x] RAM-based model filtering
- [x] Staggered entrance animations
- [x] Performance optimizations (RepaintBoundary, cacheExtent)
- [ ] Image/vision model support
- [ ] Voice input integration
- [ ] Export conversations
- [ ] Multiple language support
- [ ] iOS version

## License

MIT License — see [LICENSE](LICENSE) for details.

---

**Made with ❤️ by Finn Technologies**
