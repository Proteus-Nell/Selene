// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Period Tracker';

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
      'This app records your cycle on this device and predicts when your next period is likely to start. Everything stays on the phone: it has no internet permission at all, so nothing can be sent anywhere.';

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
      'It cannot diagnose anything. It sees only the dates you record, so it knows nothing about contraception you take, pregnancy, medication, illness or stress.';

  @override
  String get onboardingAlwaysARange =>
      'Predictions are always a range of days, never a single date. Cycles vary, and a single date would claim a precision this app does not have.';

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
  String get calendarLongPressHint => 'Press and hold any day to change it.';

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
    return 'Based on typical cycles rather than yours. It will use your own figures once you have logged $count cycles.';
  }

  @override
  String get insightsNoDataTitle => 'Nothing logged yet';

  @override
  String get insightsNoDataBody =>
      'Log the day your last period started and this screen will start filling in. Typical cycles run about 29 days, but yours are what matter here.';

  @override
  String get insightsTooIrregularTitle =>
      'Your cycles vary too much for a useful range';

  @override
  String get insightsTooIrregularBody =>
      'That is information, not a failure, and it is worth showing a clinician. Your own figures are below, and logging more will keep them sharp.';

  @override
  String get insightsLostTrackTitle => 'It has been a while';

  @override
  String insightsLostTrackBody(int days) {
    return 'Nothing has been logged for $days days, so this app has lost the thread rather than guess. Log a day and it will pick up again.';
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
      'Once you have logged a few more cycles, this app will show you how accurate its own predictions have been.';

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
  String get notificationGenericTitle => 'Period Tracker';

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
      'Some phones stop scheduled reminders to save battery. If reminders stop arriving, allow this app to run in the background in the system battery settings.';

  @override
  String get settingsNotificationPermissionTitle => 'Turn on reminders?';

  @override
  String get settingsNotificationPermissionBody =>
      'Now that you have logged a cycle, this app can remind you before the next one is expected. You can change this at any time.';

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
      'Your cycles are below, and nothing has been deleted. Add an end date to the pregnancy on the conditions screen and predictions will start again.';

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
      'The stretch after your period ends. Its length is where most of the variation between cycles sits, so it is the part this app is least certain about.';

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
      'Record bleeding as yes or no, instead of choosing an intensity. Anything already recorded is kept, and comes back if you turn this off.';

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
      'Everything this app records about its own behaviour. Read it: there are no dates or symptoms in here.';

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
      'This app has no internet permission. It is removed from the app\'s manifest, and an automated check on every release refuses to build an app that asks for it. There is no account, no sync, no analytics and no crash reporting. Nothing you record can leave this device unless you export it yourself.';

  @override
  String get privacyNotEncryptedTitle => 'The database is not encrypted';

  @override
  String get privacyNotEncryptedBody =>
      'This is the honest limit of what \"private\" means here. Your data sits in this app\'s own storage, which other apps cannot read on a phone that has not been tampered with, and which Android\'s full-device encryption protects while the phone is switched off. But it is stored as plain text. Anyone who picks up your unlocked phone, or who takes a forensic copy of it, can read it. There is no app lock in this version.';

  @override
  String get privacyBackupTitle => 'It is never backed up to the cloud';

  @override
  String get privacyBackupBody =>
      'Android\'s automatic backup is switched off for this app, so your cycle history is never copied to a Google account. The consequence is that if you lose the phone, the data is gone unless you exported it.';

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
      'The stored file was damaged, so this app started with an empty one. The damaged file has been kept next to it and has not been deleted. If you have a backup, restoring it now is the best way forward.';

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
