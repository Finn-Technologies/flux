import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('zh')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Flux'**
  String get appTitle;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Creations tab label
  ///
  /// In en, this message translates to:
  /// **'Creations'**
  String get creations;

  /// Settings tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Models screen title
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get models;

  /// Subtitle for models settings item
  ///
  /// In en, this message translates to:
  /// **'Download and manage AI models'**
  String get downloadAndManageModels;

  /// Clear cache settings item
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// Subtitle for clear cache
  ///
  /// In en, this message translates to:
  /// **'Remove temporary files'**
  String get removeTemporaryFiles;

  /// About Flux settings item
  ///
  /// In en, this message translates to:
  /// **'About Flux'**
  String get aboutFlux;

  /// Version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// About Flux description
  ///
  /// In en, this message translates to:
  /// **'Your private AI assistant that runs locally on your device. Your data stays on your phone — no account needed.'**
  String get yourPrivateAI;

  /// Model selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get selectModel;

  /// Message when no models are available
  ///
  /// In en, this message translates to:
  /// **'No models downloaded. Go to Library to download.'**
  String get noModelsDownloaded;

  /// Model info prefix
  ///
  /// In en, this message translates to:
  /// **'Powered by'**
  String get poweredBy;

  /// Delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Clear cache confirmation title
  ///
  /// In en, this message translates to:
  /// **'Clear cache?'**
  String get clearCacheQuestion;

  /// Clear cache confirmation message
  ///
  /// In en, this message translates to:
  /// **'This removes temporary files only. Your downloaded models and chats will not be affected.'**
  String get clearCacheMessage;

  /// Delete model confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete Model?'**
  String get deleteModelQuestion;

  /// Cancel download confirmation title
  ///
  /// In en, this message translates to:
  /// **'Cancel Download?'**
  String get cancelDownloadQuestion;

  /// Preview button label
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// Download button label
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// Downloading status
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// Chat screen title
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// Chat input placeholder
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// Empty creations message
  ///
  /// In en, this message translates to:
  /// **'No creations yet'**
  String get noCreations;

  /// Empty creations sub-message
  ///
  /// In en, this message translates to:
  /// **'Create your first AI-powered app'**
  String get createFirst;

  /// Empty models message
  ///
  /// In en, this message translates to:
  /// **'No models yet'**
  String get noModelsYet;

  /// Empty models sub-message
  ///
  /// In en, this message translates to:
  /// **'Download a model to get started'**
  String get downloadModelToStart;

  /// Cancel download action
  ///
  /// In en, this message translates to:
  /// **'Cancel Download'**
  String get cancelDownload;

  /// Continue download action
  ///
  /// In en, this message translates to:
  /// **'Continue Download'**
  String get continueDownload;

  /// Empty creations sub-message
  ///
  /// In en, this message translates to:
  /// **'Build your first interactive mini-app'**
  String get buildFirstApp;

  /// Onboarding welcome title
  ///
  /// In en, this message translates to:
  /// **'Welcome to Flux'**
  String get welcomeToFlux;

  /// Start button
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Skip setup button
  ///
  /// In en, this message translates to:
  /// **'Skip setup'**
  String get skipSetup;

  /// Download and continue button
  ///
  /// In en, this message translates to:
  /// **'Download & Continue'**
  String get downloadAndContinue;

  /// High-speed connection recommendation
  ///
  /// In en, this message translates to:
  /// **'High-speed connection recommended.'**
  String get highSpeedConnectionRecommended;

  /// No description provided for @noModelSelected.
  ///
  /// In en, this message translates to:
  /// **'No model selected'**
  String get noModelSelected;

  /// No description provided for @noModelSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'No model is currently selected or downloaded. Please visit the Library to download a model first.'**
  String get noModelSelectedMessage;

  /// No description provided for @messageFlux.
  ///
  /// In en, this message translates to:
  /// **'Message Flux...'**
  String get messageFlux;

  /// No description provided for @howCanIHelp.
  ///
  /// In en, this message translates to:
  /// **'How can I help you today?'**
  String get howCanIHelp;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with Flux'**
  String get startConversation;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// No description provided for @conversationsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Your conversations will appear here'**
  String get conversationsAppearHere;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameChat.
  ///
  /// In en, this message translates to:
  /// **'Rename Chat'**
  String get renameChat;

  /// No description provided for @chatName.
  ///
  /// In en, this message translates to:
  /// **'Chat name'**
  String get chatName;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @chatHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat history'**
  String get chatHistory;

  /// No description provided for @weValuePrivacy.
  ///
  /// In en, this message translates to:
  /// **'We value your privacy'**
  String get weValuePrivacy;

  /// No description provided for @privacyDescription.
  ///
  /// In en, this message translates to:
  /// **'We designed Flux to use Local AI models, so your data doesn\'t go to corporations, not even us.'**
  String get privacyDescription;

  /// No description provided for @fullyOffline.
  ///
  /// In en, this message translates to:
  /// **'Fully offline'**
  String get fullyOffline;

  /// No description provided for @offlineDescription.
  ///
  /// In en, this message translates to:
  /// **'Since we use Local AI models, Flux works entirely offline, so you can ask questions even with no coverage.'**
  String get offlineDescription;

  /// No description provided for @chooseModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a model to download'**
  String get chooseModel;

  /// No description provided for @chooseModelDescription.
  ///
  /// In en, this message translates to:
  /// **'Flux recommends models optimized for your device, ensuring they work properly.'**
  String get chooseModelDescription;

  /// No description provided for @thatsIt.
  ///
  /// In en, this message translates to:
  /// **'That\'s it. Flux is ready!'**
  String get thatsIt;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installed;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @fluxCreativeRequired.
  ///
  /// In en, this message translates to:
  /// **'Flux Creative Required'**
  String get fluxCreativeRequired;

  /// No description provided for @installCreativeModel.
  ///
  /// In en, this message translates to:
  /// **'Install the Creative model to start creating.'**
  String get installCreativeModel;

  /// No description provided for @installFluxCreative.
  ///
  /// In en, this message translates to:
  /// **'Install Flux Creative'**
  String get installFluxCreative;

  /// No description provided for @creativeDownloadSize.
  ///
  /// In en, this message translates to:
  /// **'~890 MB download'**
  String get creativeDownloadSize;

  /// No description provided for @selectModelToChat.
  ///
  /// In en, this message translates to:
  /// **'Select a model to start chatting'**
  String get selectModelToChat;

  /// No description provided for @buildSomethingAmazing.
  ///
  /// In en, this message translates to:
  /// **'Build something amazing'**
  String get buildSomethingAmazing;

  /// No description provided for @describeAppIdea.
  ///
  /// In en, this message translates to:
  /// **'Describe your app idea...'**
  String get describeAppIdea;

  /// No description provided for @previewCreation.
  ///
  /// In en, this message translates to:
  /// **'Preview Creation'**
  String get previewCreation;

  /// No description provided for @tapToOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Tap to open interactive app'**
  String get tapToOpenApp;

  /// No description provided for @fluxCreativeNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Flux Creative is not installed.'**
  String get fluxCreativeNotInstalled;

  /// No description provided for @installCreativeToUseCreations.
  ///
  /// In en, this message translates to:
  /// **'Please install it from Models to use Creations.'**
  String get installCreativeToUseCreations;

  /// No description provided for @modelArchitectureUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Model Architecture Unsupported. Please try a standard Llama 3.2 or Qwen model for now.'**
  String get modelArchitectureUnsupported;

  /// No description provided for @inferenceError.
  ///
  /// In en, this message translates to:
  /// **'Inference Error'**
  String get inferenceError;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @searchingFor.
  ///
  /// In en, this message translates to:
  /// **'Searching for \"{query}\"...'**
  String searchingFor(Object query);

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @searched.
  ///
  /// In en, this message translates to:
  /// **'Searched'**
  String get searched;

  /// No description provided for @reasoned.
  ///
  /// In en, this message translates to:
  /// **'Reasoned'**
  String get reasoned;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get thinking;

  /// No description provided for @closeMenu.
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get closeMenu;

  /// No description provided for @untitledCreation.
  ///
  /// In en, this message translates to:
  /// **'Untitled Creation'**
  String get untitledCreation;

  /// No description provided for @newCreation.
  ///
  /// In en, this message translates to:
  /// **'New Creation'**
  String get newCreation;

  /// No description provided for @modelPicker.
  ///
  /// In en, this message translates to:
  /// **'Model Picker'**
  String get modelPicker;

  /// No description provided for @detectedRam.
  ///
  /// In en, this message translates to:
  /// **'Detected {ram} GB RAM'**
  String detectedRam(Object ram);

  /// No description provided for @selectOptimizedModel.
  ///
  /// In en, this message translates to:
  /// **'Select the most optimized model for your device.'**
  String get selectOptimizedModel;

  /// No description provided for @creationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Creation not found'**
  String get creationNotFound;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(Object minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(Object hours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(Object days);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'it',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
