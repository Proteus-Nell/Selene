# Privacy

**This file is the source of the privacy text shown inside the app.** The
sections below are shipped verbatim on the Settings screen, and
`app/test/features/privacy_text_test.dart` fails if the two ever drift apart.
Change the wording here and in `app/lib/l10n/app_en.arb` together.

It is written to be read by the person using the app, not by a lawyer. In
particular it says plainly what is *not* protected. Encryption
([DECISIONS.md ADR-0018](DECISIONS.md#adr-0018-the-database-is-encrypted-with-a-key-the-android-keystore-holds))
protects a copy of the file, not an unlocked phone, and saying less would let
the word "encrypted" do work it has not earned.

---

## What this app does with your data

### We do not collect your information

The app has no internet permission, no account, no analytics, no advertising and no crash reporting, and a check on every release refuses to build one that asks for the internet. Everything you record stays on your phone, under your control, and none of it reaches us.

### It leaves your phone only when you choose

Two things send anything anywhere, and only when you ask. An export saves a backup, or a summary for a doctor, wherever you choose. A web search opens in your browser, after the app tells you exactly which words will be searched, and your browser may keep it in its history.

### The database is encrypted, with a key the phone keeps

Everything you record is kept in the app's private storage, in a database file encrypted with a key held by Android's secure key store. The key never leaves the phone and is not in your exports, so a copy of the file on its own cannot be read. Scheduled reminders are the one exception: until they are due, Android keeps their wording, which can name the predicted dates or a medicine, outside the encrypted file. Encryption does not protect an unlocked phone. Anyone using it can open the app and read what you recorded unless the app lock is on, and someone with full control of the phone, through root access or a forensic tool, may be able to use the key the way the app does.

### Nothing is copied off the phone

Android's cloud backup and device-to-device transfer are switched off for the app, so your records are never copied to a Google account or to a new phone. If you lose the phone, they are gone unless you exported them.

### Deleting really deletes

You can delete a single day, condition or medicine at any time. Delete everything removes every record and reclaims the space, so the deleted entries are not left readable in the file. Uninstalling the app deletes everything it stored on the phone.

### The activity log holds nothing you recorded

The app keeps a short log of what it did, such as "a prediction was computed" with a count of cycles. It stays on the phone, only in memory, so it is cleared when the app stops. You can read it and clear it in Settings.

### Exports are yours to look after

An exported backup is a readable file wherever you save it, unless you protect it with a passphrase when you export it. A protected backup opens only with that passphrase, and nobody can recover a forgotten one. Once a backup is saved, it is under your control and the control of wherever you keep or send it.

---

## Threat model, in one table

| Threat | Covered? |
| --- | --- |
| Network interception or a server breach | Yes, completely. There is no network and no server. |
| Another app on the same device reading the data | Yes on a device that has not been rooted, through the Android app sandbox. |
| Cloud backup exfiltration | Yes. Automatic backup is switched off for this app. |
| Someone picking up your unlocked phone | **If you turn on the app lock, yes.** It is off by default; see below. |
| A copy of the app's files, taken without the phone | **Yes.** The database is encrypted, and its key is held by the phone's secure key store, not in the file. |
| A device seized and forensically imaged, or legal compulsion | **Partly.** Android's device encryption protects a phone that is switched off, and the database is encrypted with a key the phone keeps. A phone that is unlocked, or that a forensic tool can make run code as the app, can still be made to read it — **the app lock does not change this**. |

The last row is the honest limit of this design, recorded rather than hidden.

## The most sensitive thing this app stores

You can optionally record **intercourse, and whether it was protected**. It is
the single most sensitive field in the database, and this section exists so you
know that before you decide whether to use it rather than after.

Three things are true about it:

- **It never leaves your device.** Like everything else here — no account, no
  sync, no analytics — and the app has no internet permission at all. It is
  written into your export file if you make one, because that file is your own
  backup and dropping a field would lose you data you deliberately recorded.
- **It is never used to predict anything.** Not the next period, not a fertile
  window, not a safe day. The prediction model has no way to read the column at
  all, and an automated check fails the build if that ever changes. This is
  assumption A5 in the plan and it is not negotiable.
- **You never have to record it.** Not recording is a different thing from
  recording "no" — the app stores nothing for a day you leave alone, and there
  is no "none" option that would have it say something on your behalf. Tapping
  a recorded answer again clears it.

The calendar shows a small marker on a day where something was recorded, and
never which answer. Screen readers say "intercourse logged" for the same reason:
a calendar is the easiest screen in the app to read over someone's shoulder, and
a screen reader is audible to whoever is in the room.

If you want the app to ask for your fingerprint or PIN before showing anything,
turn on the app lock described below. It is off by default.

## Medicines you record

Conditions and medication can keep a list of the medicines you take, so the app
can flag pairs whose labels connect them. It is optional, and a list like this
can say a great deal: emergency contraception, HIV prevention, antidepressants.

- **It stays on your device.** It is compared with the US labels the app
  carries, on the phone. Nothing is sent anywhere unless you choose "Look it up
  online" for a pair and confirm, and then it is your browser that searches for
  those two names, and keeps them in its history.
- **It is in your exports**, because a backup that dropped it would lose
  something you recorded. "Delete everything" deletes it, and taking the last
  medicine off the list leaves nothing behind.
- **It is never used to predict anything**, the same as conditions.
- **A flag is not advice.** It says that two labels connect, and nothing about
  whether that matters for you. A pharmacist can tell you that.

## Temperature, mucus and progesterone

You can record your basal body temperature, cervical mucus, and progesterone
results, both a home PdG strip and a blood test with its unit. They are
fertility signs, and they are kept the way intercourse is:

- **They are never used to predict anything.** Not the next period, not
  ovulation, not a fertile window. The prediction and cycle code cannot read
  them at all, and an automated check fails the build if that ever changes.
- **They stay on your device**, encrypted with everything else, and they are in
  your exports, because a backup that dropped them would lose something you
  recorded.
- **You never have to record them.** They sit in their own section of the day
  editor, closed until you open it. Leaving one empty records nothing, and
  clearing one takes it back.

## The app lock

You can require your fingerprint, face, PIN or pattern before the app will show
anything. It is **off by default**, it uses the credential your device already
has, and it locks again after a minute in the background.

**It hides the screen. The lock itself does not encrypt anything.**

That sentence is the whole point of this section. The app lock stops someone who
picks up your unlocked phone from reading your diary. The encryption is
separate, and on whether the lock is on or off: it protects a copy of the file,
and the lock protects the screen. Neither stops someone with full control of an
unlocked phone — root access, or a forensic tool — who can use the app's key
the way the app does
([ADR-0018](DECISIONS.md#adr-0018-the-database-is-encrypted-with-a-key-the-android-keystore-holds)).

We say it this plainly because a lock you believe is the encryption is worse
than no lock: it buys a false sense of safety for the price of a few taps. A
sentence saying so appears under the toggle in the app itself.

If your device has no PIN, pattern, password or fingerprint set up, the app has
nothing to ask for and the setting will tell you so rather than failing quietly.
The fix is in your device's own settings.

## Permissions this app asks for

Three, and nothing else:

- **`POST_NOTIFICATIONS`** — the runtime prompt, asked for after you have
  logged a cycle, or when you set a medicine reminder, whichever comes first.
  Decline it and everything else still works. The app does not raise it again
  on its own. Setting another medicine reminder asks again, until Android
  stops showing the prompt, which it does once it has been declined twice.
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
