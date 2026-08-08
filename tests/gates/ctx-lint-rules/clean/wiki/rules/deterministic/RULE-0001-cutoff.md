---
title: Forecast Data Cutoff
type: rule
rule_id: RULE-0001
rule_class: deterministic
gate: gates/RULE-0001.sh
known_gaps:
  - "A source with no timestamp is skipped, not failed."
  - "A cutoff declared in prose rather than frontmatter is unparsed."
  - "Data laundered through an undated intermediate page is invisible."
---
