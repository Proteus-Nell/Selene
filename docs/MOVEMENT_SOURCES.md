# Pain and movement across the cycle: claims and sources

Every factual claim the app makes in its pain-and-movement reference is listed
here with the source it came from. Nothing appears on that screen that is not in
this file, and `movement_sources_test.dart` fails the build if it does — an
uncited health claim in a health app is the thing this file exists to make
impossible.

## Verification status

Claims are marked **[VERIFY]** until someone has opened the source and checked
that it says what the claim says. This is the same convention `PLAN.md` uses for
the priors figures and that `NUTRITION_SOURCES.md` and `WEIGHT_SOURCES.md` use
for theirs, and it means the same thing here: the wording is a starting point
written from general knowledge, not a checked quotation, and it is **not yet fit
to ship**.

`[VERIFY]` is not decoration. The release checklist in `RELEASE.md` should not
pass while any claim below still carries one.

To clear a marker: open the source, confirm the claim, replace `[VERIFY]` with
`[VERIFIED yyyy-mm-dd, initials]`. If the source does not support the claim,
change the claim — do not clear the marker.

Three of the claims below (E2, E3, M3) are **absence claims**: they say that a
named body does *not* say something. An absence claim is verified the same way
as any other — by reading the source — but the reading is different work, and it
is worth knowing before starting it. Confirming E2 means reading the physical
activity guidance and the dysmenorrhoea guidance and finding no phase-based
recommendation in either. Finding one falsifies the claim, and the claim is then
what changes.

## What this reference is not

It is reference text about period pain, about what movement does and does not do
about it, and about how much of the popular advice on the subject is actually
supported. It is not advice, not a plan, not an exercise prescription, and **not
addressed to the reader's own body**. `PLAN.md` 6.2 forbids diagnostic framing,
and `movement_copy_test.dart` enforces the vocabulary.

Three rules are stricter here than in most of the app, and they are stricter on
purpose. This is the subject on which a cycle app is most likely to be believed
and most likely to be wrong, because the popular version of it is confident,
tidy, and not supported by the evidence.

1. **No prescription.** No sets, no repetitions, no intensities, no durations,
   no schedule, no rest days, no phase-by-phase plan. There is nothing on the
   screen to follow, and `movement_copy_test.dart` fails on the vocabulary of
   one.
2. **No number that could function as a target.** `movement_copy_test.dart`
   fails on a digit anywhere in this section's copy, for the reason
   `WEIGHT_SOURCES.md` gives and one more of its own: a threshold here would be
   either a training figure or a pain score, and the section is not allowed to
   hand out either.
3. **No second person at all.** Not "your period", not "you should rest", and
   specifically not *"listen to your body"* — which is the friendliest sentence
   in this whole subject area and is still an instruction addressed to a reader
   this app cannot see. The rule is absolute over every `movement*` string, as
   it is over every `weight*` one, because every softer version is a judgement
   call about whether *this* "you" is about the reader, and that judgement is
   what a hurried edit gets wrong.

### The claim this section was asked to make, and does not

This reference was requested as *"avoid exercising during menstruation, doing so
when follicular"*. It does not say that, and no edit should put it back.

A blanket instruction to avoid exercise during a period is not supported by any
source in the register below. The direction of the evidence runs the other way:
exercise is among the better-evidenced things for menstrual cramps (M2), and
clinical guidance on period pain lists it among the measures that may help
rather than among things to stop (M1). Writing the requested version would have
told people to stop doing a thing that helps them, on the authority of an app
that cannot see them.

What genuinely varies across a cycle is **how movement feels** — pain, tiredness,
and how hard a given effort seems on the day (F1, F2). That is a description,
not a permission system. The honest line is that resting is allowed, and it is
written as a permission rather than as an instruction, because an instruction to
rest is the same category error as an instruction to train, only kinder.

**Both directions, evenhandedly.** The section must not read as an argument for
exercising during a period any more than as an argument against it. S1 and S2
are the claims that keep it balanced: some things really are reasons to stop,
and one of them has a mechanism that runs straight through this app's own
subject matter.

The register for sources is NHS, NICE, ACOG, Cochrane, the Endocrine Society,
the MSD Manual and StatPearls. One claim (E1) is cited outside it, and the
reason is given at that claim.

---

