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
  String get navLog => 'Log';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navInsights => 'Insights';

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
      'It is not contraception. It cannot tell you when sex is unlikely to lead to pregnancy, and it must never be used to try.';

  @override
  String get onboardingNotMedical =>
      'It is not medical advice. If something about your cycle worries you, talk to a clinician.';

  @override
  String get onboardingNotDiagnostic =>
      'It cannot diagnose anything. It sees only the dates you record — nothing about contraception you take, pregnancy, medication, illness or stress.';

  @override
  String get onboardingAlwaysARange =>
      'Predictions are always a range of days, never a single date. Cycles vary, and one date would claim a precision this app does not have.';

  @override
  String get onboardingAcknowledge => 'I understand';

  @override
  String get onboardingFirstEntryTitle => 'When did your last period start?';

  @override
  String get onboardingFirstEntryBody =>
      'One date is enough to begin. Predictions start out wide and narrow as you log more cycles.';

  @override
  String get onboardingFirstEntrySkip => 'Skip for now';

  @override
  String get onboardingFirstEntrySaved => 'Saved. You can change it any time.';

  @override
  String get logTitle => 'Today';

  @override
  String logTodayIs(String date) {
    return 'Today is $date';
  }

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
      'Optional, and never used for predictions. Tap again to clear.';

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
  String get onboardingSensitiveTitle =>
      'One thing worth knowing before you start';

  @override
  String get onboardingSensitiveBody =>
      'You can record intercourse, and whether it was protected. It is the most sensitive thing stored here: it never leaves your device, is never used to predict anything, and is never required. The app lock in settings can ask for your fingerprint or PIN before anything shows.';

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
      'Welcome back. Log a day whenever you are ready and the predictions will pick up again.';

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
      'No predicted window is shown, because there is not enough to go on yet.';

  @override
  String get calendarLongPressHint => 'Hold any day to change it.';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsDisclaimer =>
      'Predictions are estimates from the dates you have logged. Not contraception, not medical advice.';

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
      'About four times in five it starts in this range.';

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
  String insightsNotPersonalisedYet(int count) {
    return 'Based on typical cycles rather than yours. Your own figures take over after $count cycles.';
  }

  @override
  String get insightsNoDataTitle => 'Nothing logged yet';

  @override
  String get insightsNoDataBody =>
      'Log the day your last period started and this screen fills in. Typical cycles run about 29 days, but yours are what matter here.';

  @override
  String get insightsTooIrregularTitle =>
      'Your cycles vary too much for a useful range';

  @override
  String get insightsTooIrregularBody =>
      'That is information, not a failure — and worth showing a clinician. Your figures are below; logging more keeps them sharp.';

  @override
  String get insightsLostTrackTitle => 'It has been a while';

  @override
  String insightsLostTrackBody(int days) {
    return 'Nothing logged for $days days, so this app has lost the thread rather than guess. Log a day and it picks up again.';
  }

  @override
  String get insightsInconsistentTitle => 'Something does not add up';

  @override
  String get insightsInconsistentBody =>
      'The stored dates contradict each other, so no prediction is shown. Check the calendar for a day that looks wrong.';

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
      'Worked out on this device by re-running the prediction against cycles you had already logged. Nothing is sent anywhere.';

  @override
  String insightsLoggingCompleteness(int logged, int total) {
    return 'You logged $logged of the $total days in this cycle.';
  }

  @override
  String get notificationChannelPredictions => 'Predictions';

  @override
  String get notificationChannelPredictionsDescription =>
      'When a period is expected, and when one looks late.';

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
      'Nothing has been logged since the window closed. Cycles vary for many reasons, and a prediction being wrong is one of them.';

  @override
  String get notificationLogAction => 'Started today';

  @override
  String get logMissedReminder =>
      'A reminder was due while the app was closed. Some phones stop scheduled reminders to save battery.';

  @override
  String get settingsNudgeEnabled => 'Nudge me if I stop logging';

  @override
  String get settingsNudgeSubtitle =>
      'Off by default. At most one every seven days, and never after the app has lost track.';

  @override
  String get settingsDetailedNotifications => 'Show details on the lock screen';

  @override
  String get settingsDetailedNotificationsSubtitle =>
      'Off by default. With this off, notifications say only the app name until the phone is unlocked.';

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
      'Writes a file you choose the location of. This is the only backup there is.';

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
      'Removes every day, setting and stored figure from this device for good.';

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
      'A notification in the morning, the chosen number of days ahead.';

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
      'The days you have logged bleeding for. This one is read from what you recorded, not estimated.';

  @override
  String get calendarPhaseFollicularExplained =>
      'The stretch after your period ends. Most of the variation between cycles sits here, which makes it the part this app is least certain about.';

  @override
  String get calendarPhaseLutealExplained =>
      'The run of days before your next period is due. It tends to be the steadiest part of the cycle, which is why it is counted back from the date expected rather than forward from the last one.';

  @override
  String get calendarPhaseUnknown => 'Not enough logged to say where you are.';

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
      'This hides the screen. It does not encrypt your data, which is stored unencrypted in the app\'s private storage either way.';

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
  String get lookupCuratedNote =>
      'Written for this app and checked against the sources listed in HYGIENE_SOURCES.md. Not a regulator\'s own wording, unlike the medicines below.';

  @override
  String lookupMedicinesSource(String date) {
    return 'From US drug labelling published by openFDA, as it stood on $date.';
  }

  @override
  String get lookupMedicinesUsOnly =>
      'This is United States labelling. Strengths, brand names and warnings can differ where you are — check the packet you actually have.';

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
      'Your browser will make the request, not this app. The search leaves your device, and your browser normally keeps it in its history and may sync it to other devices you are signed in on.';

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
      'Toxic shock syndrome is rare and life-threatening. It is caused by bacterial toxins, and it is associated with tampon and menstrual cup use — though it also happens to people who are not menstruating at all.';

  @override
  String get hygieneTamponsTitle => 'Tampons';

  @override
  String get hygieneTamponsBody =>
      'Regulated as medical devices rather than as drugs, which is why they are not in the medicines section. Absorbency ratings are standardised, so the same rating means the same thing across brands. General guidance is to use the lowest absorbency that suits the flow, and to change it as often as the packet says rather than leaving it longer.';

  @override
  String get hygieneCupsTitle => 'Menstrual cups';

  @override
  String get hygieneCupsBody =>
      'Reusable devices worn internally to collect fluid rather than absorb it. Cases of toxic shock syndrome linked to cup use have been reported. How long a cup can be worn, and how it should be cleaned between uses, genuinely differ between products — follow the instructions that came with yours rather than a number from an app.';

  @override
  String get hygieneExternalTitle => 'Pads and period underwear';

  @override
  String get hygieneExternalBody =>
      'Worn outside the body, and not associated with toxic shock syndrome in the way internally worn products are.';

  @override
  String get nutritionTitle => 'Iron and magnesium';

  @override
  String get nutritionIntro =>
      'Reference notes on two nutrients that come up around menstrual cycles. This is background reading, not advice about your body, and nothing here is based on what you have logged.';

  @override
  String get nutritionIronTitle => 'Iron';

  @override
  String get nutritionIronBody =>
      'Iron is part of haemoglobin, the protein that carries oxygen around the blood. Menstrual bleeding is one of the ways the body loses iron, and heavier bleeding means more of it. Heavy menstrual bleeding is a recognised cause of iron deficiency anaemia, whose commonly listed symptoms include tiredness and lack of energy.';

  @override
  String get nutritionIronDiagnosisNote =>
      'Iron deficiency is confirmed by a blood test. Symptoms alone cannot establish it, and neither can anything in this app.';

  @override
  String get nutritionIronSourcesBody =>
      'Dietary iron comes in two forms: haem iron from meat and fish, and non-haem iron from plants and fortified foods. They are absorbed differently.';

  @override
  String get nutritionVitaminCTitle => 'Why vitamin C is listed here';

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
      'Evidence that magnesium supplements improve menstrual symptoms is limited and not conclusive.';

  @override
  String get nutritionZincTitle => 'Why zinc is listed here';

  @override
  String get nutritionZincBody =>
      'Zinc is an essential mineral involved in immune function and wound healing. It is often sold together with magnesium, which is worth knowing alongside the next line: taken at high doses over time, zinc can interfere with how the body absorbs copper.';

  @override
  String get nutritionHintTitle => 'Something worth mentioning';

  @override
  String get nutritionHintBody =>
      'On several days recently you logged heavy flow and fatigue together. That pattern is worth raising with a doctor or nurse, who can look into it properly.';

  @override
  String get nutritionSourcesNote =>
      'Every claim on this page is listed with its source in NUTRITION_SOURCES.md in the app\'s source repository.';

  @override
  String get settingsNutrition => 'Iron and magnesium';

  @override
  String get settingsNutritionSubtitle =>
      'Reference notes on two nutrients that come up around menstrual cycles.';

  @override
  String get weightTitle => 'Body composition and cycle hormones';

  @override
  String get weightIntro =>
      'Reference notes on how body composition and several hormones interact with the menstrual cycle. This is background reading, not advice, and it describes mechanisms rather than any particular body. Nothing on this page is drawn from anything logged in this app.';

  @override
  String get weightNothingToEnterBody =>
      'This app records no body weight and asks for none. There is nothing to enter here, and no figure on this page to measure a body against.';

  @override
  String get weightOestrogenTitle => 'Where oestrogen is made';

  @override
  String get weightOestrogenBody =>
      'Adipose tissue — body fat — makes the enzyme aromatase, which converts androgens into oestrogens. That reaction happens in the tissue itself, so the ovaries are not the only place oestrogen comes from.';

  @override
  String get weightOestrogenBalanceBody =>
      'The quantity of adipose tissue is therefore one of the inputs to how much oestrogen is circulating, and it runs in both directions: more of it adds to the total, and very little of it removes a source the ovaries do not make up for. It is one input among several rather than the whole picture.';

  @override
  String get weightEnergyTitle => 'Energy availability and the hypothalamus';

  @override
  String get weightEnergyBody =>
      'The hypothalamus releases GnRH in pulses, and that rhythm is what drives LH and FSH from the pituitary, which in turn drive the ovary. When energy availability is low the pulses are suppressed: LH and FSH fall, ovulation stops, and periods stop with it. That state has a name — functional hypothalamic amenorrhoea.';

  @override
  String get weightEnergyNotAScaleBody =>
      'Energy availability is what is left of the energy taken in once exercise has had its share, measured against what the body needs to run on. It is not a body weight and it is not a reading from a scale. Functional hypothalamic amenorrhoea occurs in people whose body weight is entirely unremarkable, and heavy training, illness or sustained stress can produce it with no fall in body weight at all.';

  @override
  String get weightInsulinTitle => 'Insulin, SHBG and free androgen';

  @override
  String get weightInsulinBody =>
      'Sex hormone binding globulin, or SHBG, is a protein the liver puts into the blood, where it binds testosterone. Bound testosterone is held out of circulation, so only the free fraction reaches tissue. Insulin resistance lowers SHBG, and as SHBG falls the free fraction rises — even when the total amount of testosterone has not changed.';

  @override
  String get weightPcosTitle => 'PCOS';

  @override
  String get weightPcosBody =>
      'Polycystic ovary syndrome is androgen excess together with irregular or absent ovulation. Insulin resistance is common alongside it, and the mechanism above is part of how the androgen excess is sustained.';

  @override
  String get weightPcosSpectrumBody =>
      'PCOS occurs across the whole weight spectrum, in people who are thin as well as in people who are not. The widespread impression that it belongs at one end of that spectrum is not accurate, and it is one of the reasons the condition goes unrecognised.';

  @override
  String get weightThyroidTitle => 'Thyroid function';

  @override
  String get weightThyroidBody =>
      'Thyroid disease reaches the menstrual cycle too, and in both directions. An underactive thyroid is associated with heavier and more frequent bleeding; an overactive one with lighter, less frequent bleeding, or with none. Thyroid function is established by a blood test rather than by the shape of a cycle.';

  @override
  String get weightChangeTitle => 'When a cycle changes';

  @override
  String get weightChangeBody =>
      'A change in cycle length, in the amount of bleeding, or in whether periods arrive at all has many possible causes, and the mechanisms on this page are only some of them. Cycle dates cannot separate one cause from another, and nothing in this app can diagnose anything. A change worth explaining is worth taking to a doctor or nurse.';

  @override
  String get weightSourcesNote =>
      'Every claim on this page is listed with its source in WEIGHT_SOURCES.md in the app\'s source repository.';

  @override
  String get weightEntryTitle => 'Body composition and cycle hormones';

  @override
  String get weightEntrySubtitle =>
      'How body fat, energy availability, insulin and thyroid function interact with the cycle.';

  @override
  String get conditionsTitle => 'Conditions and medication';

  @override
  String get conditionsSubtitle =>
      'Things that can change your cycle. Recorded so you can read your own history with them in mind — they are not used to work out your predictions.';

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
  String get conditionPcos => 'PCOS';

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
      'Everything this app records about itself. Read it: there are no dates or symptoms in here.';

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
  String get settingsAboutBody =>
      'Built as a personal project. No accounts, no analytics, no network permission.';

  @override
  String get privacyHeading => 'What this app does with your data';

  @override
  String get privacyOnDeviceTitle => 'Everything stays on this phone';

  @override
  String get privacyOnDeviceBody =>
      'This app has no internet permission — a check on every release refuses to build one that asks for it. No account, no sync, no analytics, no crash reporting. Nothing leaves this device unless you export it.';

  @override
  String get privacyNotEncryptedTitle => 'The database is not encrypted';

  @override
  String get privacyNotEncryptedBody =>
      'This is the honest limit of what \"private\" means here. Your data sits in this app\'s own storage, which other apps cannot read on a phone that has not been tampered with, and which Android\'s full-device encryption protects while the phone is switched off. But it is stored as plain text. Anyone who picks up your unlocked phone, or who takes a forensic copy of it, can read it. The app lock does not encrypt anything: it covers the screen, not the file.';

  @override
  String get privacyBackupTitle => 'It is never backed up to the cloud';

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
      'This app keeps a short log of what it did, such as \"a prediction was computed\" with a count of cycles. It is structurally incapable of recording a date, a flow level or a symptom. You can read it and clear it in Settings.';

  @override
  String get privacyExportTitle => 'Exports are yours to look after';

  @override
  String get privacyExportBody =>
      'An exported backup is a plain readable file wherever you chose to put it, with no protection of its own. Anywhere you save it or send it is outside this app\'s control.';

  @override
  String get bootstrapRecoveredTitle => 'Your data could not be read';

  @override
  String get bootstrapRecoveredBody =>
      'The stored file was damaged, so this app started with an empty one. The damaged file has been kept, not deleted. If you have a backup, restoring it now is the best way forward.';

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
