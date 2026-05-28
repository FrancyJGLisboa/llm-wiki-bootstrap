<!--
  Vendored from FrancyJGLisboa/Infographic-extractor (references/archetypes.md).
  Bundled so produced wikis are self-contained (no external skill required).
  License: pending upstream — add MIT/Apache to Infographic-extractor.
  /wiki-diagram reads this file as the single source of truth for archetype lenses.
-->
# Archetypes

Eight archetypes. Each has a lens (what to look for in the material) and a content structure (what the downstream generator will produce).

Apply each lens **independently** to the retrieved wiki material. Score every candidate (see `scoring-rubric.md`). Mark hybrids when a concept fires under multiple lenses. Content that fits no lens goes to `archetype_gaps`.

---

## A1 — Single-Number Metric

**When to use**: concept with an explicit formula combining inputs into a single output metric, with actionable binary states (high/low → different actions).

**Lens — what to look for**:
- Explicit formulas with units
- Metrics: ratios, spreads, margins, indices
- Concepts described as "the difference between X and Y", "X divided by Y", "X minus Y"
- Mentions of conversion factors, weights, or proportions
- Language like "above X means…", "below Y triggers…"

**Visual metaphor**: `input(s) → output(s) = metric` horizontal equation, plus binary indicators (positive ↑ / negative ↓) to the right.

**Content structure (5 sections)**:
1. What it is — operational definition (2-3 sentences)
2. How it is calculated — explicit formula with units and conversion factors
3. What it tells you — 2 columns (positive vs negative state), 3 bullets each, plus a one-line self-regulating principle
4. How it is used in practice — 3 specific actions (with colored arrows) plus caveats
5. Regional/contextual variations — 3-row table

**Pull quote**: cross-domain analogy.

---

## A2 — Process Flow

**When to use**: ordered sequence of stages that transforms something (supply chain, ETL pipeline, trade lifecycle, processing operation).

**Lens — what to look for**:
- Sequences with explicit ordering ("first…then…then…")
- Stages with distinct operators, inputs, outputs
- Transformation language; workflows, pipelines, processes
- Time-ordered descriptions of how something happens end-to-end

**Visual metaphor**: 3-7 horizontal stages connected by arrows. Each stage carries icon + label + sub-label (input → action → output).

**Content structure (5 sections)**:
1. Overview — what enters at one end, what exits at the other (2-3 sentences)
2. Stages detailed — for each stage: what happens, who operates, key metric
3. Typical bottlenecks — 3 bullets on where the flow stalls plus warning signs
4. Monitoring metrics — KPIs per stage in a compact table
5. Variations by context — how the flow changes across 2-3 contexts

**Pull quote**: why understanding the flow matters more than the end product.

---

## A3 — State Regime

**When to use**: discrete mutually-exclusive states with transition triggers and distinct recommended actions (ENSO phases, contango/backwardation, policy stance, crop cycle phase).

**Lens — what to look for**:
- Discrete states named explicitly
- Transition language ("when X exceeds Y, regime shifts to…")
- Distinct actions associated with each state
- Threshold-based classification rules
- Historical case lists of when each state occurred

**Visual metaphor**: 2-4 state boxes connected by arrows labeled with transition triggers. Each state gets a distinct color (teal / orange / gray for neutral).

**Content structure (5 sections)**:
1. What defines each state — classification criterion (1 line per state)
2. Transition triggers — what moves A→B, B→C (with thresholds when applicable)
3. What to do in each state — table: state × recommended action
4. How to detect the change — leading and confirming signals
5. Historical cases — 2-3 dated examples with duration and outcome

**Pull quote**: the cost of identifying the regime too late.

---

## A4 — Comparison Matrix

**When to use**: N alternatives compared across the same dimensions (instruments, contract types, methodologies, vendors, frameworks).

**Lens — what to look for**:
- Lists of alternatives presented in parallel ("futures vs options vs swaps")
- Repeated attributes evaluated across alternatives ("cost", "liquidity", "flexibility")
- Comparative tables or implicit comparisons in prose
- Phrases like "the trade-off between…", "the main difference is…"

**Visual metaphor**: row of icons of the alternatives (3-5) side by side at top with label underneath.

**Content structure (4 sections — matrix is the centerpiece)**:
1. Comparison matrix — table alternatives × dimensions (5-7 dimensions) with short cells
2. When each makes sense — 1-2 sentences per alternative
3. Pitfalls and hidden costs — 3-5 bullets on common traps
4. How to choose — simple decision tree (3-4 questions) or rule of thumb

**Pull quote**: the central trade-off nobody wants to admit.

---

## A5 — Causal Chain

