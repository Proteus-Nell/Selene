import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The app name, shown in the task switcher.
  ///
  /// In en, this message translates to:
  /// **'Selene'**
  String get appTitle;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// No description provided for @navLog.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navLog;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights;

  /// No description provided for @navLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get navLearn;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get onboardingTitle;

  /// No description provided for @onboardingIntro.
  ///
  /// In en, this message translates to:
  /// **'Selene records your cycle on your phone and predicts when your next period is likely to start. We do not collect any of it. The app has no internet permission, and nothing you record leaves your phone unless you choose to send it.'**
  String get onboardingIntro;

  /// No description provided for @onboardingWhatItIsNotTitle.
  ///
  /// In en, this message translates to:
  /// **'What Selene is not'**
  String get onboardingWhatItIsNotTitle;

  /// No description provided for @onboardingNotContraception.
  ///
  /// In en, this message translates to:
  /// **'Selene is not contraception. It cannot tell you when sex is unlikely to lead to pregnancy, and it must never be used to try.'**
  String get onboardingNotContraception;

  /// No description provided for @onboardingNotMedical.
  ///
  /// In en, this message translates to:
  /// **'Selene does not give medical advice. If something about your cycle worries you, talk to a doctor or nurse.'**
  String get onboardingNotMedical;

  /// No description provided for @onboardingNotDiagnostic.
  ///
  /// In en, this message translates to:
  /// **'Predictions come from the dates you record and nothing else, so Selene cannot diagnose anything. Illness, stress, medicines and contraception can all move a period, and predictions do not account for them.'**
  String get onboardingNotDiagnostic;

  /// No description provided for @onboardingAlwaysARange.
  ///
  /// In en, this message translates to:
  /// **'Predictions come as a range of days, never a single date, because cycles vary too much for one date to be accurate.'**
  String get onboardingAlwaysARange;

  /// No description provided for @onboardingAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get onboardingAcknowledge;

  /// No description provided for @onboardingFirstEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'When did your last period start?'**
  String get onboardingFirstEntryTitle;

  /// No description provided for @onboardingFirstEntryBody.
  ///
  /// In en, this message translates to:
  /// **'One date is enough to begin. Predictions start wide and get narrower as you log more cycles.'**
  String get onboardingFirstEntryBody;

  /// No description provided for @onboardingFirstEntrySkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingFirstEntrySkip;

  /// No description provided for @onboardingFirstEntrySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved. You can change it any time.'**
  String get onboardingFirstEntrySaved;

  /// No description provided for @logWeekBleedingSuffix.
  ///
  /// In en, this message translates to:
  /// **'{label}, bleeding logged'**
  String logWeekBleedingSuffix(String label);

  /// No description provided for @logGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get logGreetingMorning;

  /// No description provided for @logGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get logGreetingAfternoon;

  /// No description provided for @logGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get logGreetingEvening;

  /// No description provided for @logPhaseAndDay.
  ///
  /// In en, this message translates to:
  /// **'{phase} · day {day}'**
  String logPhaseAndDay(String phase, int day);

  /// No description provided for @logDayOfCycleShort.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String logDayOfCycleShort(int day);

  /// No description provided for @logCountdownRange.
  ///
  /// In en, this message translates to:
  /// **'in {from}–{to} days'**
  String logCountdownRange(int from, int to);

  /// No description provided for @logCountdownCaption.
  ///
  /// In en, this message translates to:
  /// **'until your period is expected'**
  String get logCountdownCaption;

  /// No description provided for @logCountdownNow.
  ///
  /// In en, this message translates to:
  /// **'any day now'**
  String get logCountdownNow;

  /// No description provided for @logCountdownNowCaption.
  ///
  /// In en, this message translates to:
  /// **'you are inside the expected range'**
  String get logCountdownNowCaption;

  /// No description provided for @logCountdownNothingYet.
  ///
  /// In en, this message translates to:
  /// **'not yet'**
  String get logCountdownNothingYet;

  /// No description provided for @logCountdownNothingYetCaption.
  ///
  /// In en, this message translates to:
  /// **'log a period start and this fills in'**
  String get logCountdownNothingYetCaption;

  /// No description provided for @logCountdownLater.
  ///
  /// In en, this message translates to:
  /// **'later than expected'**
  String get logCountdownLater;

  /// No description provided for @logCountdownLaterCaption.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day past the expected range} other{{days} days past the expected range}}'**
  String logCountdownLaterCaption(int days);

  /// No description provided for @logCountdownLostTrack.
  ///
  /// In en, this message translates to:
  /// **'lost track'**
  String get logCountdownLostTrack;

  /// No description provided for @logCountdownLostTrackCaption.
  ///
  /// In en, this message translates to:
  /// **'log your latest period start and this picks up again'**
  String get logCountdownLostTrackCaption;

  /// No description provided for @logCountdownNoRange.
  ///
  /// In en, this message translates to:
  /// **'no range'**
  String get logCountdownNoRange;

  /// No description provided for @logCountdownNoRangeCaption.
  ///
  /// In en, this message translates to:
  /// **'your cycles vary too much for a useful one'**
  String get logCountdownNoRangeCaption;

  /// No description provided for @logCountdownPaused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get logCountdownPaused;

  /// No description provided for @logCountdownPausedCaption.
  ///
  /// In en, this message translates to:
  /// **'no prediction while a pregnancy is recorded'**
  String get logCountdownPausedCaption;

  /// No description provided for @logCountdownCheckDates.
  ///
  /// In en, this message translates to:
  /// **'check dates'**
  String get logCountdownCheckDates;

  /// No description provided for @logCountdownCheckDatesCaption.
  ///
  /// In en, this message translates to:
  /// **'the stored dates need a look before this fills in'**
  String get logCountdownCheckDatesCaption;

  /// No description provided for @logRingLabel.
  ///
  /// In en, this message translates to:
  /// **'Your cycle as a ring. {summary}'**
  String logRingLabel(String summary);

  /// No description provided for @logLegendOvulation.
  ///
  /// In en, this message translates to:
  /// **'Ovulation'**
  String get logLegendOvulation;

  /// No description provided for @logStartedOn.
  ///
  /// In en, this message translates to:
  /// **'Period started {date}'**
  String logStartedOn(String date);

  /// No description provided for @logPeriodStartedToday.
  ///
  /// In en, this message translates to:
  /// **'Period started today'**
  String get logPeriodStartedToday;

  /// No description provided for @logPeriodStartedOnDay.
  ///
  /// In en, this message translates to:
  /// **'Period started {day}'**
  String logPeriodStartedOnDay(String day);

  /// No description provided for @logWhenDidItStart.
  ///
  /// In en, this message translates to:
  /// **'When did it start?'**
  String get logWhenDidItStart;

  /// No description provided for @logDayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get logDayToday;

  /// No description provided for @logDayYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get logDayYesterday;

  /// No description provided for @logDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String logDaysAgo(int count);

  /// No description provided for @logStillBleeding.
  ///
  /// In en, this message translates to:
  /// **'Still bleeding today'**
  String get logStillBleeding;

  /// No description provided for @logNotBleeding.
  ///
  /// In en, this message translates to:
  /// **'Not bleeding today'**
  String get logNotBleeding;

  /// No description provided for @logFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get logFlowTitle;

  /// No description provided for @logFlowNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get logFlowNone;

  /// No description provided for @logFlowSpotting.
  ///
  /// In en, this message translates to:
  /// **'Spotting'**
  String get logFlowSpotting;

  /// No description provided for @logFlowLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get logFlowLight;

  /// No description provided for @logFlowMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get logFlowMedium;

  /// No description provided for @logFlowHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get logFlowHeavy;

  /// The 'yes' answer when the flow control is collapsed to a yes/no question. Answers 'is there bleeding today', so it reads as a state rather than as a bare Yes.
  ///
  /// In en, this message translates to:
  /// **'Bleeding'**
  String get logBleedingYes;

  /// No description provided for @logBleedingNo.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get logBleedingNo;

  /// No description provided for @logSymptomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Anything else today?'**
  String get logSymptomsTitle;

  /// No description provided for @logMeasurementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Temperature, mucus and progesterone'**
  String get logMeasurementsTitle;

  /// No description provided for @logMeasurementsHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, and only a record. Selene does not use any of these to predict anything or to estimate ovulation.'**
  String get logMeasurementsHint;

  /// No description provided for @logTemperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Basal body temperature'**
  String get logTemperatureLabel;

  /// No description provided for @logTemperatureCelsius.
  ///
  /// In en, this message translates to:
  /// **'°C'**
  String get logTemperatureCelsius;

  /// No description provided for @logTemperatureFahrenheit.
  ///
  /// In en, this message translates to:
  /// **'°F'**
  String get logTemperatureFahrenheit;

  /// No description provided for @logTemperatureInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a temperature between {low} and {high}.'**
  String logTemperatureInvalid(String low, String high);

  /// No description provided for @logMucusTitle.
  ///
  /// In en, this message translates to:
  /// **'Cervical mucus'**
  String get logMucusTitle;

  /// No description provided for @logMucusDry.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get logMucusDry;

  /// No description provided for @logMucusSticky.
  ///
  /// In en, this message translates to:
  /// **'Sticky'**
  String get logMucusSticky;

  /// No description provided for @logMucusCreamy.
  ///
  /// In en, this message translates to:
  /// **'Creamy'**
  String get logMucusCreamy;

  /// No description provided for @logMucusWatery.
  ///
  /// In en, this message translates to:
  /// **'Watery'**
  String get logMucusWatery;

  /// No description provided for @logMucusEggWhite.
  ///
  /// In en, this message translates to:
  /// **'Egg white'**
  String get logMucusEggWhite;

  /// No description provided for @logProgesteroneTitle.
  ///
  /// In en, this message translates to:
  /// **'Progesterone'**
  String get logProgesteroneTitle;

  /// No description provided for @logPdgStripLabel.
  ///
  /// In en, this message translates to:
  /// **'Home PdG strip'**
  String get logPdgStripLabel;

  /// No description provided for @logPdgNegative.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get logPdgNegative;

  /// No description provided for @logPdgPositive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get logPdgPositive;

  /// No description provided for @logProgesteroneBloodLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood test result'**
  String get logProgesteroneBloodLabel;

  /// No description provided for @logProgesteroneUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get logProgesteroneUnitLabel;

  /// No description provided for @logProgesteroneNgPerMl.
  ///
  /// In en, this message translates to:
  /// **'ng/mL'**
  String get logProgesteroneNgPerMl;

  /// No description provided for @logProgesteroneNmolPerL.
  ///
  /// In en, this message translates to:
  /// **'nmol/L'**
  String get logProgesteroneNmolPerL;

  /// No description provided for @logProgesteroneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the result as a number above zero.'**
  String get logProgesteroneInvalid;

  /// No description provided for @logIntercourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Intercourse'**
  String get logIntercourseTitle;

  /// Under the intercourse control. Says both things a user needs before touching it: that it is optional, and that recording it does not feed the model — which they would otherwise reasonably assume it does.
  ///
  /// In en, this message translates to:
  /// **'Optional, and not used for predictions. Tap again to clear.'**
  String get logIntercourseHint;

  /// No description provided for @logIntercourseProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get logIntercourseProtected;

  /// No description provided for @logIntercourseUnprotected.
  ///
  /// In en, this message translates to:
  /// **'Unprotected'**
  String get logIntercourseUnprotected;

  /// No description provided for @calendarLegendIntercourse.
  ///
  /// In en, this message translates to:
  /// **'Intercourse logged'**
  String get calendarLegendIntercourse;

  /// Appended to a day cell's screen-reader label. Says only that something was logged, never whether it was protected — a screen reader is audible to the room.
  ///
  /// In en, this message translates to:
  /// **'{label}, intercourse logged'**
  String calendarCellIntercourseSuffix(String label);

  /// No description provided for @onboardingSensitiveTitle.
  ///
  /// In en, this message translates to:
  /// **'About recording intercourse'**
  String get onboardingSensitiveTitle;

  /// Shown during onboarding, before the user has recorded anything. It names the most sensitive field the app holds rather than letting them find it themselves, and points at the app lock in the same breath.
  ///
  /// In en, this message translates to:
  /// **'You can record intercourse, and whether it was protected. It is the most sensitive thing Selene stores. Recording it is optional, it stays on your phone like everything else, none of it reaches us, and it is never used to predict anything. The app lock in Settings can ask for your fingerprint or PIN before anything shows.'**
  String get onboardingSensitiveBody;

  /// Heading over the symptoms felt in the body.
  ///
  /// In en, this message translates to:
  /// **'Physical'**
  String get logSectionPhysical;

  /// No description provided for @logSectionMental.
  ///
  /// In en, this message translates to:
  /// **'Mental'**
  String get logSectionMental;

  /// No description provided for @logSectionEmotional.
  ///
  /// In en, this message translates to:
  /// **'Emotional'**
  String get logSectionEmotional;

  /// No description provided for @logSymptomCramps.
  ///
  /// In en, this message translates to:
  /// **'Cramps'**
  String get logSymptomCramps;

  /// No description provided for @logSymptomHeadache.
  ///
  /// In en, this message translates to:
  /// **'Headache'**
  String get logSymptomHeadache;

  /// No description provided for @logSymptomBloating.
  ///
  /// In en, this message translates to:
  /// **'Bloating'**
  String get logSymptomBloating;

  /// No description provided for @logSymptomNausea.
  ///
  /// In en, this message translates to:
  /// **'Nausea'**
  String get logSymptomNausea;

  /// No description provided for @logSymptomBreastTenderness.
  ///
  /// In en, this message translates to:
  /// **'Sore breasts'**
  String get logSymptomBreastTenderness;

  /// No description provided for @logSymptomBackPain.
  ///
  /// In en, this message translates to:
  /// **'Back pain'**
  String get logSymptomBackPain;

  /// A symptom chip for skin flare-ups. Everyday wording rather than the clinical 'acne', which reads as a diagnosis.
  ///
  /// In en, this message translates to:
  /// **'Breakouts'**
  String get logSymptomAcne;

  /// No description provided for @logSymptomDigestiveUpset.
  ///
  /// In en, this message translates to:
  /// **'Digestive upset'**
  String get logSymptomDigestiveUpset;

  /// No description provided for @logSymptomSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get logSymptomSleep;

  /// No description provided for @logSymptomBrainFog.
  ///
  /// In en, this message translates to:
  /// **'Brain fog'**
  String get logSymptomBrainFog;

  /// No description provided for @logSymptomPoorConcentration.
  ///
  /// In en, this message translates to:
  /// **'Poor concentration'**
  String get logSymptomPoorConcentration;

  /// A symptom chip. Distinct from 'Low mood': this is mood that moves, not mood that is low. The two are separate entries in the same section, so the translation has to keep them apart.
  ///
  /// In en, this message translates to:
  /// **'Mood swings'**
  String get logSymptomMood;

  /// No description provided for @logSymptomEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get logSymptomEnergy;

  /// No description provided for @logSymptomIrritability.
  ///
  /// In en, this message translates to:
  /// **'Irritability'**
  String get logSymptomIrritability;

  /// No description provided for @logSymptomAnxiety.
  ///
  /// In en, this message translates to:
  /// **'Anxiety'**
  String get logSymptomAnxiety;

  /// No description provided for @logSymptomLowMood.
  ///
  /// In en, this message translates to:
  /// **'Low mood'**
  String get logSymptomLowMood;

  /// No description provided for @logSeverityMild.
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get logSeverityMild;

  /// No description provided for @logSeverityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get logSeverityModerate;

  /// No description provided for @logSeveritySevere.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get logSeveritySevere;

  /// No description provided for @logSeverityHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to record, press and hold to choose how strong it was.'**
  String get logSeverityHint;

  /// No description provided for @logEntrySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get logEntrySaved;

  /// No description provided for @logEntryRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get logEntryRemoved;

  /// No description provided for @logNothingLoggedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged for today yet.'**
  String get logNothingLoggedYet;

  /// No description provided for @logDayInProgress.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of this cycle'**
  String logDayInProgress(int day);

  /// No description provided for @logWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. Log a day and the predictions pick up again.'**
  String get logWelcomeBack;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarPreviousMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarNextMonth;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarLegendPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get calendarLegendPeriod;

  /// No description provided for @calendarLegendPredicted.
  ///
  /// In en, this message translates to:
  /// **'Predicted window'**
  String get calendarLegendPredicted;

  /// No description provided for @calendarLegendToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarLegendToday;

  /// No description provided for @calendarEditDay.
  ///
  /// In en, this message translates to:
  /// **'Edit {date}'**
  String calendarEditDay(String date);

  /// No description provided for @calendarCellPlain.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String calendarCellPlain(String date);

  /// No description provided for @calendarCellPeriodDay.
  ///
  /// In en, this message translates to:
  /// **'{date}, period day {day}'**
  String calendarCellPeriodDay(String date, int day);

  /// No description provided for @calendarCellPredicted.
  ///
  /// In en, this message translates to:
  /// **'{date}, inside predicted window'**
  String calendarCellPredicted(String date);

  /// No description provided for @calendarCellPeriodAndPredicted.
  ///
  /// In en, this message translates to:
  /// **'{date}, period day {day}, inside predicted window'**
  String calendarCellPeriodAndPredicted(String date, int day);

  /// No description provided for @calendarCellTodaySuffix.
  ///
  /// In en, this message translates to:
  /// **'{label}, today'**
  String calendarCellTodaySuffix(String label);

  /// No description provided for @calendarCellSymptomsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{label}, symptoms recorded'**
  String calendarCellSymptomsSuffix(String label);

  /// No description provided for @calendarNoPredictedWindow.
  ///
  /// In en, this message translates to:
  /// **'No predicted window is shown yet. There are not enough logged cycles to work one out.'**
  String get calendarNoPredictedWindow;

  /// No description provided for @calendarLongPressHint.
  ///
  /// In en, this message translates to:
  /// **'Hold any day to change it.'**
  String get calendarLongPressHint;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Predictions are estimates based on the information logged. This does not serve as a contraceptive aid or medical advice.'**
  String get insightsDisclaimer;

  /// No description provided for @insightsNextPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get insightsNextPeriodTitle;

  /// No description provided for @insightsWindowRange.
  ///
  /// In en, this message translates to:
  /// **'Between {start} and {end}'**
  String insightsWindowRange(String start, String end);

  /// No description provided for @insightsMostLikely.
  ///
  /// In en, this message translates to:
  /// **'Most likely around {date}'**
  String insightsMostLikely(String date);

  /// No description provided for @insightsFourInFive.
  ///
  /// In en, this message translates to:
  /// **'About four out of five times start in this range.'**
  String get insightsFourInFive;

  /// No description provided for @insightsLateRange.
  ///
  /// In en, this message translates to:
  /// **'It is later than expected, so this range has moved forward. A late period is harder to predict, so take it as a rough guide.'**
  String get insightsLateRange;

  /// No description provided for @insightsLateNotLogged.
  ///
  /// In en, this message translates to:
  /// **'If it has started and is not logged yet, logging its first day updates this.'**
  String get insightsLateNotLogged;

  /// No description provided for @insightsLaterTitle.
  ///
  /// In en, this message translates to:
  /// **'Later than expected'**
  String get insightsLaterTitle;

  /// No description provided for @insightsLaterBody.
  ///
  /// In en, this message translates to:
  /// **'It was expected between {start} and {end}. A new range would now be too wide to help, so none is shown. If it has started and is not logged yet, logging its first day updates this.'**
  String insightsLaterBody(String start, String end);

  /// No description provided for @insightsHalfTheTime.
  ///
  /// In en, this message translates to:
  /// **'About half the time it starts between {start} and {end}.'**
  String insightsHalfTheTime(String start, String end);

  /// No description provided for @insightsConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'Narrow range'**
  String get insightsConfidenceHigh;

  /// No description provided for @insightsConfidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Moderate range'**
  String get insightsConfidenceMedium;

  /// No description provided for @insightsConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Wide range'**
  String get insightsConfidenceLow;

  /// No description provided for @insightsBasedOnCycles.
  ///
  /// In en, this message translates to:
  /// **'Based on your last {count} cycles.'**
  String insightsBasedOnCycles(int count);

  /// No description provided for @insightsNotPersonalisedYet.
  ///
  /// In en, this message translates to:
  /// **'Based on typical cycles which improve as you log your cycles.'**
  String get insightsNotPersonalisedYet;

  /// No description provided for @insightsNoDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get insightsNoDataTitle;

  /// No description provided for @insightsNoDataBody.
  ///
  /// In en, this message translates to:
  /// **'Log the day your last period started and this screen fills in. Typical cycles run about 29 days, and your own figures replace that number as you log.'**
  String get insightsNoDataBody;

  /// No description provided for @insightsTooIrregularTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cycles vary too much for a useful range'**
  String get insightsTooIrregularTitle;

  /// No description provided for @insightsTooIrregularBody.
  ///
  /// In en, this message translates to:
  /// **'Cycles that vary this much are worth showing a clinician. Your figures are below, and they get more precise the more you log.'**
  String get insightsTooIrregularBody;

  /// No description provided for @insightsLostTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'It has been a while'**
  String get insightsLostTrackTitle;

  /// No description provided for @insightsLostTrackBody.
  ///
  /// In en, this message translates to:
  /// **'Your last logged period started {days} days ago. That is too long to predict from, so nothing is shown here. If one has come since, logging its first day starts predictions again.'**
  String insightsLostTrackBody(int days);

  /// No description provided for @insightsInconsistentTitle.
  ///
  /// In en, this message translates to:
  /// **'The stored dates disagree'**
  String get insightsInconsistentTitle;

  /// No description provided for @insightsInconsistentBody.
  ///
  /// In en, this message translates to:
  /// **'Two of the stored dates cannot both be right, so no prediction is shown. Check the calendar for a day that looks wrong.'**
  String get insightsInconsistentBody;

  /// No description provided for @insightsClockChanged.
  ///
  /// In en, this message translates to:
  /// **'The device date looks like it has moved backwards. Check it before trusting anything here.'**
  String get insightsClockChanged;

  /// No description provided for @insightsYourCyclesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cycles'**
  String get insightsYourCyclesTitle;

  /// No description provided for @insightsTypicalLength.
  ///
  /// In en, this message translates to:
  /// **'Typically {days} days'**
  String insightsTypicalLength(String days);

  /// No description provided for @insightsVariability.
  ///
  /// In en, this message translates to:
  /// **'Varying by about {days} days'**
  String insightsVariability(String days);

  /// No description provided for @insightsRange.
  ///
  /// In en, this message translates to:
  /// **'Between {shortest} and {longest} days'**
  String insightsRange(int shortest, int longest);

  /// No description provided for @insightsCyclesRecorded.
  ///
  /// In en, this message translates to:
  /// **'{count} cycles recorded'**
  String insightsCyclesRecorded(int count);

  /// No description provided for @insightsNotEnoughForStats.
  ///
  /// In en, this message translates to:
  /// **'Log a second cycle to see how much yours vary.'**
  String get insightsNotEnoughForStats;

  /// No description provided for @insightsChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle lengths'**
  String get insightsChartTitle;

  /// No description provided for @insightsChartSummary.
  ///
  /// In en, this message translates to:
  /// **'Bar chart of your last {count} cycle lengths, from {shortest} to {longest} days, typically {median}.'**
  String insightsChartSummary(
    int count,
    int shortest,
    int longest,
    String median,
  );

  /// No description provided for @insightsChartShowTable.
  ///
  /// In en, this message translates to:
  /// **'Show as a table'**
  String get insightsChartShowTable;

  /// No description provided for @insightsChartShowChart.
  ///
  /// In en, this message translates to:
  /// **'Show as a chart'**
  String get insightsChartShowChart;

  /// No description provided for @insightsChartColumnCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get insightsChartColumnCycle;

  /// No description provided for @insightsChartColumnStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get insightsChartColumnStarted;

  /// No description provided for @insightsChartColumnLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get insightsChartColumnLength;

  /// No description provided for @insightsChartLengthDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String insightsChartLengthDays(int days);

  /// No description provided for @insightsTrackRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'How this app has done'**
  String get insightsTrackRecordTitle;

  /// No description provided for @insightsTrackRecordScore.
  ///
  /// In en, this message translates to:
  /// **'Of your last {total} predictions, {hits} were within {days} days.'**
  String insightsTrackRecordScore(int total, int hits, int days);

  /// No description provided for @insightsTrackRecordError.
  ///
  /// In en, this message translates to:
  /// **'It has been off by about {days} days on average.'**
  String insightsTrackRecordError(String days);

  /// No description provided for @insightsTrackRecordNotYet.
  ///
  /// In en, this message translates to:
  /// **'After a few more cycles, this app will show how accurate its own predictions have been.'**
  String get insightsTrackRecordNotYet;

  /// No description provided for @insightsTrackRecordExplain.
  ///
  /// In en, this message translates to:
  /// **'Worked out on this device by re-running the prediction against cycles you had already logged.'**
  String get insightsTrackRecordExplain;

  /// No description provided for @insightsLoggingCompleteness.
  ///
  /// In en, this message translates to:
  /// **'You logged {logged} of the {total} days in this cycle.'**
  String insightsLoggingCompleteness(int logged, int total);

  /// No description provided for @notificationChannelPredictions.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get notificationChannelPredictions;

  /// No description provided for @notificationChannelPredictionsDescription.
  ///
  /// In en, this message translates to:
  /// **'When a period is expected, and when the predicted window has passed.'**
  String get notificationChannelPredictionsDescription;

  /// No description provided for @notificationChannelReminders.
  ///
  /// In en, this message translates to:
  /// **'Logging reminders'**
  String get notificationChannelReminders;

  /// No description provided for @notificationChannelRemindersDescription.
  ///
  /// In en, this message translates to:
  /// **'An occasional prompt if nothing has been logged for a while. Off unless you turn it on.'**
  String get notificationChannelRemindersDescription;

  /// No description provided for @notificationGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Selene'**
  String get notificationGenericTitle;

  /// No description provided for @notificationGenericBody.
  ///
  /// In en, this message translates to:
  /// **'Open the app to see what this is about.'**
  String get notificationGenericBody;

  /// No description provided for @notificationWindowOpeningTitle.
  ///
  /// In en, this message translates to:
  /// **'A period is expected soon'**
  String get notificationWindowOpeningTitle;

  /// No description provided for @notificationWindowOpeningBody.
  ///
  /// In en, this message translates to:
  /// **'The predicted window runs from {start} to {end}.'**
  String notificationWindowOpeningBody(String start, String end);

  /// No description provided for @notificationLikelyStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Has it started?'**
  String get notificationLikelyStartedTitle;

  /// No description provided for @notificationLikelyStartedBody.
  ///
  /// In en, this message translates to:
  /// **'The predicted window is open and nothing is logged yet.'**
  String get notificationLikelyStartedBody;

  /// No description provided for @notificationNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged for a while'**
  String get notificationNudgeTitle;

  /// No description provided for @notificationNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'Logging a day keeps the predictions useful. No hurry.'**
  String get notificationNudgeBody;

  /// No description provided for @notificationLateNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'The predicted window has passed'**
  String get notificationLateNoticeTitle;

  /// No description provided for @notificationLateNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been logged since the window closed. Cycles vary, and a prediction can simply be wrong.'**
  String get notificationLateNoticeBody;

  /// No description provided for @notificationLogAction.
  ///
  /// In en, this message translates to:
  /// **'Started today'**
  String get notificationLogAction;

  /// No description provided for @logMissedReminder.
  ///
  /// In en, this message translates to:
  /// **'A reminder was due while the app was closed. Some phones stop scheduled reminders to save battery.'**
  String get logMissedReminder;

  /// No description provided for @settingsNudgeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Nudge me if I stop logging'**
  String get settingsNudgeEnabled;

  /// No description provided for @settingsNudgeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off by default. At most one every seven days, and none once predictions have stopped.'**
  String get settingsNudgeSubtitle;

  /// No description provided for @settingsDetailedNotifications.
  ///
  /// In en, this message translates to:
  /// **'Show details on the lock screen'**
  String get settingsDetailedNotifications;

  /// No description provided for @settingsDetailedNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off by default. While it is off, notifications show only the app name until the phone is unlocked.'**
  String get settingsDetailedNotificationsSubtitle;

  /// No description provided for @settingsBatteryNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'If reminders do not arrive'**
  String get settingsBatteryNoteTitle;

  /// No description provided for @settingsBatteryNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Some phones stop scheduled reminders to save battery. If yours stop arriving, allow this app to run in the background in your battery settings.'**
  String get settingsBatteryNoteBody;

  /// No description provided for @settingsNotificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on reminders?'**
  String get settingsNotificationPermissionTitle;

  /// No description provided for @settingsNotificationPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Now that you have logged a cycle, this app can remind you before the next one is expected. Change it any time.'**
  String get settingsNotificationPermissionBody;

  /// No description provided for @settingsNotificationPermissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Turn on reminders'**
  String get settingsNotificationPermissionAllow;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDataSection.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsDataSection;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export a backup'**
  String get settingsExport;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Writes a file to a location you choose, protected by a passphrase if you like. Nothing else backs this app up.'**
  String get settingsExportSubtitle;

  /// No description provided for @settingsExportDone.
  ///
  /// In en, this message translates to:
  /// **'Backup written: {count} days.'**
  String settingsExportDone(int count);

  /// No description provided for @settingsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup could not be written.'**
  String get settingsExportFailed;

  /// No description provided for @settingsExportDoneProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected backup written: {count} days.'**
  String settingsExportDoneProtected(int count);

  /// No description provided for @settingsExportProtectTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect this backup with a passphrase?'**
  String get settingsExportProtectTitle;

  /// No description provided for @settingsExportProtectBody.
  ///
  /// In en, this message translates to:
  /// **'Without one, the backup is a readable file, and anyone who gets hold of it can read what you recorded. With one, it opens only with the passphrase. Nobody can recover a forgotten passphrase, not even you, so keep it somewhere safe.'**
  String get settingsExportProtectBody;

  /// No description provided for @settingsExportPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get settingsExportPassphraseLabel;

  /// No description provided for @settingsExportPassphraseConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'The same passphrase again'**
  String get settingsExportPassphraseConfirmLabel;

  /// No description provided for @settingsExportPassphraseTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters. A few unrelated words are easier to remember than a short password.'**
  String settingsExportPassphraseTooShort(int count);

  /// No description provided for @settingsExportPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passphrases are not the same.'**
  String get settingsExportPassphraseMismatch;

  /// No description provided for @settingsExportWithoutPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Save without one'**
  String get settingsExportWithoutPassphrase;

  /// No description provided for @settingsExportWithPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Protect and save'**
  String get settingsExportWithPassphrase;

  /// No description provided for @settingsPassphraseShow.
  ///
  /// In en, this message translates to:
  /// **'Show passphrase'**
  String get settingsPassphraseShow;

  /// No description provided for @settingsPassphraseHide.
  ///
  /// In en, this message translates to:
  /// **'Hide passphrase'**
  String get settingsPassphraseHide;

  /// No description provided for @settingsImportPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'This backup is protected'**
  String get settingsImportPassphraseTitle;

  /// No description provided for @settingsImportPassphraseBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase it was saved with.'**
  String get settingsImportPassphraseBody;

  /// No description provided for @settingsImportPassphraseOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get settingsImportPassphraseOpen;

  /// No description provided for @settingsImportPassphraseWrong.
  ///
  /// In en, this message translates to:
  /// **'That passphrase does not open this backup.'**
  String get settingsImportPassphraseWrong;

  /// No description provided for @settingsImportProtectedNewer.
  ///
  /// In en, this message translates to:
  /// **'This backup was protected by a newer version of Selene. Update the app to open it.'**
  String get settingsImportProtectedNewer;

  /// No description provided for @settingsImportProtectedDamaged.
  ///
  /// In en, this message translates to:
  /// **'This protected backup is damaged and cannot be opened.'**
  String get settingsImportProtectedDamaged;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get settingsImport;

  /// No description provided for @settingsImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replaces everything currently stored with the contents of the file.'**
  String get settingsImportSubtitle;

  /// No description provided for @settingsImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace everything?'**
  String get settingsImportConfirmTitle;

  /// No description provided for @settingsImportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Restoring replaces all {count} days currently stored with the {incoming} days in this backup. This cannot be undone.'**
  String settingsImportConfirmBody(int count, int incoming);

  /// No description provided for @settingsImportDone.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} days from a backup taken on {date}.'**
  String settingsImportDone(int count, String date);

  /// No description provided for @settingsSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary for a doctor'**
  String get settingsSummary;

  /// The PDF summary (ADR-0024). Nothing is sent anywhere: it is written to a folder the user picks.
  ///
  /// In en, this message translates to:
  /// **'A PDF of your periods, cycles, symptoms, conditions and medicines over a span you choose, saved where you choose.'**
  String get settingsSummarySubtitle;

  /// No description provided for @settingsSpreadsheet.
  ///
  /// In en, this message translates to:
  /// **'Export as spreadsheet files'**
  String get settingsSpreadsheet;

  /// No description provided for @settingsSpreadsheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The same as CSV files, to open in a spreadsheet and work with yourself.'**
  String get settingsSpreadsheetSubtitle;

  /// No description provided for @summarySpanTitle.
  ///
  /// In en, this message translates to:
  /// **'How far back?'**
  String get summarySpanTitle;

  /// Before a summary or spreadsheet is made. It must say that intercourse is left out, since the file is for someone else to read.
  ///
  /// In en, this message translates to:
  /// **'It covers period dates, cycle lengths, symptoms, temperature, mucus and progesterone, conditions and medicines. Intercourse is never included.'**
  String get summarySpanBody;

  /// No description provided for @summarySpanThreeMonths.
  ///
  /// In en, this message translates to:
  /// **'The last 3 months'**
  String get summarySpanThreeMonths;

  /// No description provided for @summarySpanSixMonths.
  ///
  /// In en, this message translates to:
  /// **'The last 6 months'**
  String get summarySpanSixMonths;

  /// No description provided for @summarySpanYear.
  ///
  /// In en, this message translates to:
  /// **'The last year'**
  String get summarySpanYear;

  /// No description provided for @summarySpanEverything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get summarySpanEverything;

  /// No description provided for @settingsSummaryDone.
  ///
  /// In en, this message translates to:
  /// **'Saved the summary in the folder you chose.'**
  String get settingsSummaryDone;

  /// No description provided for @settingsSpreadsheetDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved 1 file in the folder you chose.} other{Saved {count} files in the folder you chose.}}'**
  String settingsSpreadsheetDone(int count);

  /// No description provided for @settingsSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'It could not be saved there. Try another folder.'**
  String get settingsSummaryFailed;

  /// No description provided for @settingsSummaryNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing is logged in that span, so there is nothing to summarise.'**
  String get settingsSummaryNothing;

  /// No description provided for @summaryPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle summary'**
  String get summaryPdfTitle;

  /// No description provided for @summaryPdfSpan.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String summaryPdfSpan(String from, String to);

  /// Under the PDF summary's title. It says whose record it is and what it is not, for the doctor reading it.
  ///
  /// In en, this message translates to:
  /// **'Made with Selene on {date}, from what the person it belongs to logged in the app. It is a personal record, not a clinical measurement and not a diagnosis.'**
  String summaryPdfAbout(String date);

  /// No description provided for @summaryPdfCyclesHeading.
  ///
  /// In en, this message translates to:
  /// **'Periods and cycles'**
  String get summaryPdfCyclesHeading;

  /// No description provided for @summaryPdfCyclesUnknown.
  ///
  /// In en, this message translates to:
  /// **'Some logged days contradict each other, so the cycles could not be worked out from them. The logged days are in the spreadsheet export.'**
  String get summaryPdfCyclesUnknown;

  /// No description provided for @summaryPdfNoPeriods.
  ///
  /// In en, this message translates to:
  /// **'No period started in this span.'**
  String get summaryPdfNoPeriods;

  /// No description provided for @summaryPdfPeriodsStarted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 period started in this span.} other{{count} periods started in this span.}}'**
  String summaryPdfPeriodsStarted(int count);

  /// No description provided for @summaryPdfCycleLength.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Cycle length in days, from one period\'s start to the next: {median}, over 1 complete cycle.} other{Cycle length in days, from one period\'s start to the next: median {median}, from {shortest} to {longest}, over {count} complete cycles.}}'**
  String summaryPdfCycleLength(
    int count,
    String median,
    String shortest,
    String longest,
  );

  /// No description provided for @summaryPdfBleeding.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Days of bleeding: {median}, for 1 period.} other{Days of bleeding: median {median}, from {shortest} to {longest}, over {count} periods.}}'**
  String summaryPdfBleeding(
    int count,
    String median,
    String shortest,
    String longest,
  );

  /// No description provided for @summaryPdfNotCounted.
  ///
  /// In en, this message translates to:
  /// **'A cycle with a note is left out of the median, as the app leaves it out of its predictions.'**
  String get summaryPdfNotCounted;

  /// No description provided for @summaryPdfColumnStarted.
  ///
  /// In en, this message translates to:
  /// **'Period started'**
  String get summaryPdfColumnStarted;

  /// No description provided for @summaryPdfColumnBleeding.
  ///
  /// In en, this message translates to:
  /// **'Days of bleeding'**
  String get summaryPdfColumnBleeding;

  /// No description provided for @summaryPdfColumnLength.
  ///
  /// In en, this message translates to:
  /// **'Cycle length (days)'**
  String get summaryPdfColumnLength;

  /// No description provided for @summaryPdfColumnNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get summaryPdfColumnNote;

  /// No description provided for @summaryPdfStillGoing.
  ///
  /// In en, this message translates to:
  /// **'Still going'**
  String get summaryPdfStillGoing;

  /// A cycle the app judges implausibly short, as CycleValidity.implausiblyShort defines it.
  ///
  /// In en, this message translates to:
  /// **'Under 15 days'**
  String get summaryPdfShort;

  /// No description provided for @summaryPdfLong.
  ///
  /// In en, this message translates to:
  /// **'Over 90 days'**
  String get summaryPdfLong;

  /// A cycle that is a strong outlier against the person's own history and has not been confirmed (CycleValidity.unconfirmedOutlier).
  ///
  /// In en, this message translates to:
  /// **'Unusual for this record'**
  String get summaryPdfOutlier;

  /// No description provided for @summaryPdfSymptomsHeading.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get summaryPdfSymptomsHeading;

  /// No description provided for @summaryPdfSymptomsIntro.
  ///
  /// In en, this message translates to:
  /// **'How many days each symptom was logged on, and how strongly it was felt.'**
  String get summaryPdfSymptomsIntro;

  /// No description provided for @summaryPdfNoSymptoms.
  ///
  /// In en, this message translates to:
  /// **'No symptoms were logged in this span.'**
  String get summaryPdfNoSymptoms;

  /// No description provided for @summaryPdfColumnSymptom.
  ///
  /// In en, this message translates to:
  /// **'Symptom'**
  String get summaryPdfColumnSymptom;

  /// No description provided for @summaryPdfColumnDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get summaryPdfColumnDays;

  /// No description provided for @summaryPdfMeasurementsHeading.
  ///
  /// In en, this message translates to:
  /// **'Temperature, mucus and progesterone'**
  String get summaryPdfMeasurementsHeading;

  /// No description provided for @summaryPdfMeasurementsNote.
  ///
  /// In en, this message translates to:
  /// **'Recorded only. The app does not use them to predict anything or to estimate ovulation.'**
  String get summaryPdfMeasurementsNote;

  /// No description provided for @summaryPdfTemperature.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Basal body temperature: 1 reading, {lowest} {unit}.} other{Basal body temperature: {count} readings, from {lowest} to {highest} {unit}.}}'**
  String summaryPdfTemperature(
    int count,
    String lowest,
    String highest,
    String unit,
  );

  /// No description provided for @summaryPdfMucus.
  ///
  /// In en, this message translates to:
  /// **'Cervical mucus: {days}.'**
  String summaryPdfMucus(String days);

  /// No description provided for @summaryPdfMucusKind.
  ///
  /// In en, this message translates to:
  /// **'{kind} on {count, plural, =1{1 day} other{{count} days}}'**
  String summaryPdfMucusKind(String kind, int count);

  /// No description provided for @summaryPdfPdg.
  ///
  /// In en, this message translates to:
  /// **'Home PdG strips: {results}.'**
  String summaryPdfPdg(String results);

  /// No description provided for @summaryPdfPdgResult.
  ///
  /// In en, this message translates to:
  /// **'{result} on {date}'**
  String summaryPdfPdgResult(String result, String date);

  /// No description provided for @summaryPdfBlood.
  ///
  /// In en, this message translates to:
  /// **'Blood progesterone: {results}.'**
  String summaryPdfBlood(String results);

  /// No description provided for @summaryPdfBloodResult.
  ///
  /// In en, this message translates to:
  /// **'{value} {unit} on {date}'**
  String summaryPdfBloodResult(String value, String unit, String date);

  /// No description provided for @summaryPdfConditionsHeading.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get summaryPdfConditionsHeading;

  /// No description provided for @summaryPdfNoConditions.
  ///
  /// In en, this message translates to:
  /// **'None recorded during this span.'**
  String get summaryPdfNoConditions;

  /// No description provided for @summaryPdfConditionSince.
  ///
  /// In en, this message translates to:
  /// **'{condition}: since {start}'**
  String summaryPdfConditionSince(String condition, String start);

  /// No description provided for @summaryPdfConditionFromTo.
  ///
  /// In en, this message translates to:
  /// **'{condition}: {start} to {end}'**
  String summaryPdfConditionFromTo(String condition, String start, String end);

  /// No description provided for @summaryPdfMedicinesHeading.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get summaryPdfMedicinesHeading;

  /// No description provided for @summaryPdfMedicinesNote.
  ///
  /// In en, this message translates to:
  /// **'As recorded in the app today. The list has no dates, so it may not match the whole span.'**
  String get summaryPdfMedicinesNote;

  /// No description provided for @summaryPdfNoMedicines.
  ///
  /// In en, this message translates to:
  /// **'None recorded.'**
  String get summaryPdfNoMedicines;

  /// No description provided for @summaryPdfFooter.
  ///
  /// In en, this message translates to:
  /// **'Selene cycle summary, {from} to {to}'**
  String summaryPdfFooter(String from, String to);

  /// No description provided for @summaryPdfPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String summaryPdfPage(int page, int count);

  /// No description provided for @settingsDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get settingsDeleteAll;

  /// No description provided for @settingsDeleteAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all the logged days, settings and stored figures.'**
  String get settingsDeleteAllSubtitle;

  /// No description provided for @settingsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get settingsDeleteConfirmTitle;

  /// No description provided for @settingsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes all {count} logged days from this device and cannot be undone. There is no copy anywhere else. Type {word} to confirm.'**
  String settingsDeleteConfirmBody(int count, String word);

  /// No description provided for @settingsDeleteConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get settingsDeleteConfirmWord;

  /// No description provided for @settingsDeleteConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Type {word}'**
  String settingsDeleteConfirmHint(String word);

  /// No description provided for @settingsDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Everything has been deleted.'**
  String get settingsDeleteDone;

  /// No description provided for @settingsRemindersSection.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsRemindersSection;

  /// No description provided for @settingsReminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Remind me before a period is due'**
  String get settingsReminderEnabled;

  /// No description provided for @settingsReminderLeadDays.
  ///
  /// In en, this message translates to:
  /// **'How many days ahead'**
  String get settingsReminderLeadDays;

  /// No description provided for @settingsReminderDaysValue.
  ///
  /// In en, this message translates to:
  /// **'{count} days before'**
  String settingsReminderDaysValue(int count);

  /// No description provided for @settingsReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A notification in the morning, the number of days ahead you choose.'**
  String get settingsReminderSubtitle;

  /// No description provided for @insightsSuppressedPregnancyTitle.
  ///
  /// In en, this message translates to:
  /// **'No prediction while you have a pregnancy recorded'**
  String get insightsSuppressedPregnancyTitle;

  /// Shown instead of a predicted window. Says what to do to get predictions back, and says the history is still there, so the state does not read as data loss.
  ///
  /// In en, this message translates to:
  /// **'Your cycles are below, and nothing has been deleted. Add an end date to the pregnancy on the conditions screen and predictions start again.'**
  String get insightsSuppressedPregnancyBody;

  /// No description provided for @calendarPhaseDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of your cycle'**
  String calendarPhaseDay(int day);

  /// No description provided for @calendarPhasePeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get calendarPhasePeriod;

  /// No description provided for @calendarPhaseFollicular.
  ///
  /// In en, this message translates to:
  /// **'Follicular'**
  String get calendarPhaseFollicular;

  /// No description provided for @calendarPhaseLuteal.
  ///
  /// In en, this message translates to:
  /// **'Luteal'**
  String get calendarPhaseLuteal;

  /// Shown when the user taps the Period chip. Plain language, one line, no clinical claim.
  ///
  /// In en, this message translates to:
  /// **'The days you have logged bleeding for. This one comes from what you recorded; the other two are estimated.'**
  String get calendarPhasePeriodExplained;

  /// No description provided for @calendarPhaseFollicularExplained.
  ///
  /// In en, this message translates to:
  /// **'The days between the end of your period and ovulation. Cycle length varies most here, which makes it the part this app predicts least well.'**
  String get calendarPhaseFollicularExplained;

  /// No description provided for @calendarPhaseLutealExplained.
  ///
  /// In en, this message translates to:
  /// **'The days between ovulation and the start of your next period. Its length varies less than the rest of the cycle.'**
  String get calendarPhaseLutealExplained;

  /// No description provided for @calendarPhaseUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not enough logged to say which phase this is.'**
  String get calendarPhaseUnknown;

  /// No description provided for @calendarOvulationTitle.
  ///
  /// In en, this message translates to:
  /// **'Estimated ovulation'**
  String get calendarOvulationTitle;

  /// No description provided for @calendarOvulationRange.
  ///
  /// In en, this message translates to:
  /// **'Around {start} to {end}'**
  String calendarOvulationRange(String start, String end);

  /// Sits directly under the estimated range, never behind a link. The estimate is opt-in and this is the sentence that has to travel with it.
  ///
  /// In en, this message translates to:
  /// **'An estimate from your cycle dates alone. This app cannot observe ovulation, and this must not be used to plan or avoid pregnancy.'**
  String get calendarOvulationCaveat;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockTitle;

  /// No description provided for @lockBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock to see your diary.'**
  String get lockBody;

  /// No description provided for @lockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockAction;

  /// Shown by the system biometric prompt. Must not name the app or say what it tracks: this string can appear on a lock screen that other people can see.
  ///
  /// In en, this message translates to:
  /// **'Unlock to see your diary'**
  String get lockPromptReason;

  /// No description provided for @settingsSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecuritySection;

  /// No description provided for @settingsAppLock.
  ///
  /// In en, this message translates to:
  /// **'Require unlock'**
  String get settingsAppLock;

  /// No description provided for @settingsAppLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask for your fingerprint, face, PIN or pattern before showing the app. It locks again after a minute in the background.'**
  String get settingsAppLockSubtitle;

  /// Sits under the app-lock toggle, always visible, on or off. A lock a user mistakes for the encryption is worse than no lock, so this is not behind a link.
  ///
  /// In en, this message translates to:
  /// **'This only hides the screen. Your data is encrypted on the phone whether the lock is on or off.'**
  String get settingsAppLockNotEncrypted;

  /// Replaces the toggle when no credential is enrolled. Names the fix, which is in the device settings and not in this app.
  ///
  /// In en, this message translates to:
  /// **'Your device has no PIN, pattern, password or fingerprint set up, so there is nothing to ask for. Set a screen lock in your device settings, then come back.'**
  String get settingsAppLockUnavailable;

  /// No description provided for @settingsAppLockNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This device cannot lock the app.'**
  String get settingsAppLockNotSupported;

  /// No description provided for @reExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Make a fresh backup'**
  String get reExportTitle;

  /// Shown once, after updating from a build that wrote the old export format. It must say plainly that old files will not restore and that nothing in the app has been lost — a user who reads only the first sentence must not conclude their history is gone.
  ///
  /// In en, this message translates to:
  /// **'This update changed the backup format. Files you saved before now can no longer be restored, so it is worth exporting again. Your data in the app is untouched.'**
  String get reExportBody;

  /// No description provided for @reExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export now'**
  String get reExportAction;

  /// No description provided for @reExportDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get reExportDismiss;

  /// No description provided for @lookupTitle.
  ///
  /// In en, this message translates to:
  /// **'Look something up'**
  String get lookupTitle;

  /// Under the search field. The second sentence is the point: a user typing a drug name into a search box has every reason to assume it leaves the phone, and here it does not.
  ///
  /// In en, this message translates to:
  /// **'Reference notes stored on this device. Nothing you type here is sent anywhere.'**
  String get lookupSubtitle;

  /// No description provided for @lookupSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get lookupSearchHint;

  /// No description provided for @lookupNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing here matches that.'**
  String get lookupNoResults;

  /// No description provided for @lookupMedicinesHeading.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get lookupMedicinesHeading;

  /// No description provided for @lookupMedicinesSource.
  ///
  /// In en, this message translates to:
  /// **'From US drug labelling published by openFDA, as it stood on {date}.'**
  String lookupMedicinesSource(String date);

  /// Always shown with the medicines section. A reader applying US warnings to a box bought elsewhere is being quietly misinformed, and nothing else on the screen would tell them.
  ///
  /// In en, this message translates to:
  /// **'This is United States labelling. Strengths, brand names and warnings can differ where you are, so check the packet in front of you.'**
  String get lookupMedicinesUsOnly;

  /// Shown when no medicines bundle has been built from openFDA. Says so plainly rather than rendering an empty list, which reads as a broken screen.
  ///
  /// In en, this message translates to:
  /// **'The medicines reference is not built into this version.'**
  String get lookupMedicinesUnavailable;

  /// The progress bar's label for a screen reader, while the index of every medicine loads. A bar alone says nothing to someone who cannot see it.
  ///
  /// In en, this message translates to:
  /// **'Opening the medicines reference'**
  String get lookupMedicinesLoading;

  /// No description provided for @lookupMedicinesFailed.
  ///
  /// In en, this message translates to:
  /// **'The medicines reference could not be opened.'**
  String get lookupMedicinesFailed;

  /// Under the medicines heading before anything is typed. Several thousand medicines listed unasked would be a list nobody reads.
  ///
  /// In en, this message translates to:
  /// **'Type the name of a medicine, a brand or an ingredient to search {count} medicines.'**
  String lookupMedicinesPrompt(int count);

  /// No description provided for @lookupMedicinesShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing the closest {shown} of {total}. Type more of the name to narrow it down.'**
  String lookupMedicinesShowing(int shown, int total);

  /// No description provided for @lookupMedicinesShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get lookupMedicinesShowMore;

  /// No description provided for @lookupBrowseHeading.
  ///
  /// In en, this message translates to:
  /// **'Or browse them from A to Z'**
  String get lookupBrowseHeading;

  /// What a screen reader says for a letter in the A to Z grid. The letter alone would be read as a letter, not as a way in.
  ///
  /// In en, this message translates to:
  /// **'Medicines starting with {letter}'**
  String lookupBrowseLetter(String letter);

  /// What a screen reader says for the # in the A to Z grid.
  ///
  /// In en, this message translates to:
  /// **'Medicines starting with a number or a symbol'**
  String get lookupBrowseOther;

  /// No description provided for @lookupBrowseTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicines: {letter}'**
  String lookupBrowseTitle(String letter);

  /// Under a name in the A to Z that several medicines go by: ibuprofen tablets from a shop, on prescription, and by injection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 medicine by this name} other{{count} medicines by this name}}'**
  String lookupBrowseShared(int count);

  /// No description provided for @lookupBrowseSharedIntro.
  ///
  /// In en, this message translates to:
  /// **'These go by the same name. They differ in what is in them, how they are taken, or whether they need a prescription.'**
  String get lookupBrowseSharedIntro;

  /// No description provided for @lookupMedicinePrescription.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get lookupMedicinePrescription;

  /// No description provided for @lookupMedicineOverTheCounter.
  ///
  /// In en, this message translates to:
  /// **'Over the counter'**
  String get lookupMedicineOverTheCounter;

  /// Brand names, cut short. One medicine can be sold under two thousand.
  ///
  /// In en, this message translates to:
  /// **'{names} and {count, plural, =1{1 other name} other{{count} other names}}'**
  String lookupMedicineOtherNames(String names, int count);

  /// No description provided for @lookupMedicineLabel.
  ///
  /// In en, this message translates to:
  /// **'From the label filed by {manufacturer}, dated {date}.'**
  String lookupMedicineLabel(String manufacturer, String date);

  /// Under the label's source. One label stands for every product with the same ingredients, route and prescription status (ADR-0012), and a reader comparing it with their own box needs to know that.
  ///
  /// In en, this message translates to:
  /// **'Each maker files its own label for a medicine. One is shown here, chosen by a fixed rule, and the label on your packet may differ.'**
  String get lookupMedicineOneLabel;

  /// The leaflet the FDA requires for some medicines, written for patients. Its official name in the US, kept so it can be looked for by name.
  ///
  /// In en, this message translates to:
  /// **'Medication Guide'**
  String get lookupGuideTitle;

  /// Above the folded Medication Guide (ADR-0022). It must say that how to take the medicine is left out, so nobody opens it to look for a dose.
  ///
  /// In en, this message translates to:
  /// **'The leaflet the FDA approves for patients, its safety sections only. How to take the medicine is left out, because a dose on a US leaflet may not be the right one for the packet you have, and so are how to store it and what is in it.'**
  String get lookupGuideNote;

  /// The progress bar's label for a screen reader, while one medicine's label loads.
  ///
  /// In en, this message translates to:
  /// **'Opening this medicine\'s label'**
  String get lookupMedicineLoading;

  /// No description provided for @lookupMedicineFailed.
  ///
  /// In en, this message translates to:
  /// **'This medicine\'s label could not be opened.'**
  String get lookupMedicineFailed;

  /// No description provided for @lookupSectionPurpose.
  ///
  /// In en, this message translates to:
  /// **'What it is for'**
  String get lookupSectionPurpose;

  /// No description provided for @lookupSectionWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get lookupSectionWarnings;

  /// No description provided for @lookupSectionDoNotUse.
  ///
  /// In en, this message translates to:
  /// **'Do not use'**
  String get lookupSectionDoNotUse;

  /// No description provided for @lookupSectionAskDoctor.
  ///
  /// In en, this message translates to:
  /// **'Ask a doctor'**
  String get lookupSectionAskDoctor;

  /// No description provided for @lookupSectionStopUse.
  ///
  /// In en, this message translates to:
  /// **'Stop use and ask a doctor'**
  String get lookupSectionStopUse;

  /// No description provided for @lookupSectionPregnancy.
  ///
  /// In en, this message translates to:
  /// **'If pregnant or breastfeeding'**
  String get lookupSectionPregnancy;

  /// The FDA's name for the most serious warning a label can carry. Kept as the label calls it, because the label's own text refers to it by this name.
  ///
  /// In en, this message translates to:
  /// **'Boxed warning'**
  String get lookupSectionBoxedWarning;

  /// No description provided for @lookupSectionUses.
  ///
  /// In en, this message translates to:
  /// **'Uses'**
  String get lookupSectionUses;

  /// Section headings on a prescription label are the label's own, because its text refers to them by name: "see Warnings and Precautions (5.1)".
  ///
  /// In en, this message translates to:
  /// **'Contraindications'**
  String get lookupSectionContraindications;

  /// No description provided for @lookupSectionWarningsAndPrecautions.
  ///
  /// In en, this message translates to:
  /// **'Warnings and precautions'**
  String get lookupSectionWarningsAndPrecautions;

  /// No description provided for @lookupSectionPrecautions.
  ///
  /// In en, this message translates to:
  /// **'Precautions'**
  String get lookupSectionPrecautions;

  /// No description provided for @lookupSectionInteractions.
  ///
  /// In en, this message translates to:
  /// **'Drug interactions'**
  String get lookupSectionInteractions;

  /// No description provided for @lookupSectionSpecificPopulations.
  ///
  /// In en, this message translates to:
  /// **'Use in specific populations'**
  String get lookupSectionSpecificPopulations;

  /// No description provided for @lookupSectionPregnancyLabel.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get lookupSectionPregnancyLabel;

  /// No description provided for @lookupSectionNursingMothers.
  ///
  /// In en, this message translates to:
  /// **'Nursing mothers'**
  String get lookupSectionNursingMothers;

  /// No description provided for @lookupSectionAskDoctorOrPharmacist.
  ///
  /// In en, this message translates to:
  /// **'Ask a doctor or pharmacist'**
  String get lookupSectionAskDoctorOrPharmacist;

  /// No description provided for @lookupSectionWhenUsing.
  ///
  /// In en, this message translates to:
  /// **'When using this product'**
  String get lookupSectionWhenUsing;

  /// No description provided for @lookupSearchOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Not here?'**
  String get lookupSearchOnlineTitle;

  /// No description provided for @lookupSearchOnlineBody.
  ///
  /// In en, this message translates to:
  /// **'This app has no internet access, so it cannot look anything up for you. It can open your browser instead.'**
  String get lookupSearchOnlineBody;

  /// No description provided for @lookupSearchOnlineAction.
  ///
  /// In en, this message translates to:
  /// **'Open a browser'**
  String get lookupSearchOnlineAction;

  /// No description provided for @lookupLeavingTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaving the app'**
  String get lookupLeavingTitle;

  /// The confirmation before a browser hand-off. It has to be specific about what changes: this app makes no requests, the browser does, and the browser remembers.
  ///
  /// In en, this message translates to:
  /// **'The request comes from your browser rather than from this app. The search leaves your device, and your browser normally keeps it in its history and may sync it to other devices you are signed in on.'**
  String get lookupLeavingBody;

  /// Shown only when a term is pre-filled. Naming the term back to the user is the point — a hand-off that silently carries a drug name into browser history is the thing this warning exists to prevent.
  ///
  /// In en, this message translates to:
  /// **'The words \"{term}\" will be put into the search box, and will appear in your browser history.'**
  String lookupLeavingWithTermBody(String term);

  /// No description provided for @lookupLeavingContinue.
  ///
  /// In en, this message translates to:
  /// **'Open browser'**
  String get lookupLeavingContinue;

  /// No description provided for @lookupLeavingFailed.
  ///
  /// In en, this message translates to:
  /// **'No browser could be opened.'**
  String get lookupLeavingFailed;

  /// No description provided for @checkerTitle.
  ///
  /// In en, this message translates to:
  /// **'Check medicines together'**
  String get checkerTitle;

  /// No description provided for @checkerEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What the US labels of medicines, and NCCIH\'s fact sheets on herbs, say about each other.'**
  String get checkerEntrySubtitle;

  /// The checker's first paragraph. It says what the check reads and what it cannot conclude before anyone adds a medicine (ADR-0014).
  ///
  /// In en, this message translates to:
  /// **'Add two or more medicines, or a herbal supplement and a medicine. For each pair, this shows whether they share an ingredient, an FDA drug class or a group such as “NSAIDs”, and quotes any place where one label names the other or a group it is in. A herb is compared by NCCIH\'s fact sheet on it. It reads the labels and the fact sheets and nothing else, so it cannot tell you that a combination is safe.'**
  String get checkerIntro;

  /// No description provided for @checkerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a medicine'**
  String get checkerAdd;

  /// Tooltip, and what a screen reader says, for the button that takes a medicine off a list.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String checkerRemove(String name);

  /// No description provided for @checkerNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Add at least two medicines to compare them.'**
  String get checkerNeedTwo;

  /// No description provided for @checkerFull.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} medicines and herbs can be compared at once.'**
  String checkerFull(int count);

  /// No description provided for @checkerAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} is already on the list.'**
  String checkerAlreadyAdded(String name);

  /// The progress bar's label for a screen reader, while the labels being compared load.
  ///
  /// In en, this message translates to:
  /// **'Reading the labels'**
  String get checkerLoading;

  /// No description provided for @checkerFailed.
  ///
  /// In en, this message translates to:
  /// **'The labels could not be read.'**
  String get checkerFailed;

  /// No description provided for @checkerPairTitle.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String checkerPairTitle(String first, String second);

  /// Two medicines with the same ingredient can add up to more of it than either label allows on its own.
  ///
  /// In en, this message translates to:
  /// **'Both contain {names}.'**
  String checkerSharedSubstance(String names);

  /// The FDA's established pharmacologic classes, by their own names: "Nonsteroidal Anti-inflammatory Drug".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Both are in the FDA drug class {classes}.} other{Both are in the FDA drug classes {classes}.}}'**
  String checkerSharedClass(int count, String classes);

  /// Above a passage quoted from one label that names the other medicine. The words are as the label prints them.
  ///
  /// In en, this message translates to:
  /// **'The {medicine} label mentions “{words}”. From {section}:'**
  String checkerMentionsName(String medicine, String words, String section);

  /// Above a passage quoted from one label that names a class the other medicine is in.
  ///
  /// In en, this message translates to:
  /// **'The {medicine} label mentions “{words}”, an FDA drug class that includes {other}. From {section}:'**
  String checkerMentionsClass(
    String medicine,
    String words,
    String other,
    String section,
  );

  /// A conflict flag's reason, where there is no room for the passage itself.
  ///
  /// In en, this message translates to:
  /// **'The {medicine} label mentions “{words}”.'**
  String checkerMentionsNameShort(String medicine, String words);

  /// No description provided for @checkerMentionsClassShort.
  ///
  /// In en, this message translates to:
  /// **'The {medicine} label mentions “{words}”, an FDA drug class that includes {other}.'**
  String checkerMentionsClassShort(String medicine, String words, String other);

  /// Above a passage quoted from one label that names a group the other medicine is in, such as NSAIDs. Which medicines a group takes in comes from a sourced table (ADR-0021), and its sources are named under the passage.
  ///
  /// In en, this message translates to:
  /// **'The {medicine} label mentions “{words}”, a group that includes {other}. From {section}:'**
  String checkerMentionsGroup(
    String medicine,
    String words,
    String other,
    String section,
  );

  /// No description provided for @checkerMentionsGroupShort.
  ///
  /// In en, this message translates to:
  /// **'The {medicine} label mentions “{words}”, a group that includes {other}.'**
  String checkerMentionsGroupShort(String medicine, String words, String other);

  /// A label naming an ingredient every product of a recorded kind of contraception contains, such as levonorgestrel in hormonal IUDs. The kind is in the plural, as conditionKind* gives it.
  ///
  /// In en, this message translates to:
  /// **'The {medicine} label mentions “{words}”, which {kind} contain.'**
  String checkerMentionsKindName(String medicine, String words, String kind);

  /// No description provided for @checkerMentionsKindNameFrom.
  ///
  /// In en, this message translates to:
  /// **'The {medicine} label mentions “{words}”, which {kind} contain. From {section}:'**
  String checkerMentionsKindNameFrom(
    String medicine,
    String words,
    String kind,
    String section,
  );

  /// Two medicines in a group of the sourced table, by its name in the plural: "NSAIDs", "combined oral contraceptives".
  ///
  /// In en, this message translates to:
  /// **'Both are {groups}.'**
  String checkerSharedGroup(String groups);

  /// Under a passage naming a group: where the table's list of the group's medicines comes from. Each source is its title and who published it.
  ///
  /// In en, this message translates to:
  /// **'Which medicines are {group}: {sources}.'**
  String checkerGroupSources(String group, String sources);

  /// On every pair the labels do not connect, in the checker and under Conditions and medication, beside a way to look the pair up online. Worded by the owner. It must not read as a reassurance.
  ///
  /// In en, this message translates to:
  /// **'No labels connect these two medications, but you are advised to verify the results.'**
  String get checkerNothingFoundPair;

  /// Shown wherever the labels connect a pair in none of the ways the check looks for. It must never read as a reassurance; interaction_copy_test bans the words that would make it one.
  ///
  /// In en, this message translates to:
  /// **'That does not mean they are safe together. Labels leave interactions out, and often name medicines by a group this check does not know, such as “anticoagulants” or “strong CYP3A4 inducers”.'**
  String get checkerNothingFoundNote;

  /// No description provided for @checkerSearchOnline.
  ///
  /// In en, this message translates to:
  /// **'Look this pair up online'**
  String get checkerSearchOnline;

  /// What is put into the browser's search box for a pair. Named back to the user before the browser opens.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second} interaction'**
  String checkerSearchTerm(String first, String second);

  /// No description provided for @checkerAskPharmacist.
  ///
  /// In en, this message translates to:
  /// **'Only a pharmacist or doctor who knows your situation can say whether these medicines are right for you together. Show them this list, or the packets.'**
  String get checkerAskPharmacist;

  /// No description provided for @checkerPickerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type the name of a medicine, a brand or an ingredient.'**
  String get checkerPickerPrompt;

  /// No description provided for @checkerAddSupplement.
  ///
  /// In en, this message translates to:
  /// **'Add a herbal supplement'**
  String get checkerAddSupplement;

  /// Under a herb on the checker's list, where a medicine says how it is taken.
  ///
  /// In en, this message translates to:
  /// **'Herbal supplement · NCCIH fact sheet'**
  String get checkerSupplementKind;

  /// On the checker while its list holds herbs and no medicine (ADR-0023).
  ///
  /// In en, this message translates to:
  /// **'Add a medicine to compare with. Herbs are compared with medicines, not with each other.'**
  String get checkerNeedMedicine;

  /// On the checker when two or more herbs are listed. No fact sheet's safety section names another of the herbs, and two herbs have no label between them.
  ///
  /// In en, this message translates to:
  /// **'Herbs are compared with the medicines on the list, not with each other.'**
  String get checkerHerbsNotCompared;

  /// A medicine whose own ingredients include the herb, as many homeopathic remedies' do. The ingredients are as its label prints them.
  ///
  /// In en, this message translates to:
  /// **'The {medicine} label lists {herb} among its active ingredients, as “{ingredients}”.'**
  String checkerSupplementIngredient(
    String medicine,
    String herb,
    String ingredients,
  );

  /// Above a passage quoted from a herb's fact sheet that names the medicine. The section is the sheet's own heading, "What Do We Know About Safety?".
  ///
  /// In en, this message translates to:
  /// **'NCCIH\'s fact sheet on {herb} mentions “{words}”. From “{section}”:'**
  String checkerSheetMentionsName(String herb, String words, String section);

  /// No description provided for @checkerSheetMentionsClass.
  ///
  /// In en, this message translates to:
  /// **'NCCIH\'s fact sheet on {herb} mentions “{words}”, an FDA drug class that includes {other}. From “{section}”:'**
  String checkerSheetMentionsClass(
    String herb,
    String words,
    String other,
    String section,
  );

  /// As checkerMentionsGroup, for a fact sheet: "Birth control pills" names the oral contraceptives.
  ///
  /// In en, this message translates to:
  /// **'NCCIH\'s fact sheet on {herb} mentions “{words}”, a group that includes {other}. From “{section}”:'**
  String checkerSheetMentionsGroup(
    String herb,
    String words,
    String other,
    String section,
  );

  /// On every herb and medicine the label and the fact sheet do not connect, beside a way to look the pair up online. As checkerNothingFoundPair, it must not read as a reassurance.
  ///
  /// In en, this message translates to:
  /// **'Neither the label nor NCCIH\'s fact sheet connects these two, but you are advised to verify the results.'**
  String get checkerNothingFoundSupplementPair;

  /// Shown wherever a herb and a medicine are connected in none of the ways the check looks for. interaction_copy_test bans the words that would make it a reassurance.
  ///
  /// In en, this message translates to:
  /// **'That does not mean they are safe together. NCCIH\'s fact sheets name only some of the medicines a herb interacts with, and often by a kind, such as “some antidepressants”.'**
  String get checkerNothingFoundSheetNote;

  /// The heading over the herbs a search on Look something up found.
  ///
  /// In en, this message translates to:
  /// **'Herbal supplements'**
  String get lookupSupplementsHeading;

  /// Opens NCCIH's fact sheets (ADR-0023). Not the Supplements page under Learn, which is about nutrition and stays hidden behind the ten-second hold.
  ///
  /// In en, this message translates to:
  /// **'Herbal supplements A to Z'**
  String get lookupSupplementsEntry;

  /// No description provided for @lookupSupplementsEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'NCCIH\'s fact sheets on {count} herbs, such as St. John’s wort, from the US National Institutes of Health.'**
  String lookupSupplementsEntrySubtitle(int count);

  /// No description provided for @supplementsIntro.
  ///
  /// In en, this message translates to:
  /// **'Fact sheets from the National Center for Complementary and Integrative Health (NCCIH), part of the US National Institutes of Health, as they stood on {date}. They are in the public domain, and are shown as NCCIH wrote them.'**
  String supplementsIntro(String date);

  /// No description provided for @supplementsLoading.
  ///
  /// In en, this message translates to:
  /// **'Opening the herbal supplements reference'**
  String get supplementsLoading;

  /// No description provided for @supplementsFailed.
  ///
  /// In en, this message translates to:
  /// **'The herbal supplements reference could not be opened.'**
  String get supplementsFailed;

  /// Under a herb a search found by a common or Latin name that is not its title.
  ///
  /// In en, this message translates to:
  /// **'Also called {name}'**
  String supplementsFoundBy(String name);

  /// No description provided for @supplementsCommonNames.
  ///
  /// In en, this message translates to:
  /// **'Common names: {names}'**
  String supplementsCommonNames(String names);

  /// No description provided for @supplementsLatinNames.
  ///
  /// In en, this message translates to:
  /// **'Latin names: {names}'**
  String supplementsLatinNames(String names);

  /// The date is as NCCIH prints it, such as "May 2025".
  ///
  /// In en, this message translates to:
  /// **'From NCCIH\'s fact sheet, last updated {date}. It is in the public domain.'**
  String supplementsSource(String date);

  /// The page's address, shown and never opened: the app has no internet access (ADR-0004).
  ///
  /// In en, this message translates to:
  /// **'NCCIH publishes it at {url}.'**
  String supplementsAddress(String url);

  /// No description provided for @supplementsPhoto.
  ///
  /// In en, this message translates to:
  /// **'NCCIH\'s photograph of the plant is not in the public domain, so it is left out.'**
  String get supplementsPhoto;

  /// No description provided for @supplementsCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare with medicines'**
  String get supplementsCompare;

  /// No description provided for @lookupMedicineCheck.
  ///
  /// In en, this message translates to:
  /// **'Check with other medicines'**
  String get lookupMedicineCheck;

  /// No description provided for @settingsLookup.
  ///
  /// In en, this message translates to:
  /// **'Look something up'**
  String get settingsLookup;

  /// No description provided for @settingsLookupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Medicines from US drug labelling, stored on this device.'**
  String get settingsLookupSubtitle;

  /// No description provided for @nutritionTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplements'**
  String get nutritionTitle;

  /// The framing sentence for the whole screen. It has to establish that the page is reference text and not addressed to the reader personally, before any nutrient is named.
  ///
  /// In en, this message translates to:
  /// **'Reference notes on the nutrients that come up around menstrual cycles. This is background reading, not advice about your body, and nothing here is based on what you have logged.'**
  String get nutritionIntro;

  /// No description provided for @nutritionIronTitle.
  ///
  /// In en, this message translates to:
  /// **'Iron'**
  String get nutritionIronTitle;

  /// No description provided for @nutritionIronBody.
  ///
  /// In en, this message translates to:
  /// **'Iron is part of haemoglobin, the protein that carries oxygen around the blood. Menstrual bleeding is one of the ways the body loses iron, and heavier bleeding means more of it. Heavy menstrual bleeding is a recognised cause of iron deficiency anaemia, whose commonly listed symptoms include tiredness and lack of energy.'**
  String get nutritionIronBody;

  /// Sits directly under the iron text. The claim that stops the section reading as a checklist the reader can apply to themselves.
  ///
  /// In en, this message translates to:
  /// **'A blood test is what establishes iron deficiency. Symptoms alone cannot, and nothing in this app can.'**
  String get nutritionIronDiagnosisNote;

  /// No description provided for @nutritionIronSourcesBody.
  ///
  /// In en, this message translates to:
  /// **'Dietary iron comes in two forms: haem iron from meat and fish, and non-haem iron from plants and fortified foods. They are absorbed differently.'**
  String get nutritionIronSourcesBody;

  /// No description provided for @nutritionVitaminCTitle.
  ///
  /// In en, this message translates to:
  /// **'Vitamin C'**
  String get nutritionVitaminCTitle;

  /// No description provided for @nutritionVitaminCBody.
  ///
  /// In en, this message translates to:
  /// **'Vitamin C eaten in the same meal increases how much non-haem iron the body absorbs.'**
  String get nutritionVitaminCBody;

  /// No description provided for @nutritionIronCautionBody.
  ///
  /// In en, this message translates to:
  /// **'Iron supplements taken without a confirmed deficiency can do harm, because excess iron accumulates rather than being cleared.'**
  String get nutritionIronCautionBody;

  /// No description provided for @nutritionMagnesiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Magnesium'**
  String get nutritionMagnesiumTitle;

  /// No description provided for @nutritionMagnesiumBody.
  ///
  /// In en, this message translates to:
  /// **'Magnesium is involved in muscle and nerve function, among many other processes. It is found in green leafy vegetables, legumes, nuts, seeds and wholegrains.'**
  String get nutritionMagnesiumBody;

  /// Must not be dropped for brevity. It is the claim that stops the magnesium section reading as a recommendation.
  ///
  /// In en, this message translates to:
  /// **'Magnesium is widely taken for cramps and premenstrual symptoms. Oral forms differ in how well they are absorbed, with glycinate and citrate better absorbed than oxide.'**
  String get nutritionMagnesiumEvidenceBody;

  /// No description provided for @nutritionMagnesiumCreamBody.
  ///
  /// In en, this message translates to:
  /// **'Creams, oils and balms are sold for the same purpose.'**
  String get nutritionMagnesiumCreamBody;

  /// No description provided for @nutritionZincTitle.
  ///
  /// In en, this message translates to:
  /// **'Zinc'**
  String get nutritionZincTitle;

  /// No description provided for @nutritionZincBody.
  ///
  /// In en, this message translates to:
  /// **'Zinc is an essential mineral involved in immune function and wound healing. It is often sold together with magnesium, which matters here because at high doses over time zinc can interfere with how the body absorbs copper.'**
  String get nutritionZincBody;

  /// No description provided for @nutritionHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Something worth mentioning'**
  String get nutritionHintTitle;

  /// PINNED WORDING — nutrition_copy_test.dart asserts this string exactly. It observes two things the user logged and points at a human. It must not name a nutrient, a deficiency, or a supplement, and must not say what the pattern means.
  ///
  /// In en, this message translates to:
  /// **'On several days recently you logged heavy flow and fatigue together. That pattern is worth raising with a doctor or nurse, who can look into it properly.'**
  String get nutritionHintBody;

  /// No description provided for @settingsNutrition.
  ///
  /// In en, this message translates to:
  /// **'Supplements'**
  String get settingsNutrition;

  /// No description provided for @settingsNutritionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reference notes on the nutrients that come up around menstrual cycles.'**
  String get settingsNutritionSubtitle;

  /// No description provided for @weightTitle.
  ///
  /// In en, this message translates to:
  /// **'Body composition and cycle hormones'**
  String get weightTitle;

  /// The framing sentence for the whole screen. It has to establish that the page is reference text about mechanisms, not addressed to the reader, before anything else is named.
  ///
  /// In en, this message translates to:
  /// **'Reference notes on how body composition and several hormones interact with the menstrual cycle. This is background reading, not advice, and it describes mechanisms rather than any particular body. Nothing on this page is drawn from anything logged in this app.'**
  String get weightIntro;

  /// No description provided for @weightOestrogenTitle.
  ///
  /// In en, this message translates to:
  /// **'Where oestrogen is made'**
  String get weightOestrogenTitle;

  /// No description provided for @weightOestrogenBody.
  ///
  /// In en, this message translates to:
  /// **'Adipose tissue, or body fat, makes the enzyme aromatase, which converts androgens into oestrogens. That reaction happens in the tissue itself, so the ovaries are not the only place oestrogen comes from.'**
  String get weightOestrogenBody;

  /// Both ends of the mechanism, deliberately. Stated in one direction only this becomes an argument, and an argument is what this section must never be.
  ///
  /// In en, this message translates to:
  /// **'The quantity of adipose tissue is therefore one of the inputs to how much oestrogen is circulating, and it runs in both directions: more of it adds to the total, and very little of it removes a source the ovaries do not make up for. It is one input among several.'**
  String get weightOestrogenBalanceBody;

  /// No description provided for @weightEnergyTitle.
  ///
  /// In en, this message translates to:
  /// **'Energy availability and the hypothalamus'**
  String get weightEnergyTitle;

  /// No description provided for @weightEnergyBody.
  ///
  /// In en, this message translates to:
  /// **'The brain drives the ovaries through a steady rhythm of hormone signals. When the body is running on too little energy that rhythm is suppressed: the signals fall away, ovulation stops, and periods stop with it. The name for that state is functional hypothalamic amenorrhoea.'**
  String get weightEnergyBody;

  /// Load-bearing. Without it the section reads as a statement about a number on a scale, which is both wrong and the most harmful thing this reference could be mistaken for.
  ///
  /// In en, this message translates to:
  /// **'Energy availability is the energy left over from food once exercise has taken its share, measured against what the body needs to run on. It is a balance between what goes in and what is spent, and a scale reads neither. It happens at entirely unremarkable body weights, and heavy training, illness or sustained stress can bring it on while weight holds steady.'**
  String get weightEnergyNotAScaleBody;

  /// No description provided for @weightInsulinTitle.
  ///
  /// In en, this message translates to:
  /// **'Insulin, SHBG and free androgen'**
  String get weightInsulinTitle;

  /// No description provided for @weightInsulinBody.
  ///
  /// In en, this message translates to:
  /// **'Sex hormone binding globulin, or SHBG, is a protein the liver puts into the blood, where it binds testosterone. Bound testosterone is held out of circulation, so only the free fraction reaches tissue. Insulin resistance lowers SHBG, and as SHBG falls the free fraction rises, even when the total amount of testosterone has not changed.'**
  String get weightInsulinBody;

  /// No description provided for @weightPcosTitle.
  ///
  /// In en, this message translates to:
  /// **'PMOS'**
  String get weightPcosTitle;

  /// No description provided for @weightPcosBody.
  ///
  /// In en, this message translates to:
  /// **'Polyendocrine metabolic ovarian syndrome, formerly polycystic ovary syndrome, is androgen excess together with irregular or absent ovulation. Insulin resistance is common alongside it, and the mechanism above is part of how the androgen excess is sustained.'**
  String get weightPcosBody;

  /// Must not be dropped. The opposite impression is both common and false, and naming PCOS in a section about body composition without saying this would reinforce the error.
  ///
  /// In en, this message translates to:
  /// **'PMOS occurs across the whole weight spectrum, including in people who are thin. The widespread impression that it belongs at one end is wrong, and it is one reason the condition goes unrecognised.'**
  String get weightPcosSpectrumBody;

  /// No description provided for @weightThyroidTitle.
  ///
  /// In en, this message translates to:
  /// **'Thyroid function'**
  String get weightThyroidTitle;

  /// No description provided for @weightThyroidBody.
  ///
  /// In en, this message translates to:
  /// **'Thyroid disease affects the menstrual cycle too, in both directions. An underactive thyroid is associated with heavier and more frequent bleeding; an overactive one with lighter, less frequent bleeding, or with none. Thyroid function is established by a blood test rather than by the shape of a cycle.'**
  String get weightThyroidBody;

  /// No description provided for @weightChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'When a cycle changes'**
  String get weightChangeTitle;

  /// The last thing on the screen. A page of mechanisms with no exit is an invitation to pick one, so this points at a person. Deliberately carries no threshold: a threshold is a number, and a number here is something to measure a body against.
  ///
  /// In en, this message translates to:
  /// **'A change in cycle length, in the amount of bleeding, or in whether periods arrive at all has many possible causes, and the mechanisms on this page are only some of them. Cycle dates cannot separate one cause from another, and nothing in this app can diagnose anything. A doctor or nurse is who can work out which one it is.'**
  String get weightChangeBody;

  /// No description provided for @weightEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Body composition and cycle hormones'**
  String get weightEntryTitle;

  /// No description provided for @weightEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How body fat, energy availability, insulin and thyroid function interact with the cycle.'**
  String get weightEntrySubtitle;

  /// No description provided for @movementTitle.
  ///
  /// In en, this message translates to:
  /// **'Pain and movement across the cycle'**
  String get movementTitle;

  /// The framing sentence for the whole screen. It has to establish that the page is reference text about a subject, not addressed to the reader and not a plan, before anything else is named.
  ///
  /// In en, this message translates to:
  /// **'Reference notes on period pain, on what movement does about it, and on how well the evidence supports the popular advice. This is background reading, not advice, and it describes what is known about bodies in general. It draws on nothing you have logged.'**
  String get movementIntro;

  /// No description provided for @movementPainTitle.
  ///
  /// In en, this message translates to:
  /// **'What period pain is'**
  String get movementPainTitle;

  /// No description provided for @movementPainBody.
  ///
  /// In en, this message translates to:
  /// **'Painful menstruation with no underlying disorder behind it is called primary dysmenorrhoea. The pain is typically cramping, felt low in the abdomen, strongest around the start of bleeding and easing over the following days. Prostaglandins released from the lining of the uterus drive the contractions that produce it. Where there is an underlying cause, such as endometriosis, adenomyosis or uterine fibroids, the term is secondary dysmenorrhoea.'**
  String get movementPainBody;

  /// No description provided for @movementNotAvoidedTitle.
  ///
  /// In en, this message translates to:
  /// **'A period is not a reason to stop moving'**
  String get movementNotAvoidedTitle;

  /// The correction this section exists for. The popular version of this subject says the opposite, and a cycle app repeating it would be telling people to stop doing something that helps them.
  ///
  /// In en, this message translates to:
  /// **'Menstruation is not named anywhere in the sources behind this page as a reason to stop, and general physical activity guidance makes no exception for the days of a period.'**
  String get movementNotAvoidedBody;

  /// No description provided for @movementHowItFeelsTitle.
  ///
  /// In en, this message translates to:
  /// **'What changes is how it feels'**
  String get movementHowItFeelsTitle;

  /// No description provided for @movementHowItFeelsBody.
  ///
  /// In en, this message translates to:
  /// **'What varies across a cycle is how moving feels. Cramping pain around the start of bleeding, tiredness and low energy in the days before and during it, and how hard a given effort seems on the day are all part of that. The variation is wide between people, and wide between one cycle and the next in the same person, which is why none of it turns into a rule.'**
  String get movementHowItFeelsBody;

  /// No description provided for @movementRestTitle.
  ///
  /// In en, this message translates to:
  /// **'Doing less is allowed'**
  String get movementRestTitle;

  /// Permission, never instruction. The requested version of this section was an instruction to rest, which is the same category error as an exercise prescription and is stated here as one.
  ///
  /// In en, this message translates to:
  /// **'If you want to do less on a given day, or nothing at all, that is a reasonable choice. This page gives you permission rather than instructions: it holds you to no target, so there is nothing here to fall short of.'**
  String get movementRestBody;

  /// No description provided for @movementStopSignalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Signals to stop'**
  String get movementStopSignalsTitle;

  /// No description provided for @movementStopSignalsBody.
  ///
  /// In en, this message translates to:
  /// **'Some things are reasons to stop. Feeling faint or light-headed during exertion, breathlessness out of proportion to the effort, and chest pain are among them, and each is worth getting looked at. None of this is particular to menstruation. It applies whenever it happens.'**
  String get movementStopSignalsBody;

  /// The same claim the iron section makes, cited to the same sources in MOVEMENT_SOURCES.md and NUTRITION_SOURCES.md so the two cannot drift. It is here because it explains a hard day without blaming the cycle for it.
  ///
  /// In en, this message translates to:
  /// **'Exertion can feel harder around heavy periods, and there is a recognised reason for it. Heavy menstrual bleeding is a known cause of iron deficiency anaemia, whose commonly listed symptoms include tiredness, lack of energy and shortness of breath. A blood test is what confirms iron deficiency, rather than how a day felt, and it is worth taking to a doctor or nurse.'**
  String get movementAnaemiaBody;

  /// No description provided for @movementPhaseClaimsTitle.
  ///
  /// In en, this message translates to:
  /// **'Planning exercise around cycle phase'**
  String get movementPhaseClaimsTitle;

  /// Says outright that the evidence is weak rather than quietly declining to use it. A reference that handed someone a prescription built on evidence this thin would be worse than one that says how thin it is.
  ///
  /// In en, this message translates to:
  /// **'Schemes that assign different kinds of exercise to different parts of the cycle are widely promoted. The evidence underneath them is weak. Systematic review of cycle phase and exercise performance describes that research as low quality and inconsistent: the average effects are trivial, and the differences between individuals are larger than the effect being looked for. No clinical guidance in the sources behind this page recommends planning exercise around cycle phase, and none says the chance of injury rises or falls with it.'**
  String get movementPhaseClaimsBody;

  /// No description provided for @movementContraceptionBody.
  ///
  /// In en, this message translates to:
  /// **'Hormonal contraception is another reason these schemes do not carry over. The combined pill works by stopping ovulation, so the rise and fall of oestrogen and progesterone that a phase-based plan assumes is not happening at all. A plan built on cycle phases has nothing underneath it when those phases are not occurring.'**
  String get movementContraceptionBody;

  /// No description provided for @movementSeeSomeoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Pain worth taking to someone'**
  String get movementSeeSomeoneTitle;

  /// The last thing on the screen, pointing at a person. Deliberately carries no threshold and no pain scale: both are numbers, and a number here is something to be talked out of by.
  ///
  /// In en, this message translates to:
  /// **'Period pain that is severe, that is getting worse, that the usual measures do not ease, or that gets in the way of ordinary days is a reason to see a doctor or nurse. So is pain that began later in life, changed in character, or arrives alongside other symptoms. The causes named above are found by assessment rather than by tracking dates. No threshold is offered here, and no scale for you to score yourself against.'**
  String get movementSeeSomeoneBody;

  /// No description provided for @movementEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Pain and movement across the cycle'**
  String get movementEntryTitle;

  /// No description provided for @movementEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What exercise does about period pain, how weak the evidence for planning it by cycle phase is, and what is a reason to stop.'**
  String get movementEntrySubtitle;

  /// No description provided for @conditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conditions and medication'**
  String get conditionsTitle;

  /// Under the screen title. States plainly that these do not reach the model, so nobody expects predictions to improve after entering them.
  ///
  /// In en, this message translates to:
  /// **'Things that can change your cycle. Recorded so you can read your own history with them in mind. They are not used to work out your predictions.'**
  String get conditionsSubtitle;

  /// No description provided for @conditionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded.'**
  String get conditionsEmpty;

  /// No description provided for @conditionsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get conditionsAdd;

  /// No description provided for @conditionsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a condition'**
  String get conditionsAddTitle;

  /// No description provided for @conditionsStarted.
  ///
  /// In en, this message translates to:
  /// **'Started {date}'**
  String conditionsStarted(String date);

  /// No description provided for @conditionsSpan.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String conditionsSpan(String start, String end);

  /// No description provided for @conditionsOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get conditionsOngoing;

  /// No description provided for @conditionsEnd.
  ///
  /// In en, this message translates to:
  /// **'Mark as ended'**
  String get conditionsEnd;

  /// No description provided for @conditionsReopen.
  ///
  /// In en, this message translates to:
  /// **'Still ongoing'**
  String get conditionsReopen;

  /// No description provided for @conditionsRemove.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get conditionsRemove;

  /// No description provided for @conditionsStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get conditionsStartDate;

  /// No description provided for @conditionsEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get conditionsEndDate;

  /// The whole reason spans are stored rather than flags. A flag cannot say this.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 cycle logged while this was recorded} other{{count} cycles logged while this was recorded}}'**
  String conditionsOverlap(int count);

  /// No description provided for @conditionsMedicinesHeading.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get conditionsMedicinesHeading;

  /// No description provided for @conditionsMedicinesIntro.
  ///
  /// In en, this message translates to:
  /// **'Medicines you take, picked from the app\'s list of US medicines and kept on this device only. Each is compared with the others using their labels, and with any hormonal contraception recorded above.'**
  String get conditionsMedicinesIntro;

  /// No description provided for @conditionsMedicinesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No medicines recorded.'**
  String get conditionsMedicinesEmpty;

  /// No description provided for @conditionsMedicinesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The medicines list is not built into this version, so medicines cannot be recorded.'**
  String get conditionsMedicinesUnavailable;

  /// Under a recorded medicine that a later refresh of the US data no longer lists. Kept rather than deleted: the user recorded it.
  ///
  /// In en, this message translates to:
  /// **'No longer in this app\'s list of medicines, so it is not compared.'**
  String get conditionsMedicineGone;

  /// No description provided for @conditionsConflictsHeading.
  ///
  /// In en, this message translates to:
  /// **'Possible conflicts'**
  String get conditionsConflictsHeading;

  /// Above the conflict flags. A flag only informs: it says the labels connect two medicines, never that the user should stop or change anything.
  ///
  /// In en, this message translates to:
  /// **'Their labels connect these medicines. That is not a finding about you: a pharmacist can tell you whether it matters.'**
  String get conditionsConflictsIntro;

  /// No description provided for @conditionsConflictLookUp.
  ///
  /// In en, this message translates to:
  /// **'Look it up online'**
  String get conditionsConflictLookUp;

  /// Opens the interaction checker on the flagged pair, where each mention is quoted: a name can be found in a sense the flag cannot show, "lactic" in "lactic acidosis".
  ///
  /// In en, this message translates to:
  /// **'What the labels say'**
  String get conditionsConflictLabels;

  /// Opens the passages quoted from the medicine's label, on a flag pairing it with a recorded kind of contraception, which has no label of its own.
  ///
  /// In en, this message translates to:
  /// **'What the label says'**
  String get conditionsConflictLabel;

  /// On a card pairing a recorded kind of contraception with a medicine (ADR-0021). The kind in the plural, as conditionKind* gives it.
  ///
  /// In en, this message translates to:
  /// **'Compared as what every one of the {kind} in the US list has in common, since the record does not say which.'**
  String conditionsConflictKind(String kind);

  /// The combined pill in a sentence, in the plural: "a group that includes combined pills".
  ///
  /// In en, this message translates to:
  /// **'combined pills'**
  String get conditionKindCombined;

  /// No description provided for @conditionKindProgestogen.
  ///
  /// In en, this message translates to:
  /// **'progestogen-only pills'**
  String get conditionKindProgestogen;

  /// No description provided for @conditionKindIud.
  ///
  /// In en, this message translates to:
  /// **'hormonal IUDs'**
  String get conditionKindIud;

  /// No description provided for @conditionKindImplant.
  ///
  /// In en, this message translates to:
  /// **'contraceptive implants'**
  String get conditionKindImplant;

  /// No description provided for @conditionHormonalContraceptionCombined.
  ///
  /// In en, this message translates to:
  /// **'Combined pill'**
  String get conditionHormonalContraceptionCombined;

  /// No description provided for @conditionHormonalContraceptionProgestogen.
  ///
  /// In en, this message translates to:
  /// **'Progestogen-only pill'**
  String get conditionHormonalContraceptionProgestogen;

  /// No description provided for @conditionHormonalIud.
  ///
  /// In en, this message translates to:
  /// **'Hormonal IUD'**
  String get conditionHormonalIud;

  /// No description provided for @conditionContraceptiveImplant.
  ///
  /// In en, this message translates to:
  /// **'Implant'**
  String get conditionContraceptiveImplant;

  /// No description provided for @conditionCopperIud.
  ///
  /// In en, this message translates to:
  /// **'Copper IUD'**
  String get conditionCopperIud;

  /// No description provided for @conditionPregnancy.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get conditionPregnancy;

  /// No description provided for @conditionPostpartum.
  ///
  /// In en, this message translates to:
  /// **'Postpartum'**
  String get conditionPostpartum;

  /// No description provided for @conditionBreastfeeding.
  ///
  /// In en, this message translates to:
  /// **'Breastfeeding'**
  String get conditionBreastfeeding;

  /// No description provided for @conditionPcos.
  ///
  /// In en, this message translates to:
  /// **'PMOS'**
  String get conditionPcos;

  /// No description provided for @conditionEndometriosis.
  ///
  /// In en, this message translates to:
  /// **'Endometriosis'**
  String get conditionEndometriosis;

  /// No description provided for @conditionThyroidDisorder.
  ///
  /// In en, this message translates to:
  /// **'Thyroid disorder'**
  String get conditionThyroidDisorder;

  /// No description provided for @conditionPerimenopause.
  ///
  /// In en, this message translates to:
  /// **'Perimenopause'**
  String get conditionPerimenopause;

  /// No description provided for @conditionUterineFibroids.
  ///
  /// In en, this message translates to:
  /// **'Uterine fibroids'**
  String get conditionUterineFibroids;

  /// No description provided for @conditionOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get conditionOther;

  /// No description provided for @settingsConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions and medication'**
  String get settingsConditions;

  /// No description provided for @settingsConditionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record long-term things that can change your cycle, and the medicines you take.'**
  String get settingsConditionsSubtitle;

  /// No description provided for @learnTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learnTitle;

  /// No description provided for @learnIntro.
  ///
  /// In en, this message translates to:
  /// **'Notes that are intended for your perusal and assistance.'**
  String get learnIntro;

  /// No description provided for @learnReferenceSection.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get learnReferenceSection;

  /// No description provided for @learnYourRecordSection.
  ///
  /// In en, this message translates to:
  /// **'Your record'**
  String get learnYourRecordSection;

  /// After the Learn tab has been held for ten seconds. Says what changed, since nothing on screen asked for it.
  ///
  /// In en, this message translates to:
  /// **'Supplements, Pain and movement, and Body composition are now listed in Learn.'**
  String get learnHiddenPagesShown;

  /// No description provided for @learnHiddenPagesHidden.
  ///
  /// In en, this message translates to:
  /// **'Supplements, Pain and movement, and Body composition are hidden again.'**
  String get learnHiddenPagesHidden;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Colour scheme and light or dark.'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceSchemeSection.
  ///
  /// In en, this message translates to:
  /// **'Colour scheme'**
  String get appearanceSchemeSection;

  /// No description provided for @appearanceSchemeNote.
  ///
  /// In en, this message translates to:
  /// **'Every scheme here was measured for contrast before it was offered. Pick the one you like.'**
  String get appearanceSchemeNote;

  /// No description provided for @appearanceThemeSection.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceThemeSection;

  /// No description provided for @appearanceThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceThemeSystem;

  /// No description provided for @appearanceThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceThemeLight;

  /// No description provided for @appearanceThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceThemeDark;

  /// No description provided for @appearanceThemeLockedByScheme.
  ///
  /// In en, this message translates to:
  /// **'Night is a dark scheme, so there is nothing to switch here. Pick another scheme to get the choice back.'**
  String get appearanceThemeLockedByScheme;

  /// No description provided for @appearanceSchemeSelected.
  ///
  /// In en, this message translates to:
  /// **'{scheme}, selected'**
  String appearanceSchemeSelected(String scheme);

  /// No description provided for @appearanceSchemeRose.
  ///
  /// In en, this message translates to:
  /// **'Rose & Plum'**
  String get appearanceSchemeRose;

  /// No description provided for @appearanceSchemeRoseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Warm, soft'**
  String get appearanceSchemeRoseSubtitle;

  /// No description provided for @appearanceSchemeSage.
  ///
  /// In en, this message translates to:
  /// **'Sage & Apricot'**
  String get appearanceSchemeSage;

  /// No description provided for @appearanceSchemeSageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Calm, botanical'**
  String get appearanceSchemeSageSubtitle;

  /// No description provided for @appearanceSchemeLilac.
  ///
  /// In en, this message translates to:
  /// **'Lilac & Sage'**
  String get appearanceSchemeLilac;

  /// No description provided for @appearanceSchemeLilacSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cool, quiet'**
  String get appearanceSchemeLilacSubtitle;

  /// No description provided for @appearanceSchemePeriwinkle.
  ///
  /// In en, this message translates to:
  /// **'Periwinkle & Clay'**
  String get appearanceSchemePeriwinkle;

  /// No description provided for @appearanceSchemePeriwinkleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Soft blue, terracotta'**
  String get appearanceSchemePeriwinkleSubtitle;

  /// No description provided for @appearanceSchemeInk.
  ///
  /// In en, this message translates to:
  /// **'Ink & Ochre'**
  String get appearanceSchemeInk;

  /// No description provided for @appearanceSchemeInkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Near-monochrome, discreet'**
  String get appearanceSchemeInkSubtitle;

  /// No description provided for @appearanceSchemeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get appearanceSchemeNight;

  /// No description provided for @appearanceSchemeNightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dark from the start'**
  String get appearanceSchemeNightSubtitle;

  /// No description provided for @settingsDisplaySection.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplaySection;

  /// No description provided for @settingsFlowSimplified.
  ///
  /// In en, this message translates to:
  /// **'Simple flow'**
  String get settingsFlowSimplified;

  /// No description provided for @settingsFlowSimplifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record bleeding as yes or no rather than an intensity. Anything already recorded is kept, and comes back if you turn this off.'**
  String get settingsFlowSimplifiedSubtitle;

  /// No description provided for @settingsTemperatureFahrenheit.
  ///
  /// In en, this message translates to:
  /// **'Show temperatures in °F'**
  String get settingsTemperatureFahrenheit;

  /// No description provided for @settingsTemperatureFahrenheitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Temperatures are kept in °C and shown in whichever you choose, so switching changes nothing recorded.'**
  String get settingsTemperatureFahrenheitSubtitle;

  /// No description provided for @settingsCyclePhases.
  ///
  /// In en, this message translates to:
  /// **'Name the cycle phase'**
  String get settingsCyclePhases;

  /// No description provided for @settingsCyclePhasesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show Period, Follicular or Luteal on the calendar, alongside the day of your cycle.'**
  String get settingsCyclePhasesSubtitle;

  /// No description provided for @settingsOvulationWindow.
  ///
  /// In en, this message translates to:
  /// **'Estimated ovulation'**
  String get settingsOvulationWindow;

  /// No description provided for @settingsOvulationWindowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show an estimated ovulation range. Worked out from your cycle dates alone, and not accurate enough to plan or avoid pregnancy with.'**
  String get settingsOvulationWindowSubtitle;

  /// No description provided for @settingsLearnTab.
  ///
  /// In en, this message translates to:
  /// **'Show the Learn tab'**
  String get settingsLearnTab;

  /// No description provided for @settingsLearnTabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off by default. The reference pages, and conditions and medication, appear only when this is on.'**
  String get settingsLearnTabSubtitle;

  /// No description provided for @settingsPrivacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacySection;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'What this app does with your data'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsLogViewer.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get settingsLogViewer;

  /// No description provided for @settingsLogViewerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything this app records about itself.'**
  String get settingsLogViewerSubtitle;

  /// No description provided for @settingsLogViewerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet.'**
  String get settingsLogViewerEmpty;

  /// No description provided for @settingsLogViewerClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the log'**
  String get settingsLogViewerClear;

  /// No description provided for @settingsLogViewerCleared.
  ///
  /// In en, this message translates to:
  /// **'Log cleared.'**
  String get settingsLogViewerCleared;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsModelVersion.
  ///
  /// In en, this message translates to:
  /// **'Prediction model {version}'**
  String settingsModelVersion(String version);

  /// No description provided for @privacyHeading.
  ///
  /// In en, this message translates to:
  /// **'What this app does with your data'**
  String get privacyHeading;

  /// No description provided for @privacyOnDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'We do not collect your information'**
  String get privacyOnDeviceTitle;

  /// No description provided for @privacyOnDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'The app has no internet permission, no account, no analytics, no advertising and no crash reporting, and a check on every release refuses to build one that asks for the internet. Everything you record stays on your phone, under your control, and none of it reaches us.'**
  String get privacyOnDeviceBody;

  /// No description provided for @privacySharingTitle.
  ///
  /// In en, this message translates to:
  /// **'It leaves your phone only when you choose'**
  String get privacySharingTitle;

  /// No description provided for @privacySharingBody.
  ///
  /// In en, this message translates to:
  /// **'Two things send anything anywhere, and only when you ask. An export saves a backup, or a summary for a doctor, wherever you choose. A web search opens in your browser, after the app tells you exactly which words will be searched, and your browser may keep it in its history.'**
  String get privacySharingBody;

  /// No description provided for @privacyEncryptedTitle.
  ///
  /// In en, this message translates to:
  /// **'The database is encrypted, with a key the phone keeps'**
  String get privacyEncryptedTitle;

  /// No description provided for @privacyEncryptedBody.
  ///
  /// In en, this message translates to:
  /// **'Everything you record is kept in the app\'s private storage, in a database file encrypted with a key held by Android\'s secure key store. The key never leaves the phone and is not in your exports, so a copy of the file on its own cannot be read. Scheduled reminders are the one exception: until they are due, Android keeps their wording, which can name the predicted dates, outside the encrypted file. Encryption does not protect an unlocked phone. Anyone using it can open the app and read what you recorded unless the app lock is on, and someone with full control of the phone, through root access or a forensic tool, may be able to use the key the way the app does.'**
  String get privacyEncryptedBody;

  /// No description provided for @privacyBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing is copied off the phone'**
  String get privacyBackupTitle;

  /// No description provided for @privacyBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Android\'s cloud backup and device-to-device transfer are switched off for the app, so your records are never copied to a Google account or to a new phone. If you lose the phone, they are gone unless you exported them.'**
  String get privacyBackupBody;

  /// No description provided for @privacyDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleting really deletes'**
  String get privacyDeletionTitle;

  /// No description provided for @privacyDeletionBody.
  ///
  /// In en, this message translates to:
  /// **'You can delete a single day, condition or medicine at any time. Delete everything removes every record and reclaims the space, so the deleted entries are not left readable in the file. Uninstalling the app deletes everything it stored on the phone.'**
  String get privacyDeletionBody;

  /// No description provided for @privacyLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'The activity log holds nothing you recorded'**
  String get privacyLogsTitle;

  /// No description provided for @privacyLogsBody.
  ///
  /// In en, this message translates to:
  /// **'The app keeps a short log of what it did, such as \"a prediction was computed\" with a count of cycles. It stays on the phone, only in memory, so it is cleared when the app stops. You can read it and clear it in Settings.'**
  String get privacyLogsBody;

  /// No description provided for @privacyExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Exports are yours to look after'**
  String get privacyExportTitle;

  /// No description provided for @privacyExportBody.
  ///
  /// In en, this message translates to:
  /// **'An exported backup is a readable file wherever you save it, unless you protect it with a passphrase when you export it. A protected backup opens only with that passphrase, and nobody can recover a forgotten one. Once a backup is saved, it is under your control and the control of wherever you keep or send it.'**
  String get privacyExportBody;

  /// No description provided for @bootstrapRecoveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data could not be read'**
  String get bootstrapRecoveredTitle;

  /// No description provided for @bootstrapRecoveredBody.
  ///
  /// In en, this message translates to:
  /// **'The stored file was damaged, so this app started with an empty one. The damaged file is still on the device. If you have a backup, restoring it now is the best way forward.'**
  String get bootstrapRecoveredBody;

  /// No description provided for @bootstrapRecoveredAction.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get bootstrapRecoveredAction;

  /// No description provided for @bootstrapNewerSchemaTitle.
  ///
  /// In en, this message translates to:
  /// **'This app needs updating'**
  String get bootstrapNewerSchemaTitle;

  /// No description provided for @bootstrapNewerSchemaBody.
  ///
  /// In en, this message translates to:
  /// **'The data on this device was written by a newer version of this app (storage version {stored}; this version understands {supported}). Nothing has been changed. Install the newer version to carry on.'**
  String bootstrapNewerSchemaBody(int stored, int supported);

  /// No description provided for @bootstrapKeyUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Selene could not unlock your data'**
  String get bootstrapKeyUnavailableTitle;

  /// No description provided for @bootstrapKeyUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted on this phone, and the key that unlocks it could not be read just now. Nothing has been opened or changed. Close Selene and open it again; if this keeps happening, restart the phone.'**
  String get bootstrapKeyUnavailableBody;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorGeneric;

  /// No description provided for @errorWriteRefusedFuture.
  ///
  /// In en, this message translates to:
  /// **'That day has not happened yet.'**
  String get errorWriteRefusedFuture;

  /// No description provided for @errorWriteRefusedExists.
  ///
  /// In en, this message translates to:
  /// **'That day is already logged. Press and hold it in the calendar to change it.'**
  String get errorWriteRefusedExists;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
