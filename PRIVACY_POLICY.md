# Privacy Policy

**Last updated:** 27 October 2026\
**Effective as of:** 27 October 2026

Selene ("**Selene**", "**we**", "**us**" or "**our**") is a menstrual cycle tracker for Android, developed as an open-source project by [Proteus-Nell](https://github.com/Proteus-Nell). This Privacy Policy describes how Selene handles personal information when you use the Selene app or visit [this repository](https://github.com/Proteus-Nell/Selene) (together, the "**Service**").

**The short version: we do not collect any personal information.** The app has no internet permission, no account, no analytics, no advertising and no crash reporting. Everything you record stays on your phone, under your control, and none of it reaches us.

This policy keeps the sections of a standard privacy policy, so that you can check each kind of collection such a policy usually describes and see what Selene does instead.

**Notice to European users:** see the [Notice to European users](#notice-to-european-users) section below for information for individuals in the European Economic Area or the United Kingdom ("**Europe**").

**Notice to residents of U.S. states:** see the [State privacy rights notice](#state-privacy-rights-notice) section below.

**Index**

- [Personal information we collect](#personal-information-we-collect)
- [Tracking and other technologies](#tracking-and-other-technologies)
- [How we use your personal information](#how-we-use-your-personal-information)
- [Retention](#retention)
- [How we share your personal information](#how-we-share-your-personal-information)
- [Your choices](#your-choices)
- [Other sites and services](#other-sites-and-services)
- [Security](#security)
- [International data transfer](#international-data-transfer)
- [Children](#children)
- [Changes to this Privacy Policy](#changes-to-this-privacy-policy)
- [How to contact us](#how-to-contact-us)
- [State privacy rights notice](#state-privacy-rights-notice)
- [Notice to European users](#notice-to-european-users)

## Personal information we collect

### Information you provide to us

We do not collect the information you record in the app. It is stored in a database in the app's private storage on your phone, and it is never sent to us or to anyone else. Depending on what you choose to record, it can include:

- **Cycle data**, such as the days you log, your flow, and your symptoms with how severe they were.
- **Intimate activity data**, only if you choose to record it: whether you had sex on a given day, and whether it was protected.
- **Health condition data**, such as PMOS (formerly PCOS), endometriosis, pregnancy or hormonal contraception, with the dates each one applied.
- **Medication data**, such as the medicines you record under Conditions and medication.
- **Fertility signs**, only if you choose to record them: your basal body temperature, cervical mucus, and progesterone test results. They are kept as a record and never used to predict anything.
- **Preferences**, such as your reminder, appearance and app lock settings.

### Third-party sources

We do not receive personal information about you from anyone else.

### Automatic data collection

The app does not collect anything about you, your phone or how you use it: no device or advertising identifiers, IP address, location, usage statistics or crash reports. The app has no internet permission, so it has no way to send anything, and a check on every release refuses to build one that asks for it.

The app keeps a short log of what it did, such as "a prediction was computed" with a count of cycles. The log holds nothing you recorded and stays on the phone. It is kept only in memory, so it is cleared when the app stops. You can read it and clear it in Settings.

The app also includes US drug labelling from openFDA, which is copied into the app when it is built. Looking up a medicine reads that copy and sends nothing anywhere.

## Tracking and other technologies

Selene uses no cookies, tracking pixels, advertising or analytics tools, or chat and artificial intelligence services.

## How we use your personal information

We do not use your personal information, because we never receive it.

On your phone, the app uses what you record to:

- show your calendar, history and insights;
- predict your next period, using a model that runs on the phone;
- show the reminders you turn on, as notifications created by the phone itself;
- compare the medicines you record, using the labelling built into the app.

None of this involves us. We do not use your information for marketing, advertising, analytics, research or training artificial intelligence models, and we do not create aggregated or de-identified data from it.

## Retention

We retain no personal information, because we hold none.

On your phone, what you record stays until you delete it:

- You can delete a single day, condition or medicine at any time.
- **Delete everything**, in Settings, removes every record and reclaims the space, so the deleted entries are not left readable in the file.
- Uninstalling the app deletes everything it stored on the phone.

A backup file you export stays wherever you saved it until you delete it.

## How we share your personal information

We do not sell, share or disclose your personal information, because we never have it. Information leaves your phone only when you choose to send it:

- **Exports.** You can export a backup file, saved wherever you choose. It is a readable file unless you protect it with a passphrase when you export it, and then it opens only with that passphrase. Once it is saved, it is under your control and the control of wherever you keep or send it.
- **Searching online.** Some screens offer to search the web for you: "Look it up online" for two medicines, for example. Before anything happens, the app tells you exactly which words will be searched. If you confirm, it opens your web browser at a [DuckDuckGo](https://duckduckgo.com/privacy) search. That request is made by your browser, not by the app, and is covered by the privacy policies of your browser and of DuckDuckGo. Your browser may keep the search in its history.

## Your choices

All of these are available in the app itself, because your information is there and nowhere else.

- **Access or update your information.** Everything you record can be seen and changed in the app.
- **Export your information.** You can export everything you recorded as a readable file, from Settings, and protect it with a passphrase if you choose.
- **Delete your information.** You can delete single entries, delete everything from Settings, or uninstall the app.
- **Notifications.** Reminders are optional. The app asks for permission to send notifications once, and only after you have logged a cycle. Detail on the lock screen is off by default.
- **App lock.** You can make the app ask for your fingerprint, face, PIN or pattern before showing anything. The lock hides the screen. The encryption described under Security is separate, and is on whether the lock is on or off.
- **Optional information.** You decide what to record. Intimate activity, fertility signs, conditions and medicines can all be left out entirely.
- **Do Not Track and Global Privacy Control.** Selene does not track you, so there is nothing for these signals to switch off.

## Other sites and services

The app can open web searches in your browser, as described above, and this repository is hosted on GitHub. If you download Selene from GitHub or any other website, that website's own privacy policy applies to the download. We do not control third-party websites or services, and we encourage you to read their privacy policies.

## Security

- The database is kept in the app's private storage. On a phone that has not been tampered with, other apps cannot read it.
- The database is encrypted, with a key held by Android's secure key store. The key never leaves the phone and is not in your exports, so a copy of the file on its own cannot be read.
- Android's device encryption also protects the phone while it is switched off.
- **Encryption does not protect an unlocked phone.** Anyone using it can open the app and read what you recorded unless the app lock is on, and someone with full control of the phone, through root access or a forensic tool, may be able to use the key the way the app does.
- Scheduled reminders are kept by Android outside the encrypted file until they are due, and their wording can name the predicted dates.
- Android's cloud backup and device-to-device transfer are switched off for the app, so your records are never copied to a Google account or to a new phone.
- An exported backup is a readable file wherever you save it, unless you protect it with a passphrase when you export it. A protected backup opens only with that passphrase, and nobody can recover a forgotten one.

[`docs/PRIVACY.md`](docs/PRIVACY.md) describes these protections and their limits in more detail.

## International data transfer

We do not transfer personal information anywhere, because we never receive it. What you record stays on your phone, wherever you are.

## Children

We do not collect personal information from anyone, including children. Because nothing reaches us, there is nothing for us to delete. A parent or guardian can delete everything from within the app.

## Changes to this Privacy Policy

We may change this Privacy Policy, for example when the app gains a feature. When we do, we will update the date at the top of this page. Every earlier version stays in this repository's history.

## How to contact us

If you have questions about this Privacy Policy or about Selene's privacy, open an issue at <https://github.com/Proteus-Nell/Selene/issues>. Issues are public, so please do not include anything you have recorded in the app.

## State privacy rights notice

This section applies to residents of U.S. states whose privacy laws give their residents the rights described below (the "**State Privacy Laws**"). "**Personal Information**" and "**Sensitive Personal Information**" have the meanings those laws give them.

**We do not collect Personal Information.** In particular:

- We do not sell Personal Information or share it for targeted advertising.
- We do not process Personal Information for targeted advertising, profiling, or automated decisions with legal or similarly significant effects.
- **Sensitive Personal Information.** The app lets you record information about your health and sex life. That information stays on your phone. We do not collect or process it, and we do not use it to infer characteristics about you.
- **Consumer health data.** We do not collect, share or sell consumer health data as defined by Washington's My Health My Data Act and similar state laws.
- **Consumers under 16.** We do not collect, sell or share the Personal Information of anyone, including consumers under 16.

**Your privacy rights.** The State Privacy Laws may give you the right to know what Personal Information we hold, and to access, correct and delete it. You may also have the right to opt out of its sale, of targeted advertising and of profiling, and to appeal a decision about your request. We hold no Personal Information about you, so a request to us will be answered with that. You can see, correct, export and delete everything you recorded directly in the app, as described in [Your choices](#your-choices). You will not be discriminated against for exercising any of these rights.

**Information practices.** The following describes our practices now and during the past 12 months:

| Personal Information ("PI") we collect | CCPA statutory category | Purposes | Categories of third parties to whom we "disclose" PI for a business purpose | Categories of third parties to whom we "sell" or "share" PI |
| --- | --- | --- | --- | --- |
| None | None | None | None | None |

**California's Shine the Light law.** We do not disclose personal information to third parties for their direct marketing purposes.

**Nevada and Texas residents.** We do not sell personal information or sensitive personal data.

## Notice to European users

**Where this notice applies.** This section applies only to individuals in the United Kingdom and the European Economic Area ("Europe", as defined at the top of this Privacy Policy). References to "personal information" in this Privacy Policy include "personal data" as defined in the EU General Data Protection Regulation and the UK GDPR (together, the "**GDPR**").

**Controller.** Selene stores what you record on your own phone and never sends it to us, so we do not process your personal data and are not its controller. The data on your phone is under your control.

**Representatives and Data Protection Officer.** We have not appointed a representative in the EU or the UK, or a Data Protection Officer, because we do not process the personal data of people in Europe.

**Legal bases for processing.** The GDPR requires a legal basis for each use of personal data. We do not use your personal data, so no legal basis applies:

| Purpose | Categories of personal information involved | Legal basis |
| --- | --- | --- |
| None. We do not process personal data. | None | Not applicable |

**Health and sex life data.** The GDPR treats data about your health and sex life as special category data. The app records such data only on your phone, and we never receive it.

**Retention.** We retain no personal data. See [Retention](#retention) for how long what you record stays on your phone.

**No automated decision-making or profiling.** We do not engage in automated decision-making or profiling with legal or similarly significant effects. The app's predictions are computed on your phone, from your own records, and never reach us.

**Your rights.** The GDPR gives you rights over your personal data:

1. **Access.** See what is held about you.
2. **Correct.** Correct anything inaccurate.
3. **Delete.** Have it deleted.
4. **Transfer.** Get a machine-readable copy for yourself or someone else.
5. **Restrict.** Limit how it is processed.
6. **Object.** Object to processing based on legitimate interests or for direct marketing.
7. **Withdraw consent.** Withdraw consent you gave, at any time.

We hold no personal data about you, so you exercise these rights directly in the app. You can see and correct everything you recorded, export it as a machine-readable file, and delete some or all of it (see [Your choices](#your-choices)). A request to us will be answered that we hold no personal data about you.

**Your right to lodge a complaint with your supervisory authority.** If you are not satisfied with our response to a request, or with how we handle personal data, you can complain to the data protection regulator where you usually live.

- **European Economic Area:** the contact details for your regulator are listed by the European Data Protection Board at <https://www.edpb.europa.eu/about-edpb/about-edpb/members_en>.
- **United Kingdom:** the Information Commissioner's Office, Wycliffe House, Water Lane, Wilmslow, Cheshire SK9 5AF. Telephone +44 303 123 1113. Website <https://ico.org.uk>.

**Data processing outside Europe.** We do not receive your personal data, so we do not transfer it outside Europe.

---

This Privacy Policy is adapted from the [Privacy Policy (GDPR Enhanced)](https://github.com/General-Legal/legal-templates/tree/main/templates/privacy-policy-gdpr) template, released under [CC0 1.0](https://github.com/General-Legal/legal-templates/blob/main/LICENSE). General Legal's notice for the template follows.

This template was prepared and made publicly available by General Legal, PC ("General Legal"). It is provided for general reference purposes only and does not constitute, and should not be construed as, legal advice, or an endorsement or review of any particular transaction in which it is used. Use of this template does not create an attorney-client relationship with General Legal. General Legal has not reviewed, and takes no position on, any modifications made to this document or the deal terms it is used to document.
