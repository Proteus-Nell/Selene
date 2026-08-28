# The companion: what it can say, and where the claims come from

The companion is the small crescent at the end of the navigation bar. Tapping
it shows one sentence. It has a **finite, written vocabulary** — thirteen lines,
enumerated in `app/lib/features/companion/companion_lines.dart` and written out
in full in `app/test/features/companion_lines_test.dart` — and it chooses among
them by walking an ordered list of conditions over the user's own data. There is
no network permission, there is no model on the device, and nothing is ever
composed at runtime. It never writes a sentence; it picks one.

Five of those lines say something about bodies. Those are listed here with the
source they came from, and `companion_sources_test.dart` fails the build if a
line claims something this file does not cover. **The other eight make no health
claim at all**, and they are listed here too, in "The lines that carry no claim",
with the reason. That section is not padding: an uncited line and an uncitable
line look identical from the outside, and the only way to tell a deliberate
omission from a forgotten one is to write the distinction down.

## Verification status

Claims are marked **[VERIFY]** until someone has opened the source and checked
that it says what the claim says. Same convention as `NUTRITION_SOURCES.md`,
`HYGIENE_SOURCES.md`, `WEIGHT_SOURCES.md` and `MOVEMENT_SOURCES.md`, and it
means the same thing here: the wording is a starting point written from general
knowledge, not a checked quotation, and it is **not yet fit to ship**.

`[VERIFY]` is not decoration. The release checklist in `RELEASE.md` should not
pass while any claim below still carries one.

To clear a marker: open the source, confirm the claim, replace `[VERIFY]` with
`[VERIFIED yyyy-mm-dd, initials]`. If the source does not support the claim,
change the claim — do not clear the marker.

One claim below (M1) is an **absence claim**: it says that no source in the
register names something. It is verified the same way as any other, by reading
the source, but the reading is different work — confirming M1 means reading the
physical activity guidance and the period pain guidance and finding no
instruction to stop. Finding one falsifies the claim, and the claim is then what
changes.

## What the companion is not

It is not a diagnosis, not advice, and not an interpretation of anybody's cycle.
Every claim-bearing line has the same shape: **a statement about what was
logged, followed by a general statement about bodies with a source under it.**
The first half is arithmetic on the user's own entries. The second half is true
of people in general and is never asserted about the person holding the phone.

That shape is the whole safety argument, and it is worth being explicit about
where it could fail. The *trigger* is personal — the cramps line appears because
cramps were logged today — and it would be very easy for a reader to hear the
general half as being about them. Three things keep it from becoming that:

1. **No second person, anywhere in the companion's copy.** Not "your cramps",
   not "how you are feeling". `companion_copy_test.dart` fails on `you`, `your`
   and every inflection, as an absolute, for the reason `WEIGHT_SOURCES.md`
   gives: the judgement call about whether *this* "you" is a claim about the
   reader is exactly what a hurried edit gets wrong.
2. **No digit.** A number in a line like these would be a streak, a count of
   days, or a score to be measured against. There is no fourth kind of number a
   companion could want.
3. **Every claim points somewhere a person can go.** The iron line names the
   blood test rather than leaving a symptom to be read as a result.

And two things it may never do, from `docs/PLAN.md` 6.3, enforced in
`companion_copy_test.dart` over the whole ARB rather than only over this
feature: it never guesses at pregnancy, pregnancy loss or sexual activity, and
it never congratulates anybody for logging. **A missed period is a data state.**
The line for one says so in those words and says nothing else, because there is
nothing else this app could honestly add.

The register for sources is the app's existing one: NHS, NICE, ACOG, Cochrane,
the Endocrine Society, the MSD Manual and StatPearls. Every claim below is
inside it — unlike `MOVEMENT_SOURCES.md`, which had to reach outside it once,
this file has no such case, because none of these claims is about a subject the
register has declined to publish on.

---

## Period pain and movement

| # | Line | Claim | Source | Status |
| --- | --- | --- | --- | --- |
| P1 | `companionLineCramps` | Clinical guidance on period pain lists heat applied to the abdomen, over-the-counter painkillers and exercise among the self-help measures that may help with it. | NHS, *Period pain*, self-help section; NICE CKS, *Dysmenorrhoea* | **[VERIFY]** |
| M1 | `companionLinePeriodToday` | General physical activity guidance makes no exception for the days of a menstrual period, and menstruation is not named anywhere in the register as a reason to stop exercising or to stop moving. | NHS, *Physical activity guidelines for adults aged 19 to 64*; NHS, *Period pain*; NICE CKS, *Dysmenorrhoea* | **[VERIFY]** *(absence claim)* |

**P1 is a report of what guidance lists, not an instruction to do any of it.**
The distinction is the same one `MOVEMENT_SOURCES.md` draws and it is load
bearing here too: this app records no exercise, asks for none, and has no basis
for telling anyone to apply heat or take a painkiller. What it can honestly say
is what the guidance says. The exercise third of P1 **is the same claim as M1 in
`docs/MOVEMENT_SOURCES.md`** and is attributed identically; the heat and
painkiller thirds are new here and come from the same NHS page.

**M1 is the same claim as M3 in `docs/MOVEMENT_SOURCES.md`**, borrowed rather
than re-derived and attributed to the same sources, so the two files cannot
drift into saying different things about it. It is the claim that lets the
companion say something on a period day without telling anybody what to do:
it does not say anyone should move, it says nothing in the register tells anyone
to stop. `companion_sources_test.dart` asserts M3 still exists in the movement
file, so deleting it there cannot leave this line resting on a citation that no
longer exists.

