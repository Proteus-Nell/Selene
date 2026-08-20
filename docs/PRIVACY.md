# Privacy

**This file is the source of the privacy text shown inside the app.** The
sections below are shipped verbatim on the Settings screen, and
`app/test/features/privacy_text_test.dart` fails if the two ever drift apart.
Change the wording here and in `app/lib/l10n/app_en.arb` together.

It is written to be read by the person using the app, not by a lawyer. In
particular it says plainly what is *not* protected, because the accepted risk
in [DECISIONS.md ADR-0004](DECISIONS.md#adr-0004-unencrypted-local-sqlite-with-zero-network-permission)
is only defensible if the user is told about it.

---

## What this app does with your data

### Everything stays on this phone

This app has no internet permission. It is removed from the app's manifest, and an automated check on every release refuses to build an app that asks for it. There is no account, no sync, no analytics and no crash reporting. Nothing you record can leave this device unless you export it yourself.

### The database is not encrypted

This is the honest limit of what "private" means here. Your data sits in this app's own storage, which other apps cannot read on a phone that has not been tampered with, and which Android's full-device encryption protects while the phone is switched off. But it is stored as plain text. Anyone who picks up your unlocked phone, or who takes a forensic copy of it, can read it. There is no app lock in this version.

### It is never backed up to the cloud

Android's automatic backup is switched off for this app, so your cycle history is never copied to a Google account. The consequence is that if you lose the phone, the data is gone unless you exported it.

### Deleting really deletes

Deleting a day removes the row. Deleting everything removes every row and then reclaims the space, so the old entries are not left readable in the file. Nothing is kept behind a hidden flag.

### The activity log holds no cycle content

This app keeps a short log of what it did, such as "a prediction was computed" with a count of cycles. It is structurally incapable of recording a date, a flow level or a symptom. You can read it and clear it in Settings.

### Exports are yours to look after

An exported backup is a plain readable file wherever you chose to put it, with no protection of its own. Anywhere you save it or send it is outside this app's control.

---

## Threat model, in one table

| Threat | Covered? |
| --- | --- |
| Network interception or a server breach | Yes, completely. There is no network and no server. |
| Another app on the same device reading the data | Yes on a device that has not been rooted, through the Android app sandbox. |
| Cloud backup exfiltration | Yes. Automatic backup is switched off for this app. |
| Someone picking up your unlocked phone | **No.** There is no app lock in this version. |
| A device seized and forensically imaged, or legal compulsion | **Partly.** Android's full-device encryption protects a phone that is switched off. Once unlocked, the database is plain text. |

The last two rows are the honest limits of this design. They are recorded
rather than hidden, and an app lock is the first privacy feature queued after
the MVP.

## Permissions this app asks for

Two, and nothing else:

- **`POST_NOTIFICATIONS`** — the runtime prompt, asked once, and only after you
  have logged a cycle. Decline it and everything else still works.
- **`RECEIVE_BOOT_COMPLETED`** — granted at install with no prompt, so it is
  easy to miss when reviewing the app. It exists for one reason: Android drops
  every scheduled alarm when the phone restarts, so without it your reminders
  would silently stop after a reboot. It lets the app re-register those
  reminders. It does not let the app start itself for any other purpose, and it
  carries no access to your data.

`INTERNET` is actively **removed** from the release manifest, and a check on
the built APK fails the build if it reappears. See
`tools/scripts/assert_no_network.sh`.
