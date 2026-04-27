// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flux';

  @override
  String get home => 'Home';

  @override
  String get creations => 'Creations';

  @override
  String get settings => 'Settings';

  @override
  String get models => 'Models';

  @override
  String get downloadAndManageModels => 'Download and manage AI models';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get removeTemporaryFiles => 'Remove temporary files';

  @override
  String get aboutFlux => 'About Flux';

  @override
  String get version => 'Version';

  @override
  String get yourPrivateAI =>
      'Your private AI assistant that runs locally on your device. Your data stays on your phone — no account needed.';

  @override
  String get selectModel => 'Select Model';

  @override
  String get noModelsDownloaded =>
      'No models downloaded. Go to Library to download.';

  @override
  String get poweredBy => 'Powered by';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get clearCacheQuestion => 'Clear cache?';

  @override
  String get clearCacheMessage =>
      'This removes temporary files only. Your downloaded models and chats will not be affected.';

  @override
  String get deleteModelQuestion => 'Delete Model?';

  @override
  String get cancelDownloadQuestion => 'Cancel Download?';

  @override
  String get preview => 'Preview';

  @override
  String get download => 'Download';

  @override
  String get downloading => 'Downloading';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get noCreations => 'No creations yet';

  @override
  String get createFirst => 'Create your first AI-powered app';

  @override
  String get noModelsYet => 'No models yet';

  @override
  String get downloadModelToStart => 'Download a model to get started';

  @override
  String get cancelDownload => 'Cancel Download';

  @override
  String get continueDownload => 'Continue Download';

  @override
  String get buildFirstApp => 'Build your first interactive mini-app';

  @override
  String get welcomeToFlux => 'Welcome to Flux';

  @override
  String get start => 'Start';

  @override
  String get skipSetup => 'Skip setup';

  @override
  String get downloadAndContinue => 'Download & Continue';

  @override
  String get highSpeedConnectionRecommended =>
      'High-speed connection recommended.';

  @override
  String get noModelSelected => 'No model selected';

  @override
  String get noModelSelectedMessage =>
      'No model is currently selected or downloaded. Please visit the Library to download a model first.';

  @override
  String get messageFlux => 'Message Flux...';

  @override
  String get howCanIHelp => 'How can I help you today?';

  @override
  String get startConversation => 'Start a conversation with Flux';

  @override
  String get retry => 'Retry';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get chats => 'Chats';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get conversationsAppearHere => 'Your conversations will appear here';

  @override
  String get rename => 'Rename';

  @override
  String get renameChat => 'Rename Chat';

  @override
  String get chatName => 'Chat name';

  @override
  String get save => 'Save';

  @override
  String get newChat => 'New chat';

  @override
  String get chatHistory => 'Chat history';

  @override
  String get weValuePrivacy => 'We value your privacy';

  @override
  String get privacyDescription =>
      'We designed Flux to use Local AI models, so your data doesn\'t go to corporations, not even us.';

  @override
  String get fullyOffline => 'Fully offline';

  @override
  String get offlineDescription =>
      'Since we use Local AI models, Flux works entirely offline, so you can ask questions even with no coverage.';

  @override
  String get chooseModel => 'Choose a model to download';

  @override
  String get chooseModelDescription =>
      'Flux recommends models optimized for your device, ensuring they work properly.';

  @override
  String get thatsIt => 'That\'s it. Flux is ready!';

  @override
  String get finish => 'Finish';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get storage => 'Storage';

  @override
  String get installed => 'Installed';

  @override
  String get available => 'Available';

  @override
  String get fluxCreativeRequired => 'Flux Creative Required';

  @override
  String get installCreativeModel =>
      'Install the Creative model to start creating.';

  @override
  String get installFluxCreative => 'Install Flux Creative';

  @override
  String get creativeDownloadSize => '~890 MB download';

  @override
  String get selectModelToChat => 'Select a model to start chatting';

  @override
  String get buildSomethingAmazing => 'Build something amazing';

  @override
  String get describeAppIdea => 'Describe your app idea...';

  @override
  String get previewCreation => 'Preview Creation';

  @override
  String get tapToOpenApp => 'Tap to open interactive app';

  @override
  String get fluxCreativeNotInstalled => 'Flux Creative is not installed.';

  @override
  String get installCreativeToUseCreations =>
      'Please install it from Models to use Creations.';

  @override
  String get modelArchitectureUnsupported =>
      'Model Architecture Unsupported. Please try a standard Llama 3.2 or Qwen model for now.';

  @override
  String get inferenceError => 'Inference Error';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String searchingFor(Object query) {
    return 'Searching for \"$query\"...';
  }

  @override
  String get sources => 'Sources';

  @override
  String get searched => 'Searched';

  @override
  String get reasoned => 'Reasoned';

  @override
  String get thinking => 'Thinking';

  @override
  String get closeMenu => 'Close menu';

  @override
  String get untitledCreation => 'Untitled Creation';

  @override
  String get newCreation => 'New Creation';

  @override
  String get modelPicker => 'Model Picker';

  @override
  String detectedRam(Object ram) {
    return 'Detected $ram GB RAM';
  }

  @override
  String get selectOptimizedModel =>
      'Select the most optimized model for your device.';

  @override
  String get creationNotFound => 'Creation not found';

  @override
  String get goBack => 'Go Back';

  @override
  String get untitled => 'Untitled';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(Object minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(Object hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(Object days) {
    return '${days}d ago';
  }
}
