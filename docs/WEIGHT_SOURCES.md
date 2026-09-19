# Body composition and cycle hormones: claims and sources

Every factual claim the app makes in its body-composition reference is listed
here with the source it came from. Nothing appears on that screen that is not in
this file, and `weight_sources_test.dart` fails the build if it does — an
uncited health claim in a health app is the thing this file exists to make
impossible.

## Verification status

Claims are marked **[VERIFY]** until someone has opened the source and checked
that it says what the claim says. This is the same convention `PLAN.md` uses for
the priors figures and `NUTRITION_SOURCES.md` uses for its claims, and it means
the same thing here: the wording is a starting point written from general
knowledge, not a checked quotation, and it is **not yet fit to ship**.

`[VERIFY]` is not decoration. The release checklist in `RELEASE.md` should not
pass while any claim below still carries one.

To clear a marker: open the source, confirm the claim, replace `[VERIFY]` with
`[VERIFIED yyyy-mm-dd, initials]`. If the source does not support the claim,
change the claim — do not clear the marker.

## What this reference is not

It is reference text about a set of mechanisms, shown to someone tracking a
menstrual cycle. It is not advice, not a recommendation to change anything, and
**not addressed to the reader's own body**. `PLAN.md` 6.2 forbids diagnostic
framing, and `weight_copy_test.dart` enforces the vocabulary.

Three rules are stricter here than anywhere else in the app, and they are
stricter on purpose. Weight content in a cycle-tracking app is read by people
for whom the subject is not neutral, and the failure mode is not embarrassment,
it is harm.

1. **The app asks for nothing.** There is no weight entry, no weight log, no
   BMI, and no schema change. Nothing on the screen can be filled in.
2. **No number that could function as a target.** No BMI thresholds, no weight
   ranges, no calorie figures, no "healthy weight". `weight_copy_test.dart`
   fails on a digit anywhere in this section's copy, because the safest number
   of numbers here is none.
3. **No second person at all.** Not "your weight", not "your cycle may be
   affected", not "you should". The section never once addresses the reader's
   body, and the test enforces that as an absolute rather than as a judgement
   call — *"adipose tissue expresses aromatase"* is a statement about
   physiology, *"your body fat is raising your oestrogen"* is a claim about a
   person that nothing in this app could establish.

**Both directions, evenhandedly.** Too little body fat and too much both reach
the cycle, by different routes, and a reference that presents only one of them
is how this subject does damage. E2–E4 and A3 are the claims that keep it
balanced, and neither set may be dropped for brevity.

The register for sources is NHS, NICE, ACOG, the Endocrine Society, the MSD
Manual and StatPearls. Nothing here is cited to a blog, a supplement seller, or
a study summarised at second hand.

---

## Adipose tissue as a site of oestrogen production

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| A1 | Aromatase is the enzyme that converts androgens into oestrogens. | StatPearls, *Biochemistry, Aromatase* | **[VERIFY]** |
| A2 | Adipose tissue (body fat) expresses aromatase, so it is itself a site of oestrogen production outside the ovaries. | MSD Manual (Professional), *Female Reproductive Endocrinology*; StatPearls, *Biochemistry, Aromatase* | **[VERIFY]** |
| A3 | The quantity of adipose tissue is therefore one of the inputs to circulating oestrogen, in both directions: more of it adds to the total, and very little of it removes a source the ovaries do not make up for. | MSD Manual (Professional), *Female Reproductive Endocrinology*; Endocrine Society, *Functional Hypothalamic Amenorrhea* clinical practice guideline | **[VERIFY]** |

A3 is written as a mechanism with two ends on purpose. Stated in one direction
only it becomes an argument, and an argument in this section is the thing the
section is not allowed to be.

---

## Energy availability and GnRH pulsatility

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| E1 | The brain signals the ovaries through a hormone released in regular pulses, and that rhythm is what drives the two pituitary hormones the ovaries answer to. | StatPearls, *Physiology, Gonadotropin-Releasing Hormone* | **[VERIFY]** |
| E2 | When energy availability is low that rhythm is suppressed, the pituitary hormones fall, ovulation stops and menstruation stops with it. This is functional hypothalamic amenorrhoea. | Endocrine Society, *Functional Hypothalamic Amenorrhea: An Endocrine Society Clinical Practice Guideline* | **[VERIFY]** |
| E3 | Energy availability is the energy left over from food once exercise has taken its share, set against what the body needs; it is not a body weight and it is not a reading from a scale. | Endocrine Society, *Functional Hypothalamic Amenorrhea* clinical practice guideline; ACOG Committee Opinion, *Female Athlete Triad* | **[VERIFY]** |
| E4 | This happens to people whose body weight is unremarkable, and heavy training, illness or sustained stress can bring it on with no fall in body weight at all. | Endocrine Society, *Functional Hypothalamic Amenorrhea* clinical practice guideline | **[VERIFY]** |

