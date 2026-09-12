// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Selene';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get navLog => 'Today';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navInsights => 'Insights';

  @override
  String get navLearn => 'Learn';

  @override
  String get navSettings => 'Settings';

  @override
  String get onboardingTitle => 'Before you start';

  @override
  String get onboardingIntro =>
      'This app records your cycle on this device and predicts when your next period is likely to start. It has no internet permission, so nothing can be sent anywhere.';

  @override
  String get onboardingWhatItIsNotTitle => 'What this app is not';

  @override
  String get onboardingNotContraception =>
      'This is a record of dates, not contraception. It cannot tell you when sex is unlikely to lead to pregnancy, and it must never be used to try.';

  @override
  String get onboardingNotMedical =>
      'This is a record, not medical advice. If something about your cycle worries you, talk to a clinician.';

  @override
  String get onboardingNotDiagnostic =>
      'It works from the dates you record and nothing else. It knows nothing about your contraception, pregnancy, medication, illness or stress, so it cannot diagnose anything.';

  @override
  String get onboardingAlwaysARange =>
      'Predictions come as a range of days. Cycles vary enough that a single date would claim a precision this app does not have.';

  @override
  String get onboardingAcknowledge => 'I understand';

  @override
  String get onboardingFirstEntryTitle => 'When did your last period start?';

  @override
  String get onboardingFirstEntryBody =>
      'One date is enough to begin. Predictions start wide and get narrower as you log more cycles.';

  @override
  String get onboardingFirstEntrySkip => 'Skip for now';

  @override
  String get onboardingFirstEntrySaved => 'Saved. You can change it any time.';

  @override
  String logWeekBleedingSuffix(String label) {
    return '$label, bleeding logged';
  }

  @override
  String get logGreetingMorning => 'Good morning';

  @override
  String get logGreetingAfternoon => 'Good afternoon';

  @override
  String get logGreetingEvening => 'Good evening';

  @override
  String logPhaseAndDay(String phase, int day) {
    return '$phase · day $day';
  }

  @override
  String logDayOfCycleShort(int day) {
    return 'Day $day';
  }

  @override
  String logCountdownRange(int from, int to) {
    return 'in $from–$to days';
  }

  @override
  String get logCountdownCaption => 'until your period is expected';

  @override
  String get logCountdownNow => 'any day now';

  @override
  String get logCountdownNowCaption => 'you are inside the expected range';

  @override
  String get logCountdownNothingYet => 'not yet';

  @override
  String get logCountdownNothingYetCaption =>
      'log a period start and this fills in';

  @override
  String logRingLabel(String summary) {
    return 'Your cycle as a ring. $summary';
  }

  @override
  String get logLegendOvulation => 'Ovulation';

  @override
  String logStartedOn(String date) {
    return 'Period started $date';
  }

  @override
  String get logPeriodStartedToday => 'Period started today';

  @override
  String logPeriodStartedOnDay(String day) {
    return 'Period started $day';
  }

  @override
  String get logWhenDidItStart => 'When did it start?';

  @override
  String get logDayToday => 'Today';

  @override
  String get logDayYesterday => 'Yesterday';

  @override
  String logDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get logStillBleeding => 'Still bleeding today';

  @override
  String get logNotBleeding => 'Not bleeding today';

  @override
  String get logFlowTitle => 'Flow';

  @override
  String get logFlowNone => 'None';

  @override
  String get logFlowSpotting => 'Spotting';

  @override
  String get logFlowLight => 'Light';

  @override
  String get logFlowMedium => 'Medium';

  @override
  String get logFlowHeavy => 'Heavy';

  @override
  String get logBleedingYes => 'Bleeding';

  @override
  String get logBleedingNo => 'None';

  @override
  String get logSymptomsTitle => 'Anything else today?';

  @override
  String get logIntercourseTitle => 'Intercourse';

  @override
  String get logIntercourseHint =>
      'Optional, and not used for predictions. Tap again to clear.';

  @override
  String get logIntercourseProtected => 'Protected';

  @override
  String get logIntercourseUnprotected => 'Unprotected';

  @override
  String get calendarLegendIntercourse => 'Intercourse logged';

  @override
  String calendarCellIntercourseSuffix(String label) {
    return '$label, intercourse logged';
  }

  @override
  String get onboardingSensitiveTitle => 'About recording intercourse';

  @override
  String get onboardingSensitiveBody =>
      'You can record intercourse, and whether it was protected. That is the most sensitive thing stored here. Recording it is optional, and what you record stays on this device and is never used to predict anything. The app lock in settings can ask for your fingerprint or PIN before anything shows.';

  @override
  String get logSectionPhysical => 'Physical';

  @override
  String get logSectionMental => 'Mental';

  @override
  String get logSectionEmotional => 'Emotional';

  @override
  String get logSymptomCramps => 'Cramps';

  @override
  String get logSymptomHeadache => 'Headache';

  @override
  String get logSymptomBloating => 'Bloating';

  @override
  String get logSymptomNausea => 'Nausea';

  @override
  String get logSymptomBreastTenderness => 'Sore breasts';

  @override
  String get logSymptomBackPain => 'Back pain';

  @override
  String get logSymptomAcne => 'Breakouts';

  @override
  String get logSymptomDigestiveUpset => 'Digestive upset';

  @override
  String get logSymptomSleep => 'Sleep';

  @override
  String get logSymptomBrainFog => 'Brain fog';

  @override
  String get logSymptomPoorConcentration => 'Poor concentration';

  @override
  String get logSymptomMood => 'Mood swings';

  @override
  String get logSymptomEnergy => 'Energy';

  @override
  String get logSymptomIrritability => 'Irritability';

  @override
  String get logSymptomAnxiety => 'Anxiety';

  @override
  String get logSymptomLowMood => 'Low mood';

  @override
  String get logSeverityMild => 'Mild';

  @override
  String get logSeverityModerate => 'Moderate';

  @override
  String get logSeveritySevere => 'Severe';

  @override
  String get logSeverityHint =>
      'Tap to record, press and hold to choose how strong it was.';

  @override
  String get logEntrySaved => 'Saved';

  @override
  String get logEntryRemoved => 'Removed';

  @override
  String get logNothingLoggedYet => 'Nothing logged for today yet.';

  @override
  String logDayInProgress(int day) {
    return 'Day $day of this cycle';
  }

  @override
  String get logWelcomeBack =>
      'Welcome back. Log a day and the predictions pick up again.';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarLegendPeriod => 'Period';

  @override
  String get calendarLegendPredicted => 'Predicted window';

  @override
  String get calendarLegendToday => 'Today';

  @override
  String calendarEditDay(String date) {
    return 'Edit $date';
  }

  @override
  String calendarCellPlain(String date) {
    return '$date';
  }

  @override
  String calendarCellPeriodDay(String date, int day) {
    return '$date, period day $day';
  }

  @override
  String calendarCellPredicted(String date) {
    return '$date, inside predicted window';
  }

  @override
  String calendarCellPeriodAndPredicted(String date, int day) {
    return '$date, period day $day, inside predicted window';
  }

  @override
  String calendarCellTodaySuffix(String label) {
    return '$label, today';
  }

  @override
  String calendarCellSymptomsSuffix(String label) {
    return '$label, symptoms recorded';
  }

  @override
  String get calendarNoPredictedWindow =>
      'No predicted window is shown yet. There are not enough logged cycles to work one out.';

  @override
  String get calendarLongPressHint => 'Hold any day to change it.';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsDisclaimer =>
      'Predictions are estimates based on the information logged. This does not serve as a contraceptive aid or medical advice.';

  @override
  String get insightsNextPeriodTitle => 'Next period';

  @override
  String insightsWindowRange(String start, String end) {
    return 'Between $start and $end';
  }

  @override
  String insightsMostLikely(String date) {
    return 'Most likely around $date';
  }

  @override
  String get insightsFourInFive =>
      'About four out of five times start in this range.';

  @override
  String insightsHalfTheTime(String start, String end) {
    return 'About half the time it starts between $start and $end.';
  }

  @override
  String get insightsConfidenceHigh => 'Narrow range';

  @override
  String get insightsConfidenceMedium => 'Moderate range';

  @override
  String get insightsConfidenceLow => 'Wide range';

  @override
  String insightsBasedOnCycles(int count) {
    return 'Based on your last $count cycles.';
  }

  @override
  String get insightsNotPersonalisedYet =>
      'Based on typical cycles which improve as you log your cycles.';

  @override
  String get insightsNoDataTitle => 'Nothing logged yet';

  @override
  String get insightsNoDataBody =>
      'Log the day your last period started and this screen fills in. Typical cycles run about 29 days, and your own figures replace that number as you log.';

  @override
  String get insightsTooIrregularTitle =>
      'Your cycles vary too much for a useful range';

  @override
  String get insightsTooIrregularBody =>
      'Cycles that vary this much are worth showing a clinician. Your figures are below, and they get more precise the more you log.';

  @override
  String get insightsLostTrackTitle => 'It has been a while';

  @override
  String insightsLostTrackBody(int days) {
    return 'Nothing logged for $days days. That gap is too long to predict from, so nothing is shown here. Log a day and predictions start again.';
  }

  @override
  String get insightsInconsistentTitle => 'The stored dates disagree';

  @override
  String get insightsInconsistentBody =>
      'Two of the stored dates cannot both be right, so no prediction is shown. Check the calendar for a day that looks wrong.';

  @override
  String get insightsClockChanged =>
      'The device date looks like it has moved backwards. Check it before trusting anything here.';

  @override
  String get insightsYourCyclesTitle => 'Your cycles';

  @override
  String insightsTypicalLength(String days) {
    return 'Typically $days days';
  }

  @override
  String insightsVariability(String days) {
    return 'Varying by about $days days';
  }

  @override
  String insightsRange(int shortest, int longest) {
    return 'Between $shortest and $longest days';
  }

  @override
  String insightsCyclesRecorded(int count) {
    return '$count cycles recorded';
  }

  @override
  String get insightsNotEnoughForStats =>
      'Log a second cycle to see how much yours vary.';

  @override
  String get insightsChartTitle => 'Cycle lengths';

  @override
  String insightsChartSummary(
    int count,
    int shortest,
    int longest,
    String median,
  ) {
    return 'Bar chart of your last $count cycle lengths, from $shortest to $longest days, typically $median.';
  }

  @override
  String get insightsChartShowTable => 'Show as a table';

  @override
  String get insightsChartShowChart => 'Show as a chart';

  @override
  String get insightsChartColumnCycle => 'Cycle';

  @override
  String get insightsChartColumnStarted => 'Started';

  @override
  String get insightsChartColumnLength => 'Length';

  @override
  String insightsChartLengthDays(int days) {
    return '$days days';
  }

  @override
  String get insightsTrackRecordTitle => 'How this app has done';

  @override
  String insightsTrackRecordScore(int total, int hits, int days) {
    return 'Of your last $total predictions, $hits were within $days days.';
  }

  @override
  String insightsTrackRecordError(String days) {
    return 'It has been off by about $days days on average.';
  }

  @override
  String get insightsTrackRecordNotYet =>
      'After a few more cycles, this app will show how accurate its own predictions have been.';

  @override
  String get insightsTrackRecordExplain =>
      'Worked out on this device by re-running the prediction against cycles you had already logged.';

  @override
  String insightsLoggingCompleteness(int logged, int total) {
    return 'You logged $logged of the $total days in this cycle.';
  }

  @override
  String get notificationChannelPredictions => 'Predictions';

  @override
  String get notificationChannelPredictionsDescription =>
      'When a period is expected, and when the predicted window has passed.';

  @override
  String get notificationChannelReminders => 'Logging reminders';

  @override
  String get notificationChannelRemindersDescription =>
      'An occasional prompt if nothing has been logged for a while. Off unless you turn it on.';

  @override
  String get notificationGenericTitle => 'Selene';

  @override
  String get notificationGenericBody =>
      'Open the app to see what this is about.';

  @override
  String get notificationWindowOpeningTitle => 'A period is expected soon';

  @override
  String notificationWindowOpeningBody(String start, String end) {
    return 'The predicted window runs from $start to $end.';
  }

  @override
  String get notificationLikelyStartedTitle => 'Has it started?';

  @override
  String get notificationLikelyStartedBody =>
      'The predicted window is open and nothing is logged yet.';

  @override
  String get notificationNudgeTitle => 'Nothing logged for a while';

  @override
  String get notificationNudgeBody =>
      'Logging a day keeps the predictions useful. No hurry.';

  @override
  String get notificationLateNoticeTitle => 'The predicted window has passed';

  @override
  String get notificationLateNoticeBody =>
      'Nothing has been logged since the window closed. Cycles vary, and a prediction can simply be wrong.';

  @override
  String get notificationLogAction => 'Started today';

  @override
  String get logMissedReminder =>
      'A reminder was due while the app was closed. Some phones stop scheduled reminders to save battery.';

  @override
  String get settingsNudgeEnabled => 'Nudge me if I stop logging';

  @override
  String get settingsNudgeSubtitle =>
      'Off by default. At most one every seven days, and none once predictions have stopped.';

  @override
  String get settingsDetailedNotifications => 'Show details on the lock screen';

  @override
  String get settingsDetailedNotificationsSubtitle =>
      'Off by default. While it is off, notifications show only the app name until the phone is unlocked.';

  @override
  String get settingsBatteryNoteTitle => 'If reminders do not arrive';

  @override
  String get settingsBatteryNoteBody =>
      'Some phones stop scheduled reminders to save battery. If yours stop arriving, allow this app to run in the background in your battery settings.';

  @override
  String get settingsNotificationPermissionTitle => 'Turn on reminders?';

  @override
  String get settingsNotificationPermissionBody =>
      'Now that you have logged a cycle, this app can remind you before the next one is expected. Change it any time.';

  @override
  String get settingsNotificationPermissionAllow => 'Turn on reminders';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDataSection => 'Your data';

  @override
  String get settingsExport => 'Export a backup';

  @override
  String get settingsExportSubtitle =>
      'Writes a file to a location you choose. Nothing else backs this app up.';

  @override
  String settingsExportDone(int count) {
    return 'Backup written: $count days.';
  }

  @override
  String get settingsExportFailed => 'The backup could not be written.';

  @override
  String get settingsImport => 'Restore from a backup';

  @override
  String get settingsImportSubtitle =>
      'Replaces everything currently stored with the contents of the file.';

  @override
  String get settingsImportConfirmTitle => 'Replace everything?';

  @override
  String settingsImportConfirmBody(int count, int incoming) {
    return 'Restoring replaces all $count days currently stored with the $incoming days in this backup. This cannot be undone.';
  }

  @override
  String settingsImportDone(int count, String date) {
    return 'Restored $count days from a backup taken on $date.';
  }

  @override
  String get settingsDeleteAll => 'Delete everything';

  @override
  String get settingsDeleteAllSubtitle =>
      'Remove all the logged days, settings and stored figures.';

  @override
  String get settingsDeleteConfirmTitle => 'Delete everything?';

  @override
  String settingsDeleteConfirmBody(int count, String word) {
    return 'This removes all $count logged days from this device and cannot be undone. There is no copy anywhere else. Type $word to confirm.';
  }

  @override
  String get settingsDeleteConfirmWord => 'DELETE';

  @override
  String settingsDeleteConfirmHint(String word) {
    return 'Type $word';
  }

  @override
  String get settingsDeleteDone => 'Everything has been deleted.';

  @override
  String get settingsRemindersSection => 'Reminders';

  @override
  String get settingsReminderEnabled => 'Remind me before a period is due';

  @override
  String get settingsReminderLeadDays => 'How many days ahead';

  @override
  String settingsReminderDaysValue(int count) {
    return '$count days before';
  }

  @override
  String get settingsReminderSubtitle =>
      'A notification in the morning, the number of days ahead you choose.';

  @override
  String get insightsSuppressedPregnancyTitle =>
      'No prediction while you have a pregnancy recorded';

  @override
  String get insightsSuppressedPregnancyBody =>
      'Your cycles are below, and nothing has been deleted. Add an end date to the pregnancy on the conditions screen and predictions start again.';

  @override
  String calendarPhaseDay(int day) {
    return 'Day $day of your cycle';
  }

  @override
  String get calendarPhasePeriod => 'Period';

  @override
  String get calendarPhaseFollicular => 'Follicular';

  @override
  String get calendarPhaseLuteal => 'Luteal';

  @override
  String get calendarPhasePeriodExplained =>
      'The days you have logged bleeding for. This one comes from what you recorded; the other two are estimated.';

  @override
  String get calendarPhaseFollicularExplained =>
      'The days between the end of your period and ovulation. Cycle length varies most here, which makes it the part this app predicts least well.';

  @override
  String get calendarPhaseLutealExplained =>
      'The days between ovulation and the start of your next period. Its length varies less than the rest of the cycle.';

  @override
  String get calendarPhaseUnknown =>
      'Not enough logged to say which phase this is.';

  @override
  String get calendarOvulationTitle => 'Estimated ovulation';

  @override
  String calendarOvulationRange(String start, String end) {
    return 'Around $start to $end';
  }

  @override
  String get calendarOvulationCaveat =>
      'An estimate from your cycle dates alone. This app cannot observe ovulation, and this must not be used to plan or avoid pregnancy.';

  @override
  String get lockTitle => 'Locked';

  @override
  String get lockBody => 'Unlock to see your diary.';

  @override
  String get lockAction => 'Unlock';

  @override
  String get lockPromptReason => 'Unlock to see your diary';

  @override
  String get settingsSecuritySection => 'Security';

  @override
  String get settingsAppLock => 'Require unlock';

  @override
  String get settingsAppLockSubtitle =>
      'Ask for your fingerprint, face, PIN or pattern before showing the app. It locks again after a minute in the background.';

  @override
  String get settingsAppLockNotEncrypted =>
      'This hides the screen. It does not encrypt anything.';

  @override
  String get settingsAppLockUnavailable =>
      'Your device has no PIN, pattern, password or fingerprint set up, so there is nothing to ask for. Set a screen lock in your device settings, then come back.';

  @override
  String get settingsAppLockNotSupported => 'This device cannot lock the app.';

  @override
  String get reExportTitle => 'Make a fresh backup';

  @override
  String get reExportBody =>
      'This update changed the backup format. Files you saved before now can no longer be restored, so it is worth exporting again. Your data in the app is untouched.';

  @override
  String get reExportAction => 'Export now';

  @override
  String get reExportDismiss => 'Dismiss';

  @override
  String get lookupTitle => 'Look something up';

  @override
  String get lookupSubtitle =>
      'Reference notes stored on this device. Nothing you type here is sent anywhere.';

  @override
  String get lookupSearchHint => 'Search';

  @override
  String get lookupNoResults => 'Nothing here matches that.';

  @override
  String get lookupMedicinesHeading => 'Medicines';

  @override
  String get lookupHygieneHeading => 'Tampons, cups and pads';

  @override
  String lookupMedicinesSource(String date) {
    return 'From US drug labelling published by openFDA, as it stood on $date.';
  }

  @override
  String get lookupMedicinesUsOnly =>
      'This is United States labelling. Strengths, brand names and warnings can differ where you are, so check the packet in front of you.';

  @override
  String get lookupMedicinesUnavailable =>
      'The medicines reference is not built into this version. The other sections still work.';

  @override
  String get lookupSectionPurpose => 'What it is for';

  @override
  String get lookupSectionWarnings => 'Warnings';

  @override
  String get lookupSectionDoNotUse => 'Do not use';

  @override
  String get lookupSectionAskDoctor => 'Ask a doctor';

  @override
  String get lookupSectionStopUse => 'Stop use and ask a doctor';

  @override
  String get lookupSectionPregnancy => 'If pregnant or breastfeeding';

  @override
  String get lookupSearchOnlineTitle => 'Not here?';

  @override
  String get lookupSearchOnlineBody =>
      'This app has no internet access, so it cannot look anything up for you. It can open your browser instead.';

  @override
  String get lookupSearchOnlineAction => 'Open a browser';

  @override
  String get lookupLeavingTitle => 'Leaving the app';

  @override
  String get lookupLeavingBody =>
      'The request comes from your browser rather than from this app. The search leaves your device, and your browser normally keeps it in its history and may sync it to other devices you are signed in on.';

  @override
  String lookupLeavingWithTermBody(String term) {
    return 'The words \"$term\" will be put into the search box, and will appear in your browser history.';
  }

  @override
  String get lookupLeavingContinue => 'Open browser';

  @override
  String get lookupLeavingFailed => 'No browser could be opened.';

  @override
  String get settingsLookup => 'Look something up';

  @override
  String get settingsLookupSubtitle =>
      'Medicines and hygiene product notes, stored on this device.';

  @override
  String get hygieneTssTitle => 'Toxic shock syndrome';

  @override
  String get hygieneTssUrgent =>
      'If you have a sudden high fever, a sunburn-like rash, vomiting, diarrhoea, muscle aches, dizziness or confusion while using a tampon or a menstrual cup: remove it and get urgent medical help.';

  @override
  String get hygieneTssBody =>
      'Toxic shock syndrome is rare and life-threatening. It is caused by bacterial toxins, and it is associated with tampon and menstrual cup use, though it also happens to people who are not menstruating at all.';

  @override
  String get hygieneTamponsTitle => 'Tampons';

  @override
  String get hygieneTamponsBody =>
      'General guidance is to use the lowest absorbency that suits the flow, and to change it as often as the packet says.';

  @override
  String get hygieneCupsTitle => 'Menstrual cups';

  @override
  String get hygieneCupsBody =>
      'Reusable devices worn internally to collect fluid rather than absorb it. Cases of toxic shock syndrome linked to cup use have been reported. How long a cup can be worn, and how it should be cleaned between uses, genuinely differ between products, so follow the instructions that came with yours.';

  @override
  String get hygieneExternalTitle => 'Pads and period underwear';

  @override
  String get hygieneExternalBody =>
      'Worn outside the body. The link with toxic shock syndrome is to products worn inside it.';

  @override
  String get nutritionTitle => 'Supplements';

  @override
  String get nutritionIntro =>
      'Reference notes on the nutrients that come up around menstrual cycles. This is background reading, not advice about your body, and nothing here is based on what you have logged.';

  @override
  String get nutritionIronTitle => 'Iron';

  @override
  String get nutritionIronBody =>
      'Iron is part of haemoglobin, the protein that carries oxygen around the blood. Menstrual bleeding is one of the ways the body loses iron, and heavier bleeding means more of it. Heavy menstrual bleeding is a recognised cause of iron deficiency anaemia, whose commonly listed symptoms include tiredness and lack of energy.';

  @override
  String get nutritionIronDiagnosisNote =>
      'A blood test is what establishes iron deficiency. Symptoms alone cannot, and nothing in this app can.';

  @override
  String get nutritionIronSourcesBody =>
      'Dietary iron comes in two forms: haem iron from meat and fish, and non-haem iron from plants and fortified foods. They are absorbed differently.';

  @override
  String get nutritionVitaminCTitle => 'Vitamin C';

  @override
  String get nutritionVitaminCBody =>
      'Vitamin C eaten in the same meal increases how much non-haem iron the body absorbs. That is the only reason it appears in a menstrual cycle app.';

  @override
  String get nutritionIronCautionBody =>
      'Iron supplements taken without a confirmed deficiency can do harm, because excess iron accumulates rather than being cleared.';

  @override
  String get nutritionMagnesiumTitle => 'Magnesium';

  @override
  String get nutritionMagnesiumBody =>
      'Magnesium is involved in muscle and nerve function, among many other processes. It is found in green leafy vegetables, legumes, nuts, seeds and wholegrains.';

  @override
  String get nutritionMagnesiumEvidenceBody =>
      'Magnesium is widely taken for cramps and premenstrual symptoms. Some trials report a benefit, and reviews of those trials find the evidence limited and not conclusive. Oral forms differ in how well they are absorbed, with glycinate and citrate better absorbed than oxide.';

  @override
  String get nutritionMagnesiumCreamBody =>
      'Creams, oils and balms are sold for the same purpose. Absorption through unbroken skin is minimal: a review of the topic found meaningful absorption unsupported, and the strongest trial of a cream found a change small enough to be chance. No clinical guidance here names magnesium, in any form, as a treatment for period pain.';

  @override
  String get nutritionZincTitle => 'Zinc';

  @override
  String get nutritionZincBody =>
      'Zinc is an essential mineral involved in immune function and wound healing. It is often sold together with magnesium, which matters here because at high doses over time zinc can interfere with how the body absorbs copper.';

  @override
  String get nutritionHintTitle => 'Something worth mentioning';

  @override
  String get nutritionHintBody =>
      'On several days recently you logged heavy flow and fatigue together. That pattern is worth raising with a doctor or nurse, who can look into it properly.';

  @override
  String get settingsNutrition => 'Supplements';

  @override
  String get settingsNutritionSubtitle =>
      'Reference notes on the nutrients that come up around menstrual cycles.';

  @override
  String get weightTitle => 'Body composition and cycle hormones';

  @override
  String get weightIntro =>
      'Reference notes on how body composition and several hormones interact with the menstrual cycle. This is background reading, not advice, and it describes mechanisms rather than any particular body. Nothing on this page is drawn from anything logged in this app.';

  @override
  String get weightOestrogenTitle => 'Where oestrogen is made';

  @override
  String get weightOestrogenBody =>
      'Adipose tissue, or body fat, makes the enzyme aromatase, which converts androgens into oestrogens. That reaction happens in the tissue itself, so the ovaries are not the only place oestrogen comes from.';

  @override
  String get weightOestrogenBalanceBody =>
      'The quantity of adipose tissue is therefore one of the inputs to how much oestrogen is circulating, and it runs in both directions: more of it adds to the total, and very little of it removes a source the ovaries do not make up for. It is one input among several.';

  @override
  String get weightEnergyTitle => 'Energy availability and the hypothalamus';

  @override
  String get weightEnergyBody =>
      'The brain drives the ovaries through a steady rhythm of hormone signals. When the body is running on too little energy that rhythm is suppressed: the signals fall away, ovulation stops, and periods stop with it. The name for that state is functional hypothalamic amenorrhoea.';

  @override
  String get weightEnergyNotAScaleBody =>
      'Energy availability is the energy left over from food once exercise has taken its share, measured against what the body needs to run on. It is a balance between what goes in and what is spent, and a scale reads neither. It happens at entirely unremarkable body weights, and heavy training, illness or sustained stress can bring it on while weight holds steady.';

  @override
  String get weightInsulinTitle => 'Insulin, SHBG and free androgen';

  @override
  String get weightInsulinBody =>
      'Sex hormone binding globulin, or SHBG, is a protein the liver puts into the blood, where it binds testosterone. Bound testosterone is held out of circulation, so only the free fraction reaches tissue. Insulin resistance lowers SHBG, and as SHBG falls the free fraction rises, even when the total amount of testosterone has not changed.';

  @override
  String get weightPcosTitle => 'PMOS';

  @override
  String get weightPcosBody =>
      'Polyendocrine metabolic ovarian syndrome, formerly polycystic ovary syndrome, is androgen excess together with irregular or absent ovulation. Insulin resistance is common alongside it, and the mechanism above is part of how the androgen excess is sustained.';

  @override
  String get weightPcosSpectrumBody =>
      'PMOS occurs across the whole weight spectrum, including in people who are thin. The widespread impression that it belongs at one end is wrong, and it is one reason the condition goes unrecognised.';

  @override
  String get weightThyroidTitle => 'Thyroid function';

  @override
  String get weightThyroidBody =>
      'Thyroid disease affects the menstrual cycle too, in both directions. An underactive thyroid is associated with heavier and more frequent bleeding; an overactive one with lighter, less frequent bleeding, or with none. Thyroid function is established by a blood test rather than by the shape of a cycle.';

  @override
  String get weightChangeTitle => 'When a cycle changes';

  @override
  String get weightChangeBody =>
      'A change in cycle length, in the amount of bleeding, or in whether periods arrive at all has many possible causes, and the mechanisms on this page are only some of them. Cycle dates cannot separate one cause from another, and nothing in this app can diagnose anything. A doctor or nurse is who can work out which one it is.';

  @override
  String get weightEntryTitle => 'Body composition and cycle hormones';

  @override
  String get weightEntrySubtitle =>
      'How body fat, energy availability, insulin and thyroid function interact with the cycle.';

  @override
  String get movementTitle => 'Pain and movement across the cycle';

  @override
  String get movementIntro =>
      'Reference notes on period pain, on what movement does about it, and on how well the evidence supports the popular advice. This is background reading, not advice, and it describes what is known about bodies in general. It draws on nothing you have logged.';

  @override
  String get movementPainTitle => 'What period pain is';

  @override
  String get movementPainBody =>
      'Painful menstruation with no underlying disorder behind it is called primary dysmenorrhoea. The pain is typically cramping, felt low in the abdomen, strongest around the start of bleeding and easing over the following days. Prostaglandins released from the lining of the uterus drive the contractions that produce it. Where there is an underlying cause, such as endometriosis, adenomyosis or uterine fibroids, the term is secondary dysmenorrhoea.';

  @override
  String get movementNotAvoidedTitle =>
      'A period is not a reason to stop moving';

  @override
  String get movementNotAvoidedBody =>
      'Menstruation is not named anywhere in the sources behind this page as a reason to stop, and general physical activity guidance makes no exception for the days of a period.';

  @override
  String get movementHowItFeelsTitle => 'What changes is how it feels';

  @override
  String get movementHowItFeelsBody =>
      'What varies across a cycle is how moving feels. Cramping pain around the start of bleeding, tiredness and low energy in the days before and during it, and how hard a given effort seems on the day are all part of that. The variation is wide between people, and wide between one cycle and the next in the same person, which is why none of it turns into a rule.';

  @override
  String get movementRestTitle => 'Doing less is allowed';

  @override
  String get movementRestBody =>
      'If you want to do less on a given day, or nothing at all, that is a reasonable choice. This page gives you permission rather than instructions: it holds you to no target, so there is nothing here to fall short of.';

  @override
  String get movementStopSignalsTitle => 'Signals to stop';

  @override
  String get movementStopSignalsBody =>
      'Some things are reasons to stop. Feeling faint or light-headed during exertion, breathlessness out of proportion to the effort, and chest pain are among them, and each is worth getting looked at. None of this is particular to menstruation. It applies whenever it happens.';

  @override
  String get movementAnaemiaBody =>
      'Exertion can feel harder around heavy periods, and there is a recognised reason for it. Heavy menstrual bleeding is a known cause of iron deficiency anaemia, whose commonly listed symptoms include tiredness, lack of energy and shortness of breath. A blood test is what confirms iron deficiency, rather than how a day felt, and it is worth taking to a doctor or nurse.';

  @override
  String get movementPhaseClaimsTitle => 'Planning exercise around cycle phase';

  @override
  String get movementPhaseClaimsBody =>
      'Schemes that assign different kinds of exercise to different parts of the cycle are widely promoted. The evidence underneath them is weak. Systematic review of cycle phase and exercise performance describes that research as low quality and inconsistent: the average effects are trivial, and the differences between individuals are larger than the effect being looked for. No clinical guidance in the sources behind this page recommends planning exercise around cycle phase, and none says the chance of injury rises or falls with it.';

  @override
  String get movementContraceptionBody =>
      'Hormonal contraception is another reason these schemes do not carry over. The combined pill works by stopping ovulation, so the rise and fall of oestrogen and progesterone that a phase-based plan assumes is not happening at all. A plan built on cycle phases has nothing underneath it when those phases are not occurring.';

  @override
  String get movementSeeSomeoneTitle => 'Pain worth taking to someone';

  @override
  String get movementSeeSomeoneBody =>
      'Period pain that is severe, that is getting worse, that the usual measures do not ease, or that gets in the way of ordinary days is a reason to see a doctor or nurse. So is pain that began later in life, changed in character, or arrives alongside other symptoms. The causes named above are found by assessment rather than by tracking dates. No threshold is offered here, and no scale for you to score yourself against.';

  @override
  String get movementEntryTitle => 'Pain and movement across the cycle';

  @override
  String get movementEntrySubtitle =>
      'What exercise does about period pain, how weak the evidence for planning it by cycle phase is, and what is a reason to stop.';

  @override
  String get companionLabel => 'Companion';

  @override
  String get companionDismiss => 'Dismiss';

  @override
  String get companionLineStillReading => 'The log is still being read.';

  @override
  String get companionLinePredictionPaused =>
      'A pregnancy is recorded, so predictions are paused. Days can still be logged.';

  @override
  String get companionLineHeavyBleeding =>
      'Heavy bleeding is recorded on several days. Heavy menstrual bleeding is a recognised cause of iron deficiency anaemia. A blood test is what settles it.';

  @override
  String get companionLineCramps =>
      'Cramps are recorded for today. Guidance on period pain lists heat, painkillers and exercise among the measures that may help.';

  @override
  String get companionLineSleep =>
      'Disturbed sleep is recorded for today. Sleep problems are among the symptoms commonly reported around a period.';

  @override
  String get companionLineLowEnergy =>
      'Low energy is recorded for today. Tiredness is among the symptoms commonly reported before and during a period.';

  @override
  String get companionLinePeriodToday =>
      'A period is logged for today. Menstruation is not named anywhere in the guidance behind this app as a reason to stop moving.';

  @override
  String get companionLineOverdue =>
      'The predicted window has passed with no period logged. That is a data state, and nothing here guesses at the reason.';

  @override
  String get companionLineNothingLoggedRecently =>
      'Nothing has been logged for a few days. The log is on the first tab, whenever there is something to put in it.';

  @override
  String get companionLineNoLogsYet =>
      'Nothing is recorded yet. One period start date is enough to begin.';

  @override
  String get companionLineNoPredictionYet =>
      'There is not enough history for a prediction yet. Insights holds what has been recorded so far.';

  @override
  String get companionLineTodayLogged =>
      'Today is already logged. The day can be opened again and changed.';

  @override
  String get companionLineNothingToPointAt => 'Nothing to point at just now.';

  @override
  String get conditionsTitle => 'Conditions and medication';

  @override
  String get conditionsSubtitle =>
      'Things that can change your cycle. Recorded so you can read your own history with them in mind. They are not used to work out your predictions.';

  @override
  String get conditionsEmpty => 'Nothing recorded.';

  @override
  String get conditionsAdd => 'Add';

  @override
  String get conditionsAddTitle => 'Add a condition';

  @override
  String conditionsStarted(String date) {
    return 'Started $date';
  }

  @override
  String conditionsSpan(String start, String end) {
    return '$start to $end';
  }

  @override
  String get conditionsOngoing => 'Ongoing';

  @override
  String get conditionsEnd => 'Mark as ended';

  @override
  String get conditionsReopen => 'Still ongoing';

  @override
  String get conditionsRemove => 'Delete';

  @override
  String get conditionsStartDate => 'Start date';

  @override
  String get conditionsEndDate => 'End date';

  @override
  String conditionsOverlap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cycles logged while this was recorded',
      one: '1 cycle logged while this was recorded',
    );
    return '$_temp0';
  }

  @override
  String get conditionHormonalContraceptionCombined => 'Combined pill';

  @override
  String get conditionHormonalContraceptionProgestogen =>
      'Progestogen-only pill';

  @override
  String get conditionHormonalIud => 'Hormonal IUD';

  @override
  String get conditionContraceptiveImplant => 'Implant';

  @override
  String get conditionCopperIud => 'Copper IUD';

  @override
  String get conditionPregnancy => 'Pregnancy';

  @override
  String get conditionPostpartum => 'Postpartum';

  @override
  String get conditionBreastfeeding => 'Breastfeeding';

  @override
  String get conditionPcos => 'PMOS';

  @override
  String get conditionEndometriosis => 'Endometriosis';

  @override
  String get conditionThyroidDisorder => 'Thyroid disorder';

  @override
  String get conditionPerimenopause => 'Perimenopause';

  @override
  String get conditionUterineFibroids => 'Uterine fibroids';

  @override
  String get conditionOther => 'Other';

  @override
  String get settingsConditions => 'Conditions and medication';

  @override
  String get settingsConditionsSubtitle =>
      'Record long-term things that can change your cycle.';

  @override
  String get learnTitle => 'Learn';

  @override
  String get learnIntro =>
      'Notes that are intended for your perusal and assistance.';

  @override
  String get learnReferenceSection => 'Reference';

  @override
  String get learnYourRecordSection => 'Your record';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSubtitle => 'Colour scheme and light or dark.';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceSchemeSection => 'Colour scheme';

  @override
  String get appearanceSchemeNote =>
      'Every scheme here was measured for contrast before it was offered. Pick the one you like.';

  @override
  String get appearanceThemeSection => 'Theme';

  @override
  String get appearanceThemeSystem => 'System';

  @override
  String get appearanceThemeLight => 'Light';

  @override
  String get appearanceThemeDark => 'Dark';

  @override
  String get appearanceThemeLockedByScheme =>
      'Night is a dark scheme, so there is nothing to switch here. Pick another scheme to get the choice back.';

  @override
  String appearanceSchemeSelected(String scheme) {
    return '$scheme, selected';
  }

  @override
  String get appearanceSchemeRose => 'Rose & Plum';

  @override
  String get appearanceSchemeRoseSubtitle => 'Warm, soft';

  @override
  String get appearanceSchemeSage => 'Sage & Apricot';

  @override
  String get appearanceSchemeSageSubtitle => 'Calm, botanical';

  @override
  String get appearanceSchemeLilac => 'Lilac & Sage';

  @override
  String get appearanceSchemeLilacSubtitle => 'Cool, quiet';

  @override
  String get appearanceSchemePeriwinkle => 'Periwinkle & Clay';

  @override
  String get appearanceSchemePeriwinkleSubtitle => 'Soft blue, terracotta';

  @override
  String get appearanceSchemeInk => 'Ink & Ochre';

  @override
  String get appearanceSchemeInkSubtitle => 'Near-monochrome, discreet';

  @override
  String get appearanceSchemeNight => 'Night';

  @override
  String get appearanceSchemeNightSubtitle => 'Dark from the start';

  @override
  String get settingsDisplaySection => 'Display';

  @override
  String get settingsFlowSimplified => 'Simple flow';

  @override
  String get settingsFlowSimplifiedSubtitle =>
      'Record bleeding as yes or no rather than an intensity. Anything already recorded is kept, and comes back if you turn this off.';

  @override
  String get settingsCyclePhases => 'Name the cycle phase';

  @override
  String get settingsCyclePhasesSubtitle =>
      'Show Period, Follicular or Luteal on the calendar, alongside the day of your cycle.';

  @override
  String get settingsOvulationWindow => 'Estimated ovulation';

  @override
  String get settingsOvulationWindowSubtitle =>
      'Show an estimated ovulation range. Worked out from your cycle dates alone, and not accurate enough to plan or avoid pregnancy with.';

  @override
  String get settingsPrivacySection => 'Privacy';

  @override
  String get settingsPrivacyTitle => 'What this app does with your data';

  @override
  String get settingsLogViewer => 'Activity log';

  @override
  String get settingsLogViewerSubtitle =>
      'Everything this app records about itself.';

  @override
  String get settingsLogViewerEmpty => 'Nothing recorded yet.';

  @override
  String get settingsLogViewerClear => 'Clear the log';

  @override
  String get settingsLogViewerCleared => 'Log cleared.';

  @override
  String get settingsAboutSection => 'About';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String settingsModelVersion(String version) {
    return 'Prediction model $version';
  }

  @override
  String get privacyHeading => 'What this app does with your data';

  @override
  String get privacyOnDeviceTitle => 'Everything stays on this phone';

  @override
  String get privacyOnDeviceBody =>
      'This app has no internet permission, and a check on every release refuses to build one that asks for it. There is no account to sign into, no sync, and it collects no analytics or crash reports. What you record stays here until you export it.';

  @override
  String get privacyNotEncryptedTitle => 'The database is not encrypted';

  @override
  String get privacyNotEncryptedBody =>
      'Your data sits in this app\'s own storage. Other apps cannot read it on a phone that has not been tampered with, and Android\'s full-device encryption protects it while the phone is switched off. But it is stored as plain text, so anyone who picks up your unlocked phone, or takes a forensic copy of it, can read it. The app lock hides the screen. It does not encrypt the file underneath.';

  @override
  String get privacyBackupTitle => 'Nothing is backed up to the cloud';

  @override
  String get privacyBackupBody =>
      'Android\'s automatic backup is switched off for this app, so your cycle history is never copied to a Google account. If you lose the phone, the data is gone unless you exported it.';

  @override
  String get privacyDeletionTitle => 'Deleting really deletes';

  @override
  String get privacyDeletionBody =>
      'Deleting a day removes the row. Deleting everything removes every row and then reclaims the space, so the old entries are not left readable in the file. Nothing is kept behind a hidden flag.';

  @override
  String get privacyLogsTitle => 'The activity log holds no cycle content';

  @override
  String get privacyLogsBody =>
      'This app keeps a short log of what it did, such as \"a prediction was computed\" with a count of cycles. You can read it and clear it in Settings.';

  @override
  String get privacyExportTitle => 'Exports are yours to look after';

  @override
  String get privacyExportBody =>
      'An exported backup is a plain readable file wherever you chose to put it, with no protection of its own. Anywhere you save it or send it is outside this app\'s control.';

  @override
  String get bootstrapRecoveredTitle => 'Your data could not be read';

  @override
  String get bootstrapRecoveredBody =>
      'The stored file was damaged, so this app started with an empty one. The damaged file is still on the device. If you have a backup, restoring it now is the best way forward.';

  @override
  String get bootstrapRecoveredAction => 'Restore from a backup';

  @override
  String get bootstrapNewerSchemaTitle => 'This app needs updating';

  @override
  String bootstrapNewerSchemaBody(int stored, int supported) {
    return 'The data on this device was written by a newer version of this app (storage version $stored; this version understands $supported). Nothing has been changed. Install the newer version to carry on.';
  }

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get errorWriteRefusedFuture => 'That day has not happened yet.';

  @override
  String get errorWriteRefusedExists =>
      'That day is already logged. Press and hold it in the calendar to change it.';
}
