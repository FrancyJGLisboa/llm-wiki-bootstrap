# Retrieval questions — HELD OUT

Run only by `scripts/eval-retrieval.sh --holdout`, never by the default run and
never in CI.

This is the control. R1-R5 in `retrieval-questions.md` are visible to anyone
fixing the system, so they will eventually be optimised against — that is what
targets do. This file's modality (plain-text meeting notes), its needle, and its
supersession twist are not in that loop. If the main run goes green and this
does not, the green is Goodhart, not capability.

Do not "fix" a failure here by editing this file. Fix it in the main corpus and
re-run this untouched.

## Questions

### H1-notes
In the weekly platform sync notes, the retention window was corrected at some
point. What is the corrected value, and what identifier was the correction
logged under?
modality: notes
expects: NEEDLE-MTG-2e6b44, 90
cite-contains: NEEDLE-MTG-2e6b44
max-span: 20
