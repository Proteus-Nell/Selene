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
  /// **'Period Tracker'**
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
  /// **'Log'**
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
  /// **'This app records your cycle on this device and predicts when your next period is likely to start. Everything stays on the phone: it has no internet permission at all, so nothing can be sent anywhere.'**
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
  /// **'It cannot diagnose anything. It sees only the dates you record, so it knows nothing about contraception you take, pregnancy, medication, illness or stress.'**
  String get onboardingNotDiagnostic;

  /// No description provided for @onboardingAlwaysARange.
  ///
  /// In en, this message translates to:
  /// **'Predictions are always a range of days, never a single date. Cycles vary, and a single date would claim a precision this app does not have.'**
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

  /// No description provided for @logTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get logTitle;

  /// No description provided for @logTodayIs.
  ///
  /// In en, this message translates to:
  /// **'Today is {date}'**
  String logTodayIs(String date);

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
  /// **'You can optionally record intercourse, and whether it was protected. It is the most sensitive thing this app stores. It never leaves your device, it is never used to predict anything, and you never have to record it. If you want the app to ask for your fingerprint or PIN before showing anything, turn on the app lock in settings.'**
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
  /// **'Press and hold any day to change it.'**
  String get calendarLongPressHint;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Predictions are estimates from the dates you have logged. Not contraception, not medical advice.'**
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
  /// **'Based on typical cycles rather than yours. It will use your own figures once you have logged {count} cycles.'**
  String insightsNotPersonalisedYet(int count);

  /// No description provided for @insightsNoDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get insightsNoDataTitle;

  /// No description provided for @insightsNoDataBody.
  ///
  /// In en, this message translates to:
  /// **'Log the day your last period started and this screen will start filling in. Typical cycles run about 29 days, but yours are what matter here.'**
  String get insightsNoDataBody;

  /// No description provided for @insightsTooIrregularTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cycles vary too much for a useful range'**
  String get insightsTooIrregularTitle;

  /// No description provided for @insightsTooIrregularBody.
  ///
  /// In en, this message translates to:
  /// **'That is information, not a failure, and it is worth showing a clinician. Your own figures are below, and logging more will keep them sharp.'**
  String get insightsTooIrregularBody;

  /// No description provided for @insightsLostTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'It has been a while'**
  String get insightsLostTrackTitle;

  /// No description provided for @insightsLostTrackBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been logged for {days} days, so this app has lost the thread rather than guess. Log a day and it will pick up again.'**
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
  /// **'Once you have logged a few more cycles, this app will show you how accurate its own predictions have been.'**
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
  /// **'Period Tracker'**
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
  /// **'Some phones stop scheduled reminders to save battery. If reminders stop arriving, allow this app to run in the background in the system battery settings.'**
  String get settingsBatteryNoteBody;

  /// No description provided for @settingsNotificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on reminders?'**
  String get settingsNotificationPermissionTitle;

  /// No description provided for @settingsNotificationPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Now that you have logged a cycle, this app can remind you before the next one is expected. You can change this at any time.'**
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
  /// **'Removes every day, setting and stored figure from this device for good.'**
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
  /// **'Your cycles are below, and nothing has been deleted. Add an end date to the pregnancy on the conditions screen and predictions will start again.'**
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
  /// **'The stretch after your period ends. Its length is where most of the variation between cycles sits, so it is the part this app is least certain about.'**
  String get calendarPhaseFollicularExplained;

  /// No description provided for @calendarPhaseLutealExplained.
  ///
  /// In en, this message translates to:
  /// **'The run of days before your next period is due. It tends to be the steadiest part of the cycle, which is why it is counted back from the date expected rather than forward from the last one.'**
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
  /// **'This hides the screen. It does not encrypt your data, which is stored unencrypted in the app\'s private storage either way.'**
  String get settingsAppLockNotEncrypted;

  /// Replaces the toggle when no credential is enrolled. Names the fix, which is in the device settings and not in this app.
  ///
  /// In en, this message translates to:
  /// **'Your device has no PIN, pattern, password or fingerprint set up, so there is nothing for the app to ask for. Set a screen lock in your device settings, then come back.'**
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
  /// **'This update changed the backup format. Any backup file you saved before now can no longer be restored by the app, so it is worth exporting again. Your data in the app is untouched.'**
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
  /// **'This is United States labelling. Strengths, brand names and warnings can differ where you are — check the packet you actually have.'**
  String get lookupMedicinesUsOnly;

  /// Shown when the openFDA artifact has not been fetched. Says so plainly rather than rendering an empty list, which reads as a broken screen.
  ///
  /// In en, this message translates to:
  /// **'The medicines reference has not been built into this version of the app. The other sections still work.'**
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
  /// **'This app has no internet access at all, so it cannot look anything up for you. It can open your browser instead.'**
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
  /// **'Your browser will make the request, not this app. That means the search leaves your device, and your browser will normally keep it in its history and may sync it to other devices you are signed in on.'**
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
  /// **'Toxic shock syndrome is rare and life-threatening. It is caused by bacterial toxins, and it is associated with tampon and menstrual cup use — though it also happens to people who are not menstruating at all.'**
  String get hygieneTssBody;

  /// No description provided for @hygieneTamponsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tampons'**
  String get hygieneTamponsTitle;

  /// No description provided for @hygieneTamponsBody.
  ///
  /// In en, this message translates to:
  /// **'Regulated as medical devices rather than as drugs, which is why they are not in the medicines section. Absorbency ratings are standardised, so the same rating means the same thing across brands. General guidance is to use the lowest absorbency that suits the flow, and to change it as often as the packet says rather than leaving it longer.'**
  String get hygieneTamponsBody;

  /// No description provided for @hygieneCupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Menstrual cups'**
  String get hygieneCupsTitle;

  /// No description provided for @hygieneCupsBody.
  ///
  /// In en, this message translates to:
  /// **'Reusable devices worn internally to collect fluid rather than absorb it. Cases of toxic shock syndrome linked to cup use have been reported. How long a cup can be worn, and how it should be cleaned between uses, genuinely differ between products — follow the instructions that came with yours rather than a number from an app.'**
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

  /// No description provided for @conditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conditions and medication'**
  String get conditionsTitle;

  /// Under the screen title. States plainly that these do not reach the model, so nobody expects predictions to improve after entering them.
  ///
  /// In en, this message translates to:
  /// **'Things that can change your cycle. Recorded so you can read your own history with them in mind — they are not used to work out your predictions.'**
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
  /// **'Record bleeding as yes or no, instead of choosing an intensity. Anything already recorded is kept, and comes back if you turn this off.'**
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
  /// **'Everything this app records about its own behaviour. Read it: there are no dates or symptoms in here.'**
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

  /// No description provided for @settingsAboutBody.
  ///
  /// In en, this message translates to:
  /// **'Built as a personal project. No accounts, no analytics, no network permission.'**
  String get settingsAboutBody;

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
  /// **'This app has no internet permission. It is removed from the app\'s manifest, and an automated check on every release refuses to build an app that asks for it. There is no account, no sync, no analytics and no crash reporting. Nothing you record can leave this device unless you export it yourself.'**
  String get privacyOnDeviceBody;

  /// No description provided for @privacyNotEncryptedTitle.
  ///
  /// In en, this message translates to:
  /// **'The database is not encrypted'**
  String get privacyNotEncryptedTitle;

  /// No description provided for @privacyNotEncryptedBody.
  ///
  /// In en, this message translates to:
  /// **'This is the honest limit of what \"private\" means here. Your data sits in this app\'s own storage, which other apps cannot read on a phone that has not been tampered with, and which Android\'s full-device encryption protects while the phone is switched off. But it is stored as plain text. Anyone who picks up your unlocked phone, or who takes a forensic copy of it, can read it. There is no app lock in this version.'**
  String get privacyNotEncryptedBody;

  /// No description provided for @privacyBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'It is never backed up to the cloud'**
  String get privacyBackupTitle;

  /// No description provided for @privacyBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Android\'s automatic backup is switched off for this app, so your cycle history is never copied to a Google account. The consequence is that if you lose the phone, the data is gone unless you exported it.'**
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
  /// **'This app keeps a short log of what it did, such as \"a prediction was computed\" with a count of cycles. It is structurally incapable of recording a date, a flow level or a symptom. You can read it and clear it in Settings.'**
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
  /// **'The stored file was damaged, so this app started with an empty one. The damaged file has been kept next to it and has not been deleted. If you have a backup, restoring it now is the best way forward.'**
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