E3 and E4 are the load-bearing pair. Without them this section reads as a
statement about a number on a scale, which is both wrong and the single most
harmful thing this reference could be mistaken for.

---

## Insulin, SHBG and free androgen

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| S1 | Sex hormone binding globulin (SHBG) is a liver-produced protein that binds testosterone in the blood, so only the unbound fraction is available to tissue. | StatPearls, *Physiology, Sex Hormone Binding Globulin* | **[VERIFY]** |
| S2 | Insulin resistance, and the raised insulin that goes with it, lower SHBG. | Endocrine Society, *Diagnosis and Treatment of Polycystic Ovary Syndrome: An Endocrine Society Clinical Practice Guideline*; MSD Manual (Professional), *Polycystic Ovary Syndrome* | **[VERIFY]** |
| S3 | When SHBG falls the free fraction of testosterone rises, even when total testosterone is unchanged. | StatPearls, *Physiology, Sex Hormone Binding Globulin*; Endocrine Society, *Polycystic Ovary Syndrome* clinical practice guideline | **[VERIFY]** |

---

## PMOS

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| P1 | Polyendocrine metabolic ovarian syndrome (PMOS), formerly polycystic ovary syndrome, is characterised by androgen excess together with irregular or absent ovulation. | ACOG, *Polycystic Ovary Syndrome* (Practice Bulletin); Endocrine Society, *Polycystic Ovary Syndrome* clinical practice guideline | **[VERIFY]** |
| P2 | Insulin resistance is common in PMOS and contributes to the androgen excess. | Endocrine Society, *Polycystic Ovary Syndrome* clinical practice guideline; MSD Manual (Professional), *Polycystic Ovary Syndrome* | **[VERIFY]** |
| P3 | PMOS occurs across the whole weight spectrum, in people who are thin as well as in people who are not. | ACOG, *Polycystic Ovary Syndrome* (Practice Bulletin); Endocrine Society, *Polycystic Ovary Syndrome* clinical practice guideline | **[VERIFY]** |

The sources cited on P1 to P3 predate the rename and are titled *Polycystic
Ovary Syndrome*. That is expected rather than a mismatch: the condition was
renamed to polyendocrine metabolic ovarian syndrome in 2026, by a consensus
process the Endocrine Society took part in, because most people diagnosed with
it do not have ovarian cysts. Anyone verifying these claims should expect the
old name on the page they open, and the app names the old one once so a reader
who knows it can still find themselves in the text.

P3 must be said, and `weight_copy_test.dart` fails if it stops being said. The
opposite impression is widespread and it is false; it is one of the reasons the
condition goes unrecognised, and a reference that named PMOS in a section about
body composition while leaving it out would be actively reinforcing the error.

---

## Thyroid function

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| T1 | Thyroid disease is a recognised cause of menstrual disturbance, affecting cycle length and the amount of bleeding. | MSD Manual (Professional), *Abnormal Uterine Bleeding*; NICE CKS, *Amenorrhoea* | **[VERIFY]** |
| T2 | An underactive thyroid is associated with heavier and more frequent bleeding; an overactive thyroid with lighter, less frequent bleeding or with none. | MSD Manual (Professional), *Hypothyroidism* and *Hyperthyroidism*; StatPearls, *Hypothyroidism* | **[VERIFY]** |
| T3 | Thyroid function is established by a blood test. | NHS, *Underactive thyroid (hypothyroidism)*, diagnosis section | **[VERIFY]** |

T3 does the same job here that "iron deficiency is confirmed by a blood test"
does in `NUTRITION_SOURCES.md`: it says where the answer actually comes from,
and it is not the shape of a cycle.

---

## When a cycle changes

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| C1 | A change in cycle length, in the amount of bleeding, or in whether periods happen at all has many possible causes. | NHS, *Irregular periods*; MSD Manual (Professional), *Abnormal Uterine Bleeding* | **[VERIFY]** |
| C2 | A persistent change in the menstrual cycle is a reason for clinical assessment. | NHS, *Irregular periods*; NHS, *Stopped or missed periods* | **[VERIFY]** |

C1 and C2 are the last thing on the screen for the same reason the nutrition
hint points at a human: everything above them describes mechanisms, and a page
of mechanisms with no exit is an invitation to pick one. Deliberately no
threshold is given — no "three months", no day count. A threshold is a number,
and a number here is something to measure a body against.