## Period pain itself

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| P1 | Primary dysmenorrhoea is painful menstruation with no underlying pelvic disorder. The pain is typically cramping, felt in the lower abdomen, starting around the onset of bleeding and easing over the following days. | NHS, *Period pain*; MSD Manual (Professional), *Dysmenorrhea*; StatPearls, *Dysmenorrhea* | **[VERIFY]** |
| P2 | Prostaglandins released from the endometrium drive the uterine contractions that produce the cramping pain of primary dysmenorrhoea. | StatPearls, *Dysmenorrhea*; MSD Manual (Professional), *Dysmenorrhea* | **[VERIFY]** |
| P3 | Secondary dysmenorrhoea is period pain with an identifiable underlying cause; endometriosis, adenomyosis and uterine fibroids are among the recognised ones. | NICE CKS, *Dysmenorrhoea*; MSD Manual (Professional), *Dysmenorrhea* | **[VERIFY]** |

---

## Movement during menstruation

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| M3 | General physical activity guidance makes no exception for the days of a menstrual period, and menstruation is not listed anywhere in the register as a reason to stop exercising. | NHS, *Physical activity guidelines for adults aged 19 to 64*; NHS, *Period pain*; NICE CKS, *Dysmenorrhoea* | **[VERIFY]** *(absence claim)* |

M3 is now the whole of this section, and that is deliberate. The two claims
that used to sit beside it said that guidance lists exercise among the measures
that may help with period pain, and that a Cochrane review found it may reduce
how intense the pain is on low-quality evidence. Both were dropped at the
owner's direction.

What survives is an absence claim and nothing more: no source in the register
names menstruation as a reason to stop. It does not say anyone should exercise,
and with M1 and M2 gone the section no longer says exercise helps. That is a
narrower page than it was, and the narrower reading is the one it now supports.

---

## What varies is the experience

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| F1 | Tiredness and low energy are among the commonly reported symptoms in the days before and during menstruation. | NHS, *Premenstrual syndrome (PMS)*; MSD Manual (Professional), *Premenstrual Syndrome* | **[VERIFY]** |
| F2 | Symptoms around menstruation vary widely between people, and between one cycle and the next in the same person. | NHS, *Premenstrual syndrome (PMS)*; MSD Manual (Professional), *Premenstrual Syndrome* | **[VERIFY]** |

F1 and F2 are the load-bearing pair for the framing of the whole section. They
are what make "how it feels" the variable rather than "what is permitted", and
F2 in particular is why nothing here can be turned into a rule: a claim that
holds on average across a population, applied to one person on one day, is a
guess wearing a citation.

The statement that resting is a reasonable choice carries no claim number and no
source, deliberately. It is not a finding about bodies. It is this app declining
to have an opinion about how a day is spent, and a citation attached to it would
be a way of making it sound like one.

---

## Signals to stop

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| S1 | Feeling faint or light-headed during exertion, breathlessness out of proportion to the effort, and chest pain are reasons to stop and to seek medical assessment rather than to continue. | NHS, *Chest pain*; NHS, *Dizziness (lightheadedness)*; NHS, *Shortness of breath* | **[VERIFY]** |
| S2 | Heavy menstrual bleeding is a recognised cause of iron deficiency anaemia in people who menstruate. | NICE guideline NG88, *Heavy menstrual bleeding: assessment and management* | **[VERIFY]** |
| S3 | Commonly listed symptoms of iron deficiency anaemia include tiredness, lack of energy and shortness of breath. | NHS, *Iron deficiency anaemia*, symptoms section | **[VERIFY]** |
| S4 | Iron deficiency is confirmed by a blood test, not by symptoms. | NHS, *Iron deficiency anaemia*, diagnosis section | **[VERIFY]** |

### S2, S3 and S4 are shared claims, not new ones

**S2 is the same claim as I3 in `docs/NUTRITION_SOURCES.md`, S4 is the same
claim as I5, and S3 is I4 plus one more symptom from the same NHS page.** They
are attributed here exactly as they are attributed there — S2 to NICE NG88, S3
and S4 to the NHS iron deficiency anaemia article — so that the two references
cannot drift into citing the same fact to different places, or into saying
different things about it.

