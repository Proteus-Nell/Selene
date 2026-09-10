# Nutrition reference: claims and sources

Every factual claim the app makes in its nutrition reference is listed here with
the source it came from. Nothing appears on that screen that is not in this
file, and `nutrition_sources_test.dart` fails the build if it does — an uncited
health claim in a health app is the thing this file exists to make impossible.

## Verification status

Claims are marked **[VERIFY]** until someone has opened the source and checked
that it says what the claim says. This is the same convention `PLAN.md` uses for
the priors figures and the dependency pinning, and it means the same thing here:
the wording is a starting point written from general knowledge, not a checked
quotation, and it is **not yet fit to ship**.

`[VERIFY]` is not decoration. The release checklist in `RELEASE.md` should not
pass while any claim below still carries one.

To clear a marker: open the source, confirm the claim, replace `[VERIFY]` with
`[VERIFIED yyyy-mm-dd, initials]`. If the source does not support the claim,
change the claim — do not clear the marker.

## What this reference is not

It is reference text about two nutrients, shown to someone tracking a menstrual
cycle. It is not advice, not a recommendation to supplement, and not addressed
to the reader's own body. `PLAN.md` 6.2 forbids diagnostic framing, and
`nutrition_copy_test.dart` enforces the specific vocabulary: no "you have", no
"you are deficient", no "diagnos-", no "you should take".

The distinction the whole feature rests on: *"heavy menstrual bleeding is a
recognised cause of iron loss"* is a statement about physiology. *"You are low
in iron"* is a diagnosis of a person, from data that cannot support one. Only
the first kind is here.

---

## Iron

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| I1 | Iron is a component of haemoglobin, which carries oxygen in the blood. | NIH Office of Dietary Supplements, *Iron — Health Professional Fact Sheet* | **[VERIFY]** |
| I2 | Menstrual blood loss is a route of iron loss, and heavier bleeding means more of it. | NIH ODS, *Iron*, section on groups at risk of inadequacy | **[VERIFY]** |
| I3 | Heavy menstrual bleeding is a recognised cause of iron deficiency anaemia in people who menstruate. | NICE guideline NG88, *Heavy menstrual bleeding: assessment and management* | **[VERIFY]** |
| I4 | Tiredness and lack of energy are among the commonly listed symptoms of iron deficiency anaemia. | NHS, *Iron deficiency anaemia* | **[VERIFY]** |
| I5 | Iron deficiency is diagnosed by a blood test, not by symptoms. | NHS, *Iron deficiency anaemia*, diagnosis section | **[VERIFY]** |
| I6 | Dietary iron occurs in two forms, haem (from meat and fish) and non-haem (from plants and fortified foods), which are absorbed differently. | NIH ODS, *Iron*, sources section | **[VERIFY]** |
| I7 | Taking iron supplements without a confirmed deficiency can cause harm, and excess iron accumulates. | NIH ODS, *Iron*, section on health risks from excessive iron | **[VERIFY]** |

### Why vitamin C is listed next to iron

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| C1 | Vitamin C increases absorption of non-haem iron when eaten in the same meal. | NIH ODS, *Vitamin C — Health Professional Fact Sheet*, section on iron absorption | **[VERIFY]** |

This is the only reason vitamin C appears in a menstrual-cycle app at all, and
the reference says so rather than listing it as a second thing to think about.

---

## Magnesium

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| M1 | Magnesium is involved in muscle and nerve function, among many other processes. | NIH ODS, *Magnesium — Health Professional Fact Sheet* | **[VERIFY]** |
| M2 | Magnesium is found in green leafy vegetables, legumes, nuts, seeds and wholegrains. | NIH ODS, *Magnesium*, sources section | **[VERIFY]** |
| M3 | Magnesium supplements are widely taken for period pain and premenstrual symptoms. Trials report some benefit, and reviews of those trials find the evidence limited and not conclusive. | Cochrane Database of Systematic Reviews, *Vitamin and mineral supplements for premenstrual syndrome* (Kaewrudee et al.); NIH ODS, *Magnesium*, section on magnesium and health | **[VERIFY]** |
| M4 | Oral magnesium comes in several salts, and they are not equally absorbed; glycinate and citrate are better absorbed than oxide. | NIH ODS, *Magnesium*, section on dietary supplements | **[VERIFY]** |
| M5 | Magnesium creams, oils and balms are sold for cramps, but absorption through intact skin is minimal. A narrative review of the topic concluded that meaningful transdermal absorption is not supported, and the best available trial found only a small, non-significant trend. | Gröber et al., *Myth or Reality — Transdermal Magnesium?*, Nutrients (2017); Kass et al., *Effect of transdermal magnesium cream on serum and urinary magnesium levels in humans*, PLOS One (2017) | **[VERIFY]** |
| M6 | No clinical guidance in the register names magnesium, in any form, as a treatment for period pain. | NHS, *Period pain*; NICE CKS, *Dysmenorrhoea* | **[VERIFY]** *(absence claim)* |

M3, M5 and M6 matter more than M1, M2 and M4. They are the claims that stop
this section reading as a recommendation, and none of them may be dropped for
brevity. M5 and M6 were added when the section was widened to cover the creams,
and they are the reason widening it did not turn it into an advertisement: the
section now says what people use and what the evidence under it is worth, which
is a different thing from saying it works.

M5 is cited outside the usual register, which is NIH ODS, NHS and NICE for this
file. The reason is that none of those bodies has published on transdermal
magnesium at all, and the honest answer to "does the cream work" is in the two
papers named. Citing nothing, or citing a fact sheet that does not mention it,
would have been worse than citing the literature that exists.

M6 is an absence claim: it says the guidance does *not* name magnesium as a
treatment. It is verified by reading the two named pages and finding no such
recommendation, and it is what keeps M3 and M5 in proportion.

### Why zinc is listed next to magnesium

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| Z1 | Zinc is an essential mineral involved in immune function and wound healing. | NIH ODS, *Zinc — Health Professional Fact Sheet* | **[VERIFY]** |
| Z2 | High-dose zinc supplementation over time can interfere with copper absorption. | NIH ODS, *Zinc*, section on interactions and excess intake | **[VERIFY]** |

Z2 is included deliberately. Zinc and magnesium are commonly sold together, and
a reference that mentions both without noting that one of them has a known
interaction at high doses would be less useful than saying nothing.

---

## The symptom hint

The app shows one hint, and only one, and only when both of these are true on
the same logged day, on at least `NutritionHints.minCoincidences` days within
the last `NutritionHints.lookbackDays`:

- flow recorded as heavy, and
- fatigue recorded at moderate or severe.

It says that the pattern is worth raising with a clinician. It names no
nutrient, no deficiency and no supplement, and it does not say what the pattern
means, because from two logged symptoms it cannot know.

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| H1 | Heavy menstrual bleeding is a reason to seek clinical assessment. | NICE NG88, *Heavy menstrual bleeding* | **[VERIFY]** |

The threshold of three days is a judgement call and has no source. It exists so
that one bad day does not produce a health prompt: a single heavy, tired day is
an ordinary period, and an app that says something about it every month teaches
the user to ignore it.
