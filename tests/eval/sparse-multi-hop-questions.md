# Sparse-fixture multi-hop questions for typed-relations gate

The `scripts/eval-multi-hop-sparse.sh` script reads this file, runs each question
against the **baseline** (verbs stripped from single-target `## Related` lines)
and the **typed** copies of `tests/eval/sparse-fixture/`, and grades by literal
case-insensitive substring match.

## Per-question format

```
### Q<n>
Question text on one or more lines.
expects: token1, token2, ...
baseline-absent: true|false
hops: 2|3
```

- `expects`: comma-separated tokens; every token must appear in the answer for
  the question to pass on a given variant.
- `baseline-absent`: this fixture is engineered so every question is
  baseline-absent — `true` for all.
- `hops`: the number of forward typed edges that must be traversed.

## Verb semantics (forward supply direction)

Forward supply edges in this fixture: `feeds`, `powers`, `produces`,
`ships-via`, `terminates-at`. For `A <verb> B`, A is the source and B is
the target — A is positionally "above" B in the supply chain. The verbs
`succeeds` and `replaces` are temporal (successor/replacement) and are NOT
forward supply edges; questions below ignore them when tracing supply.

## Questions

### Q1
Following only the forward supply edges in the typed `## Related` graph
(feeds, powers, produces, ships-via, terminates-at), how does velnar sit
relative to zerlon? Reply with one position word (above-or-below the source
in the supply chain) and one distance word (directly-adjacent or via an
intermediate).
expects: downstream, transitive
baseline-absent: true
hops: 2

### Q2
Following only the forward supply edges in the typed `## Related` graph,
how does thalox sit relative to zerlon? Reply with one position word and
one distance word, as in Q1.
expects: upstream, transitive
baseline-absent: true
hops: 2

### Q3
Following only the forward supply edges in the typed `## Related` graph,
how does mordax sit relative to bryntex? Reply with one position word and
one distance word, as in Q1.
expects: downstream, transitive
baseline-absent: true
hops: 2

### Q4
Following only the forward supply edges in the typed `## Related` graph,
how does glivex sit relative to mordax? Reply with one position word and
one distance word.
expects: upstream, transitive
baseline-absent: true
hops: 3

### Q5
Following only the forward supply edges in the typed `## Related` graph,
how does quirpal sit relative to mordax? Reply with one position word and
one distance word.
expects: upstream, transitive
baseline-absent: true
hops: 3

### Q6
At the bryntex node, two entities arrive via the same `powers` verb. Are
those two entities sibling sources of bryntex (both directly powering it
with no chain between them), or is one a transitive ancestor of the other
in the supply graph? Reply with a single category word describing the
relationship between those two power-source entities.
expects: parallel
baseline-absent: true
hops: 2

### Q7
Starting from velnar and tracing strictly forward through supply verbs
(feeds, powers, produces, ships-via, terminates-at) for up to three hops,
is any other node reachable, or is the rest of the graph not-reachable
from velnar? Reply with one category word for the forward-reachability
state.
expects: unreachable
baseline-absent: true
hops: 2
