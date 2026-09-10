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
  /// **'This app records your cycle on this device and predicts when your next period is likely to start. It has no internet permission, so nothing can be sent anywhere.'**
  String get onboardingIntro;

  /// No description provided for @onboardingWhatItIsNotTitle.
  ///
  /// In en, this message translates to:
  /// **'What this app is not'**
  String get onboardingWhatItIsNotTitle;

  /// No description provided for @onboardingNotContraception.
  ///
  /// In en, this message translates to:
  /// **'It is not contraception. It cannot tell you when sex is unlikely to lead to pregnancy, and it must never be used to try.'**
  String get onboardingNotContraception;

  /// No description provided for @onboardingNotMedical.
  ///
  /// In en, this message translates to:
  /// **'It is not medical advice. If something about your cycle worries you, talk to a clinician.'**
  String get onboardingNotMedical;

  /// No description provided for @onboardingNotDiagnostic.
  ///
  /// In en, this message translates to:
  /// **'It cannot diagnose anything. It sees only the dates you record, and nothing about contraception you take, pregnancy, medication, illness or stress.'**
  String get onboardingNotDiagnostic;

  /// No description provided for @onboardingAlwaysARange.
  ///
  /// In en, this message translates to:
  /// **'Predictions are always a range of days, never a single date. Cycles vary, and one date would claim a precision this app does not have.'**
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
  /// **'One date is enough to begin. Predictions start out wide and narrow as you log more cycles.'**
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
  /// **'until your period is likely'**
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

  /// No description provided for @logIntercourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Intercourse'**
  String get logIntercourseTitle;

  /// Under the intercourse control. Says both things a user needs before touching it: that it is optional, and that recording it does not feed the model — which they would otherwise reasonably assume it does.
  ///
  /// In en, this message translates to:
  /// **'Optional, and never used for predictions. Tap again to clear.'**
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
  /// **'One thing worth knowing before you start'**
  String get onboardingSensitiveTitle;

  /// Shown during onboarding, before the user has recorded anything. It names the most sensitive field the app holds rather than letting them find it themselves, and points at the app lock in the same breath.
  ///
  /// In en, this message translates to:
  /// **'You can record intercourse, and whether it was protected. It is the most sensitive thing stored here: it never leaves your device, is never used to predict anything, and is never required. The app lock in settings can ask for your fingerprint or PIN before anything shows.'**
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
  /// **'Welcome back. Log a day whenever you are ready and the predictions will pick up again.'**
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
  /// **'No predicted window is shown, because there is not enough to go on yet.'**
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
  /// **'About four times in five it starts in this range.'**
  String get insightsFourInFive;

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
  /// **'Based on typical cycles rather than yours. Your own figures take over after {count} cycles.'**
  String insightsNotPersonalisedYet(int count);

  /// No description provided for @insightsNoDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get insightsNoDataTitle;

  /// No description provided for @insightsNoDataBody.
  ///
  /// In en, this message translates to:
  /// **'Log the day your last period started and this screen fills in. Typical cycles run about 29 days, but yours are what matter here.'**
  String get insightsNoDataBody;

  /// No description provided for @insightsTooIrregularTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cycles vary too much for a useful range'**
  String get insightsTooIrregularTitle;

  /// No description provided for @insightsTooIrregularBody.
  ///
  /// In en, this message translates to:
  /// **'That is information, not a failure, and worth showing a clinician. Your figures are below; logging more keeps them sharp.'**
  String get insightsTooIrregularBody;

  /// No description provided for @insightsLostTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'It has been a while'**
  String get insightsLostTrackTitle;

  /// No description provided for @insightsLostTrackBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged for {days} days, so this app has lost the thread rather than guess. Log a day and it picks up again.'**
  String insightsLostTrackBody(int days);

  /// No description provided for @insightsInconsistentTitle.
  ///
  /// In en, this message translates to:
  /// **'Something does not add up'**
  String get insightsInconsistentTitle;

  /// No description provided for @insightsInconsistentBody.
  ///
  /// In en, this message translates to:
  /// **'The stored dates contradict each other, so no prediction is shown. Check the calendar for a day that looks wrong.'**
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
  /// **'Worked out on this device by re-running the prediction against cycles you had already logged. Nothing is sent anywhere.'**
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
  /// **'When a period is expected, and when one looks late.'**
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
  /// **'Nothing has been logged since the window closed. Cycles vary for many reasons, and a prediction being wrong is one of them.'**
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
  /// **'Off by default. At most one every seven days, and never after the app has lost track.'**
  String get settingsNudgeSubtitle;

  /// No description provided for @settingsDetailedNotifications.
  ///
  /// In en, this message translates to:
  /// **'Show details on the lock screen'**
  String get settingsDetailedNotifications;

  /// No description provided for @settingsDetailedNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off by default. With this off, notifications say only the app name until the phone is unlocked.'**
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
  /// **'Writes a file you choose the location of. This is the only backup there is.'**
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
  /// **'A notification in the morning, the chosen number of days ahead.'**
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
  /// **'The days you have logged bleeding for. This one is read from what you recorded, not estimated.'**
  String get calendarPhasePeriodExplained;

  /// No description provided for @calendarPhaseFollicularExplained.
  ///
  /// In en, this message translates to:
  /// **'The stretch after your period ends. Most of the variation between cycles sits here, which makes it the part this app is least certain about.'**
  String get calendarPhaseFollicularExplained;

  /// No description provided for @calendarPhaseLutealExplained.
  ///
  /// In en, this message translates to:
  /// **'The run of days before your next period is due. It tends to be the steadiest part of the cycle.'**
  String get calendarPhaseLutealExplained;

  /// No description provided for @calendarPhaseUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not enough logged to say where you are.'**
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

  /// Sits under the app-lock toggle, always visible, on or off. A lock a user mistakes for encryption is worse than no lock, so this is not behind a link.
  ///
  /// In en, this message translates to:
  /// **'This hides the screen. It does not encrypt anything.'**
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

  /// No description provided for @lookupHygieneHeading.
  ///
  /// In en, this message translates to:
  /// **'Tampons, cups and pads'**
  String get lookupHygieneHeading;

  /// No description provided for @lookupCuratedNote.
  ///
  /// In en, this message translates to:
  /// **'Written for this app and checked against the sources listed in HYGIENE_SOURCES.md. Not a regulator\'s own wording, unlike the medicines below.'**
  String get lookupCuratedNote;

  /// No description provided for @lookupMedicinesSource.
  ///
  /// In en, this message translates to:
  /// **'From US drug labelling published by openFDA, as it stood on {date}.'**
  String lookupMedicinesSource(String date);

  /// Always shown with the medicines section. A reader applying US warnings to a box bought elsewhere is being quietly misinformed, and nothing else on the screen would tell them.
  ///
  /// In en, this message translates to:
  /// **'This is United States labelling. Strengths, brand names and warnings can differ where you are, so check the packet you actually have.'**
  String get lookupMedicinesUsOnly;

  /// Shown when the openFDA artifact has not been fetched. Says so plainly rather than rendering an empty list, which reads as a broken screen.
  ///
  /// In en, this message translates to:
  /// **'The medicines reference is not built into this version. The other sections still work.'**
  String get lookupMedicinesUnavailable;

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
  /// **'Your browser will make the request, not this app. The search leaves your device, and your browser normally keeps it in its history and may sync it to other devices you are signed in on.'**
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

  /// No description provided for @settingsLookup.
  ///
  /// In en, this message translates to:
  /// **'Look something up'**
  String get settingsLookup;

  /// No description provided for @settingsLookupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Medicines and hygiene product notes, stored on this device.'**
  String get settingsLookupSubtitle;

  /// No description provided for @hygieneTssTitle.
  ///
  /// In en, this message translates to:
  /// **'Toxic shock syndrome'**
  String get hygieneTssTitle;

  /// PINNED — hygiene_copy_test.dart asserts this exactly. It describes symptoms and says what to do. It must never name a diagnosis, and must never be softened into a suggestion.
  ///
  /// In en, this message translates to:
  /// **'If you have a sudden high fever, a sunburn-like rash, vomiting, diarrhoea, muscle aches, dizziness or confusion while using a tampon or a menstrual cup: remove it and get urgent medical help.'**
  String get hygieneTssUrgent;

  /// No description provided for @hygieneTssBody.
  ///
  /// In en, this message translates to:
  /// **'Toxic shock syndrome is rare and life-threatening. It is caused by bacterial toxins, and it is associated with tampon and menstrual cup use, though it also happens to people who are not menstruating at all.'**
  String get hygieneTssBody;

  /// No description provided for @hygieneTamponsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tampons'**
  String get hygieneTamponsTitle;

  /// No description provided for @hygieneTamponsBody.
  ///
  /// In en, this message translates to:
  /// **'Regulated as medical devices rather than as drugs. Absorbency ratings are standardised, so the same rating means the same thing across brands. General guidance is to use the lowest absorbency that suits the flow, and to change it as often as the packet says rather than leaving it longer.'**
  String get hygieneTamponsBody;

  /// No description provided for @hygieneCupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Menstrual cups'**
  String get hygieneCupsTitle;

  /// No description provided for @hygieneCupsBody.
  ///
  /// In en, this message translates to:
  /// **'Reusable devices worn internally to collect fluid rather than absorb it. Cases of toxic shock syndrome linked to cup use have been reported. How long a cup can be worn, and how it should be cleaned between uses, genuinely differ between products, so follow the instructions that came with yours rather than a number from an app.'**
  String get hygieneCupsBody;

  /// No description provided for @hygieneExternalTitle.
  ///
  /// In en, this message translates to:
  /// **'Pads and period underwear'**
  String get hygieneExternalTitle;

  /// No description provided for @hygieneExternalBody.
  ///
  /// In en, this message translates to:
  /// **'Worn outside the body, and not associated with toxic shock syndrome in the way internally worn products are.'**
  String get hygieneExternalBody;

  /// No description provided for @nutritionTitle.
  ///
  /// In en, this message translates to:
  /// **'Iron and magnesium'**
  String get nutritionTitle;

  /// The framing sentence for the whole screen. It has to establish that the page is reference text and not addressed to the reader personally, before any nutrient is named.
  ///
  /// In en, this message translates to:
  /// **'Reference notes on two nutrients that come up around menstrual cycles. This is background reading, not advice about your body, and nothing here is based on what you have logged.'**
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
  /// **'Iron deficiency is confirmed by a blood test. Symptoms alone cannot establish it, and neither can anything in this app.'**
  String get nutritionIronDiagnosisNote;

  /// No description provided for @nutritionIronSourcesBody.
  ///
  /// In en, this message translates to:
  /// **'Dietary iron comes in two forms: haem iron from meat and fish, and non-haem iron from plants and fortified foods. They are absorbed differently.'**
  String get nutritionIronSourcesBody;

  /// No description provided for @nutritionVitaminCTitle.
  ///
  /// In en, this message translates to:
  /// **'Why vitamin C is listed here'**
  String get nutritionVitaminCTitle;

  /// No description provided for @nutritionVitaminCBody.
  ///
  /// In en, this message translates to:
  /// **'Vitamin C eaten in the same meal increases how much non-haem iron the body absorbs. That is the only reason it appears in a menstrual cycle app.'**
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
  /// **'Evidence that magnesium supplements improve menstrual symptoms is limited and not conclusive.'**
  String get nutritionMagnesiumEvidenceBody;

  /// No description provided for @nutritionZincTitle.
  ///
  /// In en, this message translates to:
  /// **'Why zinc is listed here'**
  String get nutritionZincTitle;

  /// No description provided for @nutritionZincBody.
  ///
  /// In en, this message translates to:
  /// **'Zinc is an essential mineral involved in immune function and wound healing. It is often sold together with magnesium, which is worth knowing alongside the next line: taken at high doses over time, zinc can interfere with how the body absorbs copper.'**
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

  /// No description provided for @nutritionSourcesNote.
  ///
  /// In en, this message translates to:
  /// **'Every claim on this page is listed with its source in NUTRITION_SOURCES.md in the app\'s source repository.'**
  String get nutritionSourcesNote;

  /// No description provided for @settingsNutrition.
  ///
  /// In en, this message translates to:
  /// **'Iron and magnesium'**
  String get settingsNutrition;

  /// No description provided for @settingsNutritionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reference notes on two nutrients that come up around menstrual cycles.'**
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

  /// Sits directly under the intro. The section carries a real risk of harm around disordered eating, and the first thing it says is that the app wants nothing from the reader.
  ///
  /// In en, this message translates to:
  /// **'This app records no body weight and asks for none. There is nothing to enter here, and no figure on this page to measure a body against.'**
  String get weightNothingToEnterBody;

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
  /// **'The quantity of adipose tissue is therefore one of the inputs to how much oestrogen is circulating, and it runs in both directions: more of it adds to the total, and very little of it removes a source the ovaries do not make up for. It is one input among several rather than the whole picture.'**
  String get weightOestrogenBalanceBody;

  /// No description provided for @weightEnergyTitle.
  ///
  /// In en, this message translates to:
  /// **'Energy availability and the hypothalamus'**
  String get weightEnergyTitle;

  /// No description provided for @weightEnergyBody.
  ///
  /// In en, this message translates to:
  /// **'The hypothalamus releases GnRH in pulses, and that rhythm is what drives LH and FSH from the pituitary, which in turn drive the ovary. When energy availability is low the pulses are suppressed: LH and FSH fall, ovulation stops, and periods stop with it. That state has a name: functional hypothalamic amenorrhoea.'**
  String get weightEnergyBody;

  /// Load-bearing. Without it the section reads as a statement about a number on a scale, which is both wrong and the most harmful thing this reference could be mistaken for.
  ///
  /// In en, this message translates to:
  /// **'Energy availability is what is left of the energy taken in once exercise has had its share, measured against what the body needs to run on. It is not a body weight and it is not a reading from a scale. Functional hypothalamic amenorrhoea occurs in people whose body weight is entirely unremarkable, and heavy training, illness or sustained stress can produce it with no fall in body weight at all.'**
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
  /// **'PCOS'**
  String get weightPcosTitle;

  /// No description provided for @weightPcosBody.
  ///
  /// In en, this message translates to:
  /// **'Polycystic ovary syndrome is androgen excess together with irregular or absent ovulation. Insulin resistance is common alongside it, and the mechanism above is part of how the androgen excess is sustained.'**
  String get weightPcosBody;

  /// Must not be dropped. The opposite impression is both common and false, and naming PCOS in a section about body composition without saying this would reinforce the error.
  ///
  /// In en, this message translates to:
  /// **'PCOS occurs across the whole weight spectrum, in people who are thin as well as in people who are not. The widespread impression that it belongs at one end of that spectrum is not accurate, and it is one of the reasons the condition goes unrecognised.'**
  String get weightPcosSpectrumBody;

  /// No description provided for @weightThyroidTitle.
  ///
  /// In en, this message translates to:
  /// **'Thyroid function'**
  String get weightThyroidTitle;

  /// No description provided for @weightThyroidBody.
  ///
  /// In en, this message translates to:
  /// **'Thyroid disease reaches the menstrual cycle too, and in both directions. An underactive thyroid is associated with heavier and more frequent bleeding; an overactive one with lighter, less frequent bleeding, or with none. Thyroid function is established by a blood test rather than by the shape of a cycle.'**
  String get weightThyroidBody;

  /// No description provided for @weightChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'When a cycle changes'**
  String get weightChangeTitle;

  /// The last thing on the screen. A page of mechanisms with no exit is an invitation to pick one, so this points at a person. Deliberately carries no threshold: a threshold is a number, and a number here is something to measure a body against.
  ///
  /// In en, this message translates to:
  /// **'A change in cycle length, in the amount of bleeding, or in whether periods arrive at all has many possible causes, and the mechanisms on this page are only some of them. Cycle dates cannot separate one cause from another, and nothing in this app can diagnose anything. A change worth explaining is worth taking to a doctor or nurse.'**
  String get weightChangeBody;

  /// No description provided for @weightSourcesNote.
  ///
  /// In en, this message translates to:
  /// **'Every claim on this page is listed with its source in WEIGHT_SOURCES.md in the app\'s source repository.'**
  String get weightSourcesNote;

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
  /// **'Reference notes on period pain, on what movement does and does not do about it, and on how much of the popular advice on the subject the evidence actually supports. This is background reading, not advice, and it describes what is known rather than any particular body. Nothing on this page is drawn from anything logged in this app.'**
  String get movementIntro;

  /// Sits directly under the intro. The reader most likely to be harmed by this subject is the one who arrives expecting to be told what to do, and the first thing the section says is that it is not going to.
  ///
  /// In en, this message translates to:
  /// **'This app records no exercise and asks for none. There is nothing to enter here and no plan on this page to follow, so there is nothing on it to keep up with or to fall behind.'**
  String get movementNothingToFollowBody;

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
  /// **'Menstruation is not named anywhere in the sources behind this page as a reason to stop, and general physical activity guidance makes no exception for the days of a period. Clinical guidance on period pain goes further than that and lists exercise among the measures that may help with it.'**
  String get movementNotAvoidedBody;

  /// Must not be strengthened. "Low quality evidence that exercise may reduce pain" is weaker than "exercise helps period pain" and it is the true one.
  ///
  /// In en, this message translates to:
  /// **'A Cochrane review of exercise for period pain found that exercise may reduce how intense the pain is, on evidence the reviewers themselves rated as low quality. That is a modest finding and it is stated here at its real strength rather than at a more useful one. What it supports is only this: the direction of the evidence runs towards movement helping with cramps rather than making them worse.'**
  String get movementEvidenceBody;

  /// No description provided for @movementHowItFeelsTitle.
  ///
  /// In en, this message translates to:
  /// **'What changes is how it feels'**
  String get movementHowItFeelsTitle;

  /// No description provided for @movementHowItFeelsBody.
  ///
  /// In en, this message translates to:
  /// **'What varies across a cycle is the experience of moving, not what is permitted. Cramping pain around the start of bleeding, tiredness and low energy in the days before and during it, and how hard a given effort seems on the day are all part of that. The variation is wide between people and between one cycle and the next in the same person, which is why none of it turns into a rule.'**
  String get movementHowItFeelsBody;

  /// No description provided for @movementRestTitle.
  ///
  /// In en, this message translates to:
  /// **'Doing less is allowed'**
  String get movementRestTitle;

  /// Permission, never instruction. The requested version of this section was an instruction to rest, which is the same category error as an exercise prescription and is stated here as one.
  ///
  /// In en, this message translates to:
  /// **'Doing less, or nothing at all, on a day when that is what is wanted is a reasonable choice and not a lapse. That is a permission rather than an instruction, and the difference is the whole point: an instruction to rest is the same mistake as an instruction to push, only kinder. Nothing on this page asks for more and nothing on it asks for less.'**
  String get movementRestBody;

  /// No description provided for @movementStopSignalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Signals to stop'**
  String get movementStopSignalsTitle;

  /// No description provided for @movementStopSignalsBody.
  ///
  /// In en, this message translates to:
  /// **'Some things are reasons to stop rather than to carry on. Feeling faint or light-headed during exertion, breathlessness out of proportion to the effort, and chest pain are among them, and each of those is a reason to get it looked at rather than to push on. None of this is particular to menstruation; it holds whenever it happens.'**
  String get movementStopSignalsBody;

  /// The same claim the iron section makes, cited to the same sources in MOVEMENT_SOURCES.md and NUTRITION_SOURCES.md so the two cannot drift. It is here because it explains a hard day without blaming the cycle for it.
  ///
  /// In en, this message translates to:
  /// **'There is also a recognised reason why exertion can feel harder around heavy periods, and it is not that a cycle makes movement unwise. Heavy menstrual bleeding is a recognised cause of iron deficiency anaemia, whose commonly listed symptoms include tiredness, lack of energy and shortness of breath. Iron deficiency is confirmed by a blood test rather than by how a day felt, and it is worth taking to a doctor or nurse rather than working around.'**
  String get movementAnaemiaBody;

  /// No description provided for @movementPhaseClaimsTitle.
  ///
  /// In en, this message translates to:
  /// **'Planning exercise around cycle phase'**
  String get movementPhaseClaimsTitle;

  /// Says outright that the evidence is weak rather than quietly declining to use it. A reference that handed someone a prescription built on evidence this thin would be worse than one that says how thin it is.
  ///
  /// In en, this message translates to:
  /// **'Schemes that assign different kinds of exercise to different parts of the cycle are widely promoted. The evidence underneath them is weak. Systematic review of cycle phase and exercise performance describes that research as low quality and inconsistent, with average effects that are trivial and with differences between individuals larger than the effect being looked for. No clinical guidance in the sources behind this page recommends planning exercise around cycle phase, and none says the chance of injury rises or falls with it.'**
  String get movementPhaseClaimsBody;

  /// No description provided for @movementContraceptionBody.
  ///
  /// In en, this message translates to:
  /// **'Hormonal contraception is a further reason those schemes do not carry across. Combined hormonal contraception works by suppressing ovulation, so the rise and fall of oestrogen and progesterone that a phase-based scheme assumes is not what is going on underneath. A scheme built on phases, applied where those phases are not occurring, has nothing left to stand on.'**
  String get movementContraceptionBody;

  /// No description provided for @movementSeeSomeoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Pain worth taking to someone'**
  String get movementSeeSomeoneTitle;

  /// The last thing on the screen, pointing at a person. Deliberately carries no threshold and no pain scale: both are numbers, and a number here is something to be talked out of by.
  ///
  /// In en, this message translates to:
  /// **'Period pain that is severe, that is getting worse, that the usual measures do not ease, or that gets in the way of ordinary days is a reason to see a doctor or nurse. So is pain that began later in life, changed in character, or arrives alongside other symptoms. The causes named above are found by assessment rather than by tracking dates. No threshold is set out here and no scale.'**
  String get movementSeeSomeoneBody;

  /// No description provided for @movementSourcesNote.
  ///
  /// In en, this message translates to:
  /// **'Every claim on this page is listed with its source in MOVEMENT_SOURCES.md in the app\'s source repository.'**
  String get movementSourcesNote;

  /// No description provided for @movementEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Pain and movement across the cycle'**
  String get movementEntryTitle;

  /// No description provided for @movementEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What exercise does about period pain, how little supports planning it by cycle phase, and what is a reason to stop.'**
  String get movementEntrySubtitle;

  /// The name of the small persistent control in the bottom bar. It is a control, so it needs a name a screen reader can announce; 'decoration' is not an option.
  ///
  /// In en, this message translates to:
  /// **'Companion'**
  String get companionLabel;

  /// Closes the suggestion. The suggestion has to be dismissible from inside it, not only by the sheet's own gesture.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get companionDismiss;

  /// Points at the sources file. Some lines make no health claim at all, and the file says which ones and why.
  ///
  /// In en, this message translates to:
  /// **'Any health claim above is listed with its source in COMPANION_SOURCES.md in the app\'s source repository.'**
  String get companionSourcesNote;

  /// Shown while the logs, prediction or conditions are still loading. Says so rather than picking a line from a state it has not seen yet.
  ///
  /// In en, this message translates to:
  /// **'The log is still being read.'**
  String get companionLineStillReading;

  /// Restates a state the user entered themselves and a behaviour the app already has. It never infers a pregnancy; it reads a recorded condition.
  ///
  /// In en, this message translates to:
  /// **'A pregnancy is recorded, so predictions are paused. Days can still be logged.'**
  String get companionLinePredictionPaused;

  /// Carries a health claim (COMPANION_SOURCES.md I1, I2). A statement about physiology, followed by the sentence that stops it being read as a conclusion about the reader.
  ///
  /// In en, this message translates to:
  /// **'Heavy bleeding is recorded on several days. Heavy menstrual bleeding is a recognised cause of iron deficiency anaemia, which a blood test settles rather than symptoms.'**
  String get companionLineHeavyBleeding;

  /// Carries a health claim (COMPANION_SOURCES.md P1). Reports what guidance lists rather than telling anyone to do any of it.
  ///
  /// In en, this message translates to:
  /// **'Cramps are recorded for today. Guidance on period pain lists heat, painkillers and exercise among the measures that may help.'**
  String get companionLineCramps;

  /// Carries a health claim (COMPANION_SOURCES.md S1). Says the symptom is commonly reported, which is not the same as saying it is caused by the cycle.
  ///
  /// In en, this message translates to:
  /// **'Disturbed sleep is recorded for today. Sleep problems are among the symptoms commonly reported around a period.'**
  String get companionLineSleep;

  /// Carries a health claim (COMPANION_SOURCES.md S2). Same shape as the sleep line and the same limit on it.
  ///
  /// In en, this message translates to:
  /// **'Low energy is recorded for today. Tiredness is among the symptoms commonly reported before and during a period.'**
  String get companionLineLowEnergy;

  /// Carries a health claim (COMPANION_SOURCES.md M1), an absence claim borrowed from the movement reference. It tells nobody to move; it says no source tells anyone to stop.
  ///
  /// In en, this message translates to:
  /// **'A period is logged for today. Menstruation is not named anywhere in the guidance behind this app as a reason to stop moving.'**
  String get companionLinePeriodToday;

  /// The line PLAN 6.3 is most specific about. A missed period is a data state, not a life event to comment on, and the second sentence is what keeps it one.
  ///
  /// In en, this message translates to:
  /// **'The predicted window has passed with no period logged. That is a data state, and nothing here guesses at what is behind it.'**
  String get companionLineOverdue;

  /// An offer, never a nudge. No streak, no count, and no reason asked for: a gap may be pregnancy, loss, illness, or simply not wanting to think about it.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been logged for a few days. The log is on the first tab, whenever there is something to put in it.'**
  String get companionLineNothingLoggedRecently;

  /// The empty state, restating what onboarding already said rather than inventing a second version of it.
  ///
  /// In en, this message translates to:
  /// **'Nothing is recorded yet. One period start date is enough to begin.'**
  String get companionLineNoLogsYet;

  /// Says what is missing and where the user's own figures are, because withholding a prediction must not read as withholding their history.
  ///
  /// In en, this message translates to:
  /// **'There is not enough history for a prediction yet. Insights holds what has been recorded so far.'**
  String get companionLineNoPredictionYet;

  /// Deliberately no praise. Logging is not an achievement and this app does not congratulate anyone for it.
  ///
  /// In en, this message translates to:
  /// **'Today is already logged. The day can be opened again and changed.'**
  String get companionLineTodayLogged;

  /// The fallback. It says nothing rather than manufacturing something, which is the whole reason the set is finite.
  ///
  /// In en, this message translates to:
  /// **'Nothing to point at just now.'**
  String get companionLineNothingToPointAt;

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
  /// **'PCOS'**
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
  /// **'Record long-term things that can change your cycle.'**
  String get settingsConditionsSubtitle;

  /// No description provided for @learnTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learnTitle;

  /// No description provided for @learnIntro.
  ///
  /// In en, this message translates to:
  /// **'Reference notes, written for this app and kept on the device. Every one of them says where its claims come from, and none of them is advice about you.'**
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
  /// **'Every scheme here was measured for contrast before it was offered. Pick whichever you can stand to look at.'**
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
  /// **'Night is dark by design, so there is nothing to switch. Pick another scheme to choose.'**
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
  /// **'Designed dark, not inverted'**
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
  /// **'Everything stays on this phone'**
  String get privacyOnDeviceTitle;

  /// No description provided for @privacyOnDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'This app has no internet permission, and a check on every release refuses to build one that asks for it. No account, no sync, no analytics, no crash reporting. Nothing leaves this device unless you export it.'**
  String get privacyOnDeviceBody;

  /// No description provided for @privacyNotEncryptedTitle.
  ///
  /// In en, this message translates to:
  /// **'The database is not encrypted'**
  String get privacyNotEncryptedTitle;

  /// No description provided for @privacyNotEncryptedBody.
  ///
  /// In en, this message translates to:
  /// **'Your data sits in this app\'s own storage, which other apps cannot read on a phone that has not been tampered with, and which Android\'s full-device encryption protects while the phone is switched off. But it is stored as plain text. Anyone who picks up your unlocked phone, or who takes a forensic copy of it, can read it. The app lock does not encrypt anything: it covers the screen, not the file.'**
  String get privacyNotEncryptedBody;

  /// No description provided for @privacyBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'It is never backed up to the cloud'**
  String get privacyBackupTitle;

  /// No description provided for @privacyBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Android\'s automatic backup is switched off for this app, so your cycle history is never copied to a Google account. If you lose the phone, the data is gone unless you exported it.'**
  String get privacyBackupBody;

  /// No description provided for @privacyDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleting really deletes'**
  String get privacyDeletionTitle;

  /// No description provided for @privacyDeletionBody.
  ///
  /// In en, this message translates to:
  /// **'Deleting a day removes the row. Deleting everything removes every row and then reclaims the space, so the old entries are not left readable in the file. Nothing is kept behind a hidden flag.'**
  String get privacyDeletionBody;

  /// No description provided for @privacyLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'The activity log holds no cycle content'**
  String get privacyLogsTitle;

  /// No description provided for @privacyLogsBody.
  ///
  /// In en, this message translates to:
  /// **'This app keeps a short log of what it did, such as \"a prediction was computed\" with a count of cycles. You can read it and clear it in Settings.'**
  String get privacyLogsBody;

  /// No description provided for @privacyExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Exports are yours to look after'**
  String get privacyExportTitle;

  /// No description provided for @privacyExportBody.
  ///
  /// In en, this message translates to:
  /// **'An exported backup is a plain readable file wherever you chose to put it, with no protection of its own. Anywhere you save it or send it is outside this app\'s control.'**
  String get privacyExportBody;

  /// No description provided for @bootstrapRecoveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data could not be read'**
  String get bootstrapRecoveredTitle;

  /// No description provided for @bootstrapRecoveredBody.
  ///
  /// In en, this message translates to:
  /// **'The stored file was damaged, so this app started with an empty one. The damaged file has been kept, not deleted. If you have a backup, restoring it now is the best way forward.'**
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
