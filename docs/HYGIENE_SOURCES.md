# Menstrual hygiene products: claims and sources

Tampons, menstrual cups and pads are FDA **devices**, not drugs. They are not in
`/drug/label` and the openFDA generator in AND-31 cannot reach them, so the
entries in the app's lookup screen are **hand-curated**. This file is the record
of what each one claims and where it came from.

The app labels them as curated rather than sourced from a regulator, because the
distinction is real and a user is entitled to it: the medicines entries are a
dated snapshot of a regulator's own text, and these are not.

## Verification status

Claims are marked **[VERIFY]** until someone has opened the source and confirmed
it says what the claim says — the same convention `PLAN.md` uses for the priors
figures and `NUTRITION_SOURCES.md` uses for its claims. It means the wording was
written from general knowledge with the source named, not read off the page, and
**it is not yet fit to ship**.

`RELEASE.md` should not pass while any claim below still carries one.

## What these entries are not

They are not instructions, not a recommendation of one product over another, and
not addressed to the reader's own body. `PLAN.md` 6.2 forbids diagnostic
framing, and `hygiene_copy_test.dart` enforces the vocabulary.

The one thing here that is genuinely urgent — the symptoms that mean *stop and
get help now* — is written as a description of the symptoms and an instruction
to seek medical care, never as a diagnosis. "These symptoms need urgent medical
attention" is a statement about the symptoms. "You have toxic shock syndrome" is
a diagnosis of a person, and nothing in this app can support one.

---

## Toxic shock syndrome

TSS is rare and serious, and it is the reason this section exists at all. A
menstrual-cycle app that lists tampons without mentioning it would be leaving
out the only thing on the page that could matter urgently.

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| T1 | Toxic shock syndrome is a rare but life-threatening condition caused by bacterial toxins. | NHS, *Toxic shock syndrome* | **[VERIFY]** |
| T2 | It is associated with tampon use, and with menstrual cups, but can occur in people who are not menstruating at all. | NHS, *Toxic shock syndrome*, causes section | **[VERIFY]** |
| T3 | Commonly listed early symptoms include a sudden high fever, a sunburn-like rash, vomiting, diarrhoea, muscle aches, dizziness and confusion. | NHS, *Toxic shock syndrome*, symptoms section | **[VERIFY]** |
| T4 | The advice if these symptoms appear during tampon or cup use is to remove it and seek urgent medical care. | NHS, *Toxic shock syndrome* | **[VERIFY]** |
| T5 | Tampon guidance is to use the lowest absorbency adequate for the flow and to change it regularly rather than leaving one in longer than the packet advises. | FDA, *The Facts on Tampons — and How to Use Them Safely* | **[VERIFY]** |

T4 is the one that must never be softened. Everything else on this page is
reference reading; that line is the one someone might act on within the hour.

---

## Tampons

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| P1 | Tampons are regulated by the FDA as medical devices rather than as drugs. | FDA, *Tampons and Asbestos, Dioxin, & Toxic Shock Syndrome* | **[VERIFY]** |
| P2 | Absorbency is standardised and labelled, so the same rating means the same thing across brands. | FDA, *The Facts on Tampons* | **[VERIFY]** |

---

## Menstrual cups

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| C1 | Menstrual cups are reusable devices worn internally to collect rather than absorb menstrual fluid. | FDA device classification for menstrual cups | **[VERIFY]** |
| C2 | Cases of toxic shock syndrome associated with menstrual cup use have been reported. | Published case reports; see NHS *Toxic shock syndrome* for the general guidance | **[VERIFY]** |
| C3 | Manufacturer instructions cover cleaning between uses and how long a cup may be worn; those instructions differ by product. | Product labelling | **[VERIFY]** |

C3 deliberately points at the packet rather than giving a number. Wear times and
cleaning instructions genuinely differ between products, and a single figure in
this app would be wrong for somebody.

---

## Pads and period underwear

| # | Claim | Source | Status |
| --- | --- | --- | --- |
| A1 | External products are not associated with toxic shock syndrome in the way internally worn ones are. | NHS, *Toxic shock syndrome*, causes section | **[VERIFY]** |

Included because its absence would be read as an omission rather than as a
difference, by anyone who has just read the tampon entry.
