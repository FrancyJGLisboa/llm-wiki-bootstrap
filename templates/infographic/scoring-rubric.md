<!--
  Vendored from FrancyJGLisboa/Infographic-extractor (references/scoring_rubric.md).
  Bundled so produced wikis are self-contained. License pending upstream.
  /wiki-diagram scores every archetype candidate with this rubric.
-->
# Scoring Rubric

Four dimensions, each scored 1-5. `overall_score` = simple mean rounded to 1 decimal. Score AFTER consolidation, so hybrids are scored once under the primary archetype.

---

## Visualizability

**How naturally the candidate fits its assigned archetype, without forcing the template.**

- **5**: Fits perfectly. Every element of the content structure is present or trivially inferable.
- **4**: Fits well. 1-2 minor elements need inference but the fit is natural.
- **3**: Fits partially. Moderate interpretation; some sections will be thin.
- **2**: Barely fits. Forcing the template produces an awkward result. Consider hybrid or downgrade.
- **1**: Does not fit naturally. Route to `archetype_gaps`.

## Material Density

**How much the retrieved material covers the candidate concept.**

- **5**: Deep coverage. At least 3 distinct angles in the material.
- **4**: Solid coverage. 2 angles developed in detail.
- **3**: Medium. 1 angle developed; others mentioned briefly.
- **2**: Quick mention with little development.
- **1**: Surface mention only.

## Standalone-ness

**Whether the candidate is understandable without the broader material.**

- **5**: Fully interpretable on its own.
- **4**: Needs 1-2 sentences of setup.
- **3**: Needs a paragraph of setup.
- **2**: Depends heavily on other concepts.
- **1**: Incomprehensible outside the original material.

## Audience Match

**Calibration against the requested audience.**

- **5**: Ideal level. Lands with no adaptation.
- **4**: Well-calibrated. Minor tweaks.
- **3**: Usable after adaptation.
- **2**: Significantly off-level (too basic or too advanced).
- **1**: Completely misaligned.

---

## Overall score

```
overall_score = round((visualizability + material_density + standalone + audience_match) / 4, 1)
```

No weighting — all four count equally.

## Interpretation guide

- **4.5-5.0**: Top-tier. Ready to generate with minimal extra work.
- **3.5-4.4**: Solid. Useful with light additional work. **Surface these in the candidate menu.**
- **2.5-3.4**: Marginal. Worth considering but needs substantial work.
- **1.5-2.4**: Weak. Probably skip.
- **<1.5**: Route to `archetype_gaps` or exclude.

`/wiki-diagram` surfaces candidates scoring **≥ 3.5** in the menu it presents the user, lists lower-scoring ones briefly, and reports `archetype_gaps` separately.
