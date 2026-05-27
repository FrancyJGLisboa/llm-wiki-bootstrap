# Sealed-channels multi-hop questions for phase-3 gate

The `scripts/eval-multi-hop-sealed.sh` script reads this file, runs each question
against the **baseline** (verbs, attrs, AND `tags:` lines stripped from
`tests/eval/sealed-fixture/`) and the **typed** copy, and grades by
**word-boundary** numeric match on every `expects:` token (NOT substring — this
fixes the grader bug that would otherwise let `"page 12 of …"` false-pass
`expects: 12`).

## Per-question format

```
### Q<n>
Question text on one or more lines.
expects: <4-or-more-digit integer>
baseline-absent: true
hops: 2|3
```

Question prose is **verb-neutral** — it never names any verb literal from the
fixture (see C7(e) in the phase-3 GOAL). Baseline cannot reach the numeric
answer because attrs are stripped; typed can sum the integers along the chain.

## Questions

### Q1
Sum the integers on each Related line along the directed chain xyloth → kyphix → vornak. Reply with the integer total only.
expects: 2636
baseline-absent: true
hops: 2

### Q2
Sum the integers on each Related line along the directed chain kyphix → vornak → pluxar. Reply with the integer total only.
expects: 2910
baseline-absent: true
hops: 2

### Q3
Sum the integers on each Related line along the directed chain vornak → pluxar → grymon. Reply with the integer total only.
expects: 3214
baseline-absent: true
hops: 2

### Q4
Sum the integers on each Related line along the directed chain pluxar → grymon → whelox. Reply with the integer total only.
expects: 3510
baseline-absent: true
hops: 2

### Q5
Sum the integers on each Related line along the directed chain grymon → whelox → jorvex. Reply with the integer total only.
expects: 3751
baseline-absent: true
hops: 2

### Q6
Sum the integers on each Related line along the directed chain xyloth → kyphix → vornak → pluxar. Reply with the integer total only.
expects: 4157
baseline-absent: true
hops: 3

### Q7
Sum the integers on each Related line along the directed chain kyphix → vornak → pluxar → grymon. Reply with the integer total only.
expects: 4603
baseline-absent: true
hops: 3

### Q8
Sum the integers on each Related line along the directed chain vornak → pluxar → grymon → whelox. Reply with the integer total only.
expects: 5031
baseline-absent: true
hops: 3

### Q9
Sum the integers on each Related line along the directed chain pluxar → grymon → whelox → jorvex. Reply with the integer total only.
expects: 5444
baseline-absent: true
hops: 3

### Q10
Sum the integers on each Related line along the directed chain xyloth → vornak → pluxar → grymon, taking the direct xyloth → vornak edge (not the longer xyloth → kyphix → vornak path). Reply with the integer total only.
expects: 5272
baseline-absent: true
hops: 3