**When to use**: driver → transmission mechanism → outcome chain (weather shock → yield → price; rate hike → DXY → commodities).

**Lens — what to look for**:
- "X causes Y" or "X leads to Y which leads to Z" patterns
- Transmission mechanism explanations
- Chains of causation; sensitivity language ("for every 1% decline in X, Y moves Z%")
- Discussions of when the chain breaks or weakens

**Visual metaphor**: horizontal chain with 3-5 nodes connected by thick arrows. First node teal (driver), intermediate nodes gray (mechanisms), final node colored by sign.

**Content structure (5 sections)**:
1. Driver — starting point and how to measure it
2. Transmission mechanism — step-by-step propagation
3. Expected magnitudes — how much each link moves (with units and ranges)
4. Modifiers — what amplifies or attenuates the effect (3-5 factors)
5. When the chain breaks — conditions under which the effect fails to confirm

**Pull quote**: why the effect is rarely linear.

---

## A6 — Cycle / Loop

**When to use**: recurring stages that return to the starting point (crop calendar, hog cycle, business cycle, a self-reinforcing process).

**Lens — what to look for**:
- "After X, comes Y, then Z, then back to X"
- Cyclical language: "cycle", "loop", "seasonality", "recurrence"
- Self-perpetuating dynamics
- Typical duration estimates ("4-year cycle")

**Visual metaphor**: circular diagram with 4-8 stages around a circle, arrows indicating direction. Stages colored by intensity.

**Content structure (5 sections)**:
1. Cycle stages — short description of each (1 line per stage)
2. Typical duration — average time in each stage plus total cycle length
3. What drives the cycle — fundamental drivers
4. Inflection signals — how to identify transitions between stages
5. Geographic/contextual variations — how the cycle differs across 2-3 contexts

**Pull quote**: why the cycle self-perpetuates even when everyone knows it exists.

---

## A7 — Network / Map

**When to use**: nodes (places, entities, actors) connected by flows or relationships where geography or topology — not sequence — is the organizing axis (trade lanes, supply networks, partnership graphs).

**Lens — what to look for**:
- Enumeration of units (countries, regions, ports, hubs, entities) treated as nodes
- Flow language without ordering ("X exports to Y", "Z connects A and B")
- "Hub", "corridor", "lane", "basin", "spoke" vocabulary
- Multiple origin-destination pairs in parallel without a canonical sequence

**Visual metaphor**: map (or abstract node graph when geography is not literal) with nodes sized by weight and edges sized by flow magnitude. Teal for primary nodes, gray for secondary, orange for emerging.

**Content structure (5 sections)**:
1. Network overview — what the nodes represent, what flows between them, the unit of flow
2. Major nodes — 5-8 most important with one defining attribute each
3. Principal corridors — top 3-5 flows with magnitude and direction
4. Concentration vs dispersion — how much of total flow concentrates in the top N
5. Structural shifts — how the network is changing

**Pull quote**: the structural reason the dominant corridor is dominant.

---

## A8 — Taxonomy / Tree

**When to use**: parent → child → grandchild hierarchical categorization where leaves are mutually exclusive within a branch (frameworks, contract templates, instrument families, catalogs).

**Lens — what to look for**:
- "A is a type of B" or "B includes X, Y, Z" patterns
- Standards, template, framework, or catalog families
- "Library", "framework", "family", "catalog" vocabulary
- Multi-level categorization where leaves differ on multiple attributes

**Visual metaphor**: tree diagram (top-down or horizontal) with navy root, teal first-level branches, smaller leaves with short attribute labels. Orange highlight on branches with overlap.

**Content structure (5 sections)**:
1. Root and first-level split — what the parent category is and how it divides
2. Branches detailed — for each major branch: definition, leaf members, origin
3. Leaf attributes — what distinguishes leaves within the same branch
4. Where boundaries blur — branches with overlap or contested membership
5. Why classification matters — operational consequence of misfiling

**Pull quote**: the cost of misclassifying — what breaks when something is filed in the wrong branch.

---

## Hybrid handling

When a concept fires under multiple lenses, mark `is_hybrid: true` and record both `primary_archetype` (richest infographic with the available material) and `secondary_archetype` (the alternative, with brief justification).

## Outside-archetype patterns (route to `archetype_gaps`)

Visualizable but not covered by the eight:

- **Distribution / quantiles** — tails vs body of a distribution
- **Anatomy / component breakdown** — labeled parts of a thing
- **Multi-variable timeline** — multiple series over time with annotated events
- **Status board / kanban** — items grouped by workflow state (done / in-progress / blocked / planned)

If a pattern recurs across multiple `archetype_gaps`, surface it as a candidate for a future archetype.
