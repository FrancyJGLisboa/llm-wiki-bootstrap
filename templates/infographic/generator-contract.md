<!--
  Vendored from FrancyJGLisboa/Infographic-extractor (references/generator_handoff.md, v2).
  Bundled so produced wikis are self-contained. License pending upstream.
  /wiki-diagram applies this contract to turn a chosen candidate's handoff block
  into a renderable HTML poster. See example-poster.html for a worked scaffold.
-->
# Generator Contract (v2)

Turns a candidate's `handoff_to_generator` block into a renderable HTML infographic.

## Variables (from the candidate's handoff block)

| Variable | Description |
|---|---|
| `conceito` | Concept name (1-4 words) |
| `tagline` | Essence sentence, ≤12 words |
| `dominio` | Domain or market |
| `audiencia` | Target audience |
| `idioma` | `PT-BR` or `EN` |
| `arquetipo` | One of: `single_number_metric`, `process_flow`, `state_regime`, `comparison_matrix`, `causal_chain`, `cycle_loop`, `network_map`, `taxonomy_tree` |
| `analogia_final` | Cross-domain analogy for the pull quote, or null |
| `source_pages` | The wiki pages this candidate drew from (cite them in the footer) |

## Generation protocol

### Step 1 — Confirm archetype
`arquetipo` is always supplied from the handoff. Proceed.

### Step 2 — Apply the design system (invariant across all eight archetypes)

**Palette (fixed hex)**:
- Navy primary `#1B2A47` — titles, section numbers, quote block
- Teal secondary `#2A8B8C` — subtitles, positive indicators, accent
- Warning orange `#E45A2E` — negative indicators, alerts, transitions
- Cream gray `#F5F1EA` — card backgrounds
- White `#FFFFFF` — main background
- Divider gray `#D9D9D9` — separator lines

**Typography**:
- Titles: `Montserrat` 900, ALL CAPS, period at end
- Subtitles: `Montserrat` 600, teal, all caps, letter-spacing +2%
- Body: `Inter` 400, dark navy
- Section numbers: `Montserrat` 700, white, in navy 32×32px square
- Import via Google Fonts: `Montserrat:wght@400;600;900` and `Inter:wght@400;600;900`

**Layout**: vertical poster, ratio ≈ 2:3, width 800px, natural height. Header (title + tagline) → upper visual block (archetype-specific metaphor) → numbered content sections in a 2-column grid → footer (navy block with italic pull quote and large decorative quote marks).

**Iconography**: flat modern, no complex gradients. Arrows in teal/orange for binary states.

### Step 3 — Apply archetype-specific content structure
See `archetypes.md` for each archetype's upper visual metaphor and its 4-5 numbered sections.

### Step 4 — Generate
Produce HTML that is:
- **Single file, self-contained**
- **No JavaScript**
- CSS inline or in a `<style>` block
- Only external dependency: Google Fonts
- Width fixed at 800px, height natural
- Renderable directly in a browser

Write the file to `diagrams/<slug>.html` (the `diagrams/` directory is git-ignored). Report the full path.

## Content rules (transversal to all archetypes)

- Each section: ≤60 words
- Each bullet: ≤12 words
- Every magnitude with explicit units
- Concrete nouns > abstract nouns
- No filler ("It is important to note that…")
- No hedging when the fact is clear
- Language: `idioma`
- **Footer must cite `source_pages`** — the wiki pages the diagram drew from. Never invent connections not supported by retrieved pages.
