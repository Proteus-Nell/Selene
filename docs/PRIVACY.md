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
| Someone picking up your unlocked phone | **If you turn on the app lock, yes.** It is off by default; see below. |
| A device seized and forensically imaged, or legal compulsion | **Partly.** Android's full-device encryption protects a phone that is switched off. Once unlocked, the database is plain text — **the app lock does not change this**. |

The last row is the honest limit of this design, recorded rather than hidden.

## The app lock

You can require your fingerprint, face, PIN or pattern before the app will show
anything. It is **off by default**, it uses the credential your device already
has, and it locks again after a minute in the background.

**It hides the screen. It does not encrypt your data.**

That sentence is the whole point of this section. The app lock stops someone who
picks up your unlocked phone from reading your diary. It does nothing at all
against anyone who can read the file itself — someone with your unlocked phone
plugged into a computer with developer options on, anyone with root, or a
forensic tool. The database is stored unencrypted in the app's private storage
whether the lock is on or off, exactly as
[ADR-0004](DECISIONS.md#adr-0004-unencrypted-local-sqlite-with-zero-network-permission)
describes, and turning the lock on changes nothing about that.

We say it this plainly because a lock you believe is encryption is worse than no
lock: it buys a false sense of safety for the price of a few taps. The same
sentence appears under the toggle in the app itself.

If your device has no PIN, pattern, password or fingerprint set up, the app has
nothing to ask for and the setting will tell you so rather than failing quietly.
The fix is in your device's own settings.

## Permissions this app asks for

Three, and nothing else:

- **`POST_NOTIFICATIONS`** — the runtime prompt, asked once, and only after you
  have logged a cycle. Decline it and everything else still works.
- **`RECEIVE_BOOT_COMPLETED`** — granted at install with no prompt, so it is
  easy to miss when reviewing the app. It exists for one reason: Android drops
  every scheduled alarm when the phone restarts, so without it your reminders
  would silently stop after a reboot. It lets the app re-register those
  reminders. It does not let the app start itself for any other purpose, and it
  carries no access to your data.
- **`USE_BIOMETRIC`** — granted at install with no prompt. It lets the app show
  the system's own unlock prompt for the app lock described above. It gives the
  app no access to your fingerprint or face data: Android does the matching and
  tells the app only yes or no. If you leave the app lock off, it is never used.

`INTERNET` is actively **removed** from the release manifest, and a check on
the built APK fails the build if it reappears. See
`tools/scripts/assert_no_network.sh`.
