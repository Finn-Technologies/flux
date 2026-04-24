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