Note what is deliberately **not** here: nothing about which days are better for
which kind of movement, and no Cochrane effect size. The first is the
phase-based scheme `MOVEMENT_SOURCES.md` E1 to E3 exist to refuse, and the
second is a claim with enough shape to it that a one-sentence version would
overstate it. A companion line has room for a fact, not for a caveat, so it gets
the facts that survive being said briefly.

---

## Symptoms commonly reported around a period

| # | Line | Claim | Source | Status |
| --- | --- | --- | --- | --- |
| S1 | `companionLineSleep` | Sleep problems are among the commonly reported symptoms of premenstrual syndrome. | NHS, *Premenstrual syndrome (PMS)*; MSD Manual (Professional), *Premenstrual Syndrome* | **[VERIFY]** |
| S2 | `companionLineLowEnergy` | Tiredness and low energy are among the commonly reported symptoms in the days before and during menstruation. | NHS, *Premenstrual syndrome (PMS)*; MSD Manual (Professional), *Premenstrual Syndrome* | **[VERIFY]** |

**S2 is the same claim as F1 in `docs/MOVEMENT_SOURCES.md`**, and S1 is the same
NHS list read one line further down.

Both are stated as *commonly reported*, and the wording is the claim rather than
a hedge in front of it. "Sleep problems are among the symptoms commonly reported
around a period" is supportable. "Your sleep is disturbed because of your cycle"
is a causal claim about one person on one night, and nothing in this app — which
sees a tick in a box and nothing else — could establish it. The companion says
the first and is forbidden by its own second-person rule from saying the second.

There is deliberately **no line about mood**, although mood, irritability,
anxiety and low mood are all in the symptom catalogue and all appear on the same
NHS list. A sentence from a character, addressed to somebody who has just
recorded low mood, is the single most likely place in this app for warmth to
turn into presumption, and there is no version of it that is worth the risk of
getting it wrong. The omission is recorded here so that nobody adds one by
accident, thinking it was overlooked.

---

## Heavy bleeding and iron

| # | Line | Claim | Source | Status |
| --- | --- | --- | --- | --- |
| I1 | `companionLineHeavyBleeding` | Heavy menstrual bleeding is a recognised cause of iron deficiency anaemia in people who menstruate. | NICE guideline NG88, *Heavy menstrual bleeding: assessment and management* | **[VERIFY]** |
| I2 | `companionLineHeavyBleeding` | Iron deficiency is confirmed by a blood test, not by symptoms. | NHS, *Iron deficiency anaemia*, diagnosis section | **[VERIFY]** |

**I1 and I2 are shared claims, not new ones.** I1 is I3 in
`docs/NUTRITION_SOURCES.md` and S2 in `docs/MOVEMENT_SOURCES.md`; I2 is I5 and
S4 in the same two files. They are attributed here exactly as they are
attributed there, and `companion_sources_test.dart` fails if either disappears
from the nutrition file, which is where the iron claims are explained at length.

**I2 is not a caveat, it is half the claim.** The line pairs them in one
sentence on purpose: heavy bleeding is a recognised cause of iron deficiency
anaemia, *and* a blood test rather than a symptom is what settles it. Without
the second half, a line that appears because heavy flow was logged reads as the
app forming an opinion — which is exactly what `nutrition_copy_test.dart` was
written to make impossible, and the guard it enforces (no `you`, no `your`, no
"you are low in", in any string that names a nutrient) applies to this line as
it applies to everything else.

The trigger is several heavy days inside a month rather than one. One heavy day
is an ordinary period, and a line that fires every cycle is a line the user
learns to dismiss without reading, which costs them the one time it mattered —
the same argument, and the same figure, as `NutritionHints.minCoincidences`.

---

## The lines that carry no claim

Eight of the thirteen lines say nothing about bodies at all, and they are not
cited because there is nothing to cite. Listing them is the point: an omission
that is not written down is indistinguishable from an oversight.

| ARB key | What it says | Why it needs no source |
| --- | --- | --- |
| `companionLineStillReading` | The log has not finished loading. | A statement about this app's own state, one frame long. |
| `companionLinePredictionPaused` | A recorded pregnancy has paused predictions. | Restates a condition the user entered themselves and a behaviour the app already has (ADR-0010, `PredictionResult.suppressedByCondition`). It infers nothing: the user told it. |
| `companionLineOverdue` | The predicted window has passed with no period logged. | Arithmetic on a date the user logged and a window this app produced. **The claim-free-ness is the whole point of the line.** PLAN 6.3 says a missed period is a data state and not a life event to comment on, so the line reports the state and stops. A citation here would imply there was something to conclude. |
| `companionLineNothingLoggedRecently` | Nothing has been logged for a few days, and the log is on the first tab. | An offer to open a screen. No claim, no nudge, and deliberately no reason asked for — a gap may be pregnancy, loss, illness, or simply not wanting to think about it (PLAN 2.4.1). |
| `companionLineNoLogsYet` | Nothing is recorded yet; one period start date is enough to begin. | Restates what onboarding already said about how this app works. |
| `companionLineNoPredictionYet` | Not enough history for a prediction; Insights holds what there is. | A statement about the model's own state, and a pointer at the user's own figures. |
| `companionLineTodayLogged` | Today is logged and the day can be reopened. | A statement about the user's data and about a screen. Deliberately carries no praise: logging is not an achievement, and `companion_copy_test.dart` fails on the vocabulary of one. |
| `companionLineNothingToPointAt` | Nothing to point at just now. | The fallback. It says nothing rather than manufacturing something, which is the reason a finite vocabulary is safe: the alternative to having a line is having no line, not having a worse one. |

Two further strings are shown alongside every suggestion and carry no claim
either. `companionHowItWorks` says what the thing is — a fixed set of written
lines, reading what was logged on this device, which is not the same as knowing
how anyone feels. `companionSourcesNote` points here, and is shown **only under
a line that carries a health claim**, so that its presence means something.
