---
title: Import Permit Required
type: rule
rule_id: RULE-0005
rule_class: deterministic
rule_domain: world
source: report
updated: 2026-08-09
asserted_at: 2026-05-01
statement: "A soybean meal import must hold a permit issued under the 2026 licensing procedure."
detection: "for a consignment with entry_date >= 2026-05-01: assert a permit reference is present"
gate: none
tags: [trade]
---

# Import Permit Required

## Definition / TL;DR
A rule about the world, not about this package.

## Body
THE NEGATIVE CONTROL for R-01's domain split. Deterministic in shape and
ungated, so a lint that ignored `rule_domain` would fire here — and this tree
must stay green. There are no consignments in this package to check it against;
demanding a gate would be demanding a script with nothing to run on.

(source: raw/fixture.md#report-metadata)

## Related
- [[trade-policy]] related-to — parent topic
- [[licensing]] related-to — mechanism