`movement_sources_test.dart` asserts that `NUTRITION_SOURCES.md` still carries
the iron and anaemia link, so that deleting it there cannot leave this section
resting on a citation that no longer exists. It is a cross-reference rather than
a copy: the nutrition file remains where the iron claims are explained, and this
one borrows exactly the part that explains why exertion can feel harder around a
heavy period.

I4 lists tiredness and lack of energy. The breathlessness half of S3 is what
this section adds, and it is the half that matters here — breathlessness during
effort is the symptom most likely to be read on a hard day as a verdict on the
cycle, when it has an ordinary explanation that a blood test can settle.

That explanation is the whole reason this section exists in the form it does.
Exertion feeling harder during or after heavy periods is not evidence that a
cycle makes exercise unwise. Following S2 and S3, it has a recognised cause that
points at a clinician and a blood test, and S4 is what stops that pointing from
becoming a conclusion: nothing in this app can establish iron deficiency, and
neither can the way a day felt.

---

## Planning exercise around cycle phase

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| E1 | Systematic review of menstrual cycle phase and exercise performance reports low-quality evidence, average effects that are trivial, and variation between individuals larger than the effect under study. | McNulty et al., *The Effects of Menstrual Cycle Phase on Exercise Performance in Eumenorrheic Women: A Systematic Review and Meta-Analysis*, Sports Medicine | **[VERIFY]** |
| E2 | No guidance from NHS, NICE or ACOG recommends planning exercise around menstrual cycle phase. | NHS, *Physical activity guidelines for adults aged 19 to 64*; NICE CKS, *Dysmenorrhoea*; ACOG, patient guidance on exercise and fitness | **[VERIFY]** *(absence claim)* |
| E3 | No guidance from NHS, NICE or ACOG states that the chance of injury rises or falls with menstrual cycle phase. | NHS, *Physical activity guidelines for adults aged 19 to 64*; ACOG, patient guidance on exercise and fitness | **[VERIFY]** *(absence claim)* |
| H1 | Combined hormonal contraception works by stopping ovulation. The rise and fall of oestrogen and progesterone that a phase-based scheme assumes is therefore not occurring, so the scheme has nothing underneath it. | MSD Manual (Professional), *Contraception*; StatPearls, *Combined Oral Contraceptive Pills*; NHS, *Combined pill* | **[VERIFY]** |

**E1 is cited outside the register, and this is the only claim that is.** No body
in the register has published on whether exercise should be programmed by cycle
phase, which is itself the point E2 and E3 make. Citing the systematic review
that has looked is more honest than the two alternatives: attributing a
conclusion about training to NICE, which has not drawn one, or saying nothing
and leaving a claim that is loudly promoted everywhere else unanswered on the
one screen in this app that is about it. Whoever clears its `[VERIFY]` should
check the review's own stated conclusion rather than a summary of it, because
the summary that circulates is stronger than the paper.

H1 is here rather than in the contraception copy because it is the argument's
last step, not a fact about contraception. A phase-based scheme applied to a
suppressed cycle is a scheme applied to phases that are not occurring, and a
great many readers of this app are in exactly that position — the condition list
this app already carries names four hormonal methods.

**No plan is built out of E1.** A reference that hands someone a prescription
built on weak evidence is worse than one that says the evidence is weak, because
the prescription survives being wrong and the caveat does not.

---

## When pain is a reason to see someone

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| C1 | Period pain that is severe, that is getting worse, that is not eased by the usual measures, or that interferes with everyday activities is a reason for clinical assessment. | NHS, *Period pain*, when to see a GP; NICE CKS, *Dysmenorrhoea* | **[VERIFY]** |
| C2 | Period pain that begins later in life, changes in character, or occurs with other symptoms may indicate an underlying cause and is a reason for assessment. | NICE guideline NG73, *Endometriosis: diagnosis and management*; NICE CKS, *Dysmenorrhoea* | **[VERIFY]** |

C1 and C2 close the screen for the reason `WEIGHT_SOURCES.md` gives: a page of
mechanisms with no exit is an invitation to pick one. **Deliberately no
threshold and deliberately no scale.** A pain score is a number, and this
section is not allowed to hand a reader a number to measure themselves against
any more than the body-composition one is. "Severe", "getting worse" and "gets
in the way of ordinary days" are the words the sources use, and they are the
words that survive being read by somebody having a bad month.
