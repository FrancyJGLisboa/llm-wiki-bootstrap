#!/usr/bin/env python3
"""scripts/wiki-timeline.py — materialize the DATED evidence list for a topic.

The temporal counterpart to `wiki-to-kg.py | wiki-graph-walk.py`. That pair
exists because "what caused X" was being eyeballed across pages and got it
wrong; this exists for the same reason on the time axis.

Measured failure it addresses: change-over-time questions ("how did his
position shift", "does he still think that") scored 3/6, and the mechanism was
not bad reading — it was NO reading. Every answer that succeeded opened 1-3
files; both failures opened zero and answered from the synthesis artifacts,
which aggregate away the very timeline that IS the answer.

So the fix is not "try harder", it is "here is the reading list, in order":

    2021-02-25  asserted  raw/2021-02-25-did-china-just-cancel.md  <- wiki/china-cancellations.md
    2022-06-03  asserted  raw/2022-06-03-export-pace.md            <- wiki/export-pace.md

Dates come from `asserted_at` (valid time — what the DOCUMENT claims for its own
content), never from `fetched_at` (transaction time — when we snapshotted it).
Conflating the two is forbidden by the contract in wiki-lint-asserted-at.sh:
it makes every source look dated while encoding nothing.

Date provenance is a printed column, never laundered:

    asserted  `asserted_at: <ISO>` in frontmatter          authoritative
    inferred  leading ISO date in the filename             a guess, labelled
    unknown   `asserted_at: unknown`, or absent            sorted last, KEPT

`unknown` rows are printed, not dropped. A source with no discoverable date
still bears on the topic; silently omitting it would let the caller narrate a
clean trajectory over evidence that was quietly excluded.

Read-only. Never writes anything, never touches raw/ (hard rule 1). Stdlib only.

Usage:
    wiki-timeline.py --question "<the user's question>"   # classify + timeline
    wiki-timeline.py --topic "<terms>" [--raw raw] [--wiki wiki]
    wiki-timeline.py --classify "<question>"              # TEMPORAL / SINGLE-POINT
    wiki-timeline.py --demo                               # self-check, asserts

`--question` is the mode /wiki-query runs UNCONDITIONALLY at step 1. It decides
in code whether the question is cross-temporal, and only then prints the reading
list and the directive. The first version of this feature left that decision to
the model and measured 3/7 with median ZERO reads — see the note above classify().

Exit: 0 rows found (or demo passed), 1 no match, 2 usage error.
"""

from __future__ import annotations

import os
import re
import sys
from typing import NamedTuple

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "lib"))
from wikitext import parse_frontmatter  # noqa: E402

ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
FILENAME_DATE = re.compile(r"^(\d{4}-\d{2}-\d{2})")


class Source(NamedTuple):
    """One raw file, dated. `date` is None only when the label is 'unknown'."""

    path: str
    date: str | None
    label: str
    body: str


def date_of(path: str, fm: dict) -> tuple[str | None, str]:
    """Resolve (date, provenance-label) for one raw file.

    Deliberately does NOT fall back to `fetched_at`. See module docstring.
    """
    asserted = fm.get("asserted_at", "")
    if ISO_DATE.match(asserted):
        return asserted, "asserted"
    m = FILENAME_DATE.match(os.path.basename(path))
    if m:
        return m.group(1), "inferred"
    return None, "unknown"


def load_sources(raw_dir: str) -> list[Source]:
    out = []
    for name in sorted(os.listdir(raw_dir)):
        if name.startswith(".") or not name.endswith(".md"):
            continue
        full = os.path.join(raw_dir, name)
        if not os.path.isfile(full):
            continue
        with open(full, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        fm = parse_frontmatter(text.split("\n"))
        date, label = date_of(full, fm)
        out.append(Source(full, date, label, text.lower()))
    return out


def match(sources: list[Source], terms: list[str]) -> tuple[list[Source], bool]:
    """AND over terms; widen to OR only if AND finds fewer than two.

    The widening is load-bearing, not a convenience. A narrow query that returns
    zero rows sends the caller straight back to answering from the synthesis
    artifacts — the exact failure this script exists to prevent. Better to
    return a wider list and say so than to return nothing.
    """
    lowered = [t.lower() for t in terms if t]
    if not lowered:
        return sources, False
    strict = [s for s in sources if all(t in s.body for t in lowered)]
    if len(strict) >= 2:
        return strict, False
    wide = [s for s in sources if any(t in s.body for t in lowered)]
    if len(wide) > len(strict):
        return wide, True
    return strict, False


def citing_pages(wiki_dir: str, raw_path: str) -> list[str]:
    """Wiki pages carrying a `(source: raw/<this file>...)` citation.

    Matches the same literal citation grammar citation-audit.py greps for; a
    second, looser definition here would list pages whose provenance the audit
    does not actually recognise.
    """
    needle = "(source: raw/" + os.path.basename(raw_path)
    hits = []
    for root, _dirs, files in os.walk(wiki_dir):
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            full = os.path.join(root, name)
            with open(full, encoding="utf-8", errors="replace") as fh:
                if needle in fh.read():
                    hits.append(os.path.relpath(full))
    return hits


def render(rows: list[Source], wiki_dir: str) -> str:
    lines = []
    for s in sorted(rows, key=lambda s: (s.date is None, s.date or "")):
        pages = citing_pages(wiki_dir, s.path) if os.path.isdir(wiki_dir) else []
        cited = " <- " + ", ".join(pages) if pages else " <- (uncited by any page)"
        lines.append(f"{s.date or 'undated':10}  {s.label:8}  {s.path}{cited}")
    dated = [s for s in rows if s.date]
    span = f"{min(s.date for s in dated)}..{max(s.date for s in dated)}" if dated else "none"
    lines.append("")
    lines.append(
        f"# {len(rows)} source(s), {len(set(s.date for s in dated))} distinct date(s), span {span}"
    )
    return "\n".join(lines)


# ── classification ───────────────────────────────────────────────────────────
#
# The first version of this feature asked the MODEL to decide whether a question
# was cross-temporal and, if so, to run the timeline. Measured: 3/7 with median
# ZERO file reads — the router never fired. The model that fails to notice a
# cross-temporal question is exactly the model that will not invoke the check on
# itself, so making enforcement conditional on that judgment guaranteed it would
# be skipped precisely when it was needed.
#
# The classification therefore lives HERE, in code, and the caller runs one
# command unconditionally. There is no "decide whether to" branch left to skip.

_MONTH = (
    "january|february|march|april|may|june|july|august|september|october|"
    "november|december"
)
# Bare-month matching omits "may" on purpose: the modal verb ("he may have
# argued") is far commoner in questions than the month, and a phantom second
# time reference would fire the router on single-point questions. In the
# month+year form "May 2021" the ambiguity is gone, so it stays there.
_MONTH_BARE = _MONTH.replace("may|", "")

# ONE scan, alternation ordered longest-first, so "16 September 2020" yields a
# single reference rather than `september` + `2020` counted as two. That bug
# made every dated single-point question ("On 16 September 2020, what phrase…")
# look cross-temporal.
DATEREF_RE = re.compile(
    rf"\b(?:(?:{_MONTH})\s+(?:19|20)\d{{2}}"        # September 2020
    rf"|(?:19|20)\d{{2}}"                            # 2020
    rf"|{_MONTH_BARE}"                               # September
    rf"|spring|summer|fall|autumn|winter)\b",        # seasons
    re.I,
)

# Grain futures are NAMED by delivery month: "December corn", "July wheat",
# "May beans". Those are contracts, not dates — counting them as time references
# made "what did the analyst say about December corn on 4 May 2023" look
# cross-temporal. Domain-specific, and the corpus is full of them.
CONTRACT_MONTH_RE = re.compile(
    rf"\b(?:{_MONTH})\s+(?:corn|beans?|soybeans?|wheat|meal|oil|cattle|hogs|"
    r"futures|contract|board|options?)\b"
    # "winter wheat" / "spring wheat" name a CROP CLASS (hard red winter), not a
    # season. Same trap as contract months, and the corpus is full of both.
    r"|\b(?:winter|spring)\s+wheat\b",
    re.I,
)


def time_refs(question: str) -> set[str]:
    """Distinct time references, composite dates counted once, contracts dropped."""
    masked = CONTRACT_MONTH_RE.sub(" ", question)
    return {re.sub(r"\s+", " ", m.group(0).lower()) for m in DATEREF_RE.finditer(masked)}

# Words that assert a comparison across time. Kept explicit rather than clever:
# a reader must be able to see exactly what fires the router.
# Tuned against the 66-question single-point gold set, which is what stops this
# from being a wish-list. Three terms were removed after measurement:
#   `update`   — in this corpus it is a NOUN ("his fund-position update"), so it
#                fired on ordinary single-episode recall questions.
#   `compared` — the host compares things WITHIN one episode constantly.
#   bare `later`/`earlier` — too weak alone; now require a time unit in front
#                ("three months later"), which is what actually signals a second
#                point in time.
CHANGE_RE = re.compile(
    r"\b(chang(e|ed|es|ing)|shift(ed|s)?|evolv(e|ed|ing)|revis(e|ed|ion)|"
    r"revers(e|ed|al)|still|used to|any ?more|no longer|since then|"
    r"consistent with|contradict(s|ed|ion)?|always (said|held|argued)|"
    r"over time|trajectory|each time|both times|both occasions|"
    r"(day|week|month|year)s?\s+(later|earlier)|line up|set the two|"
    r"how the two|against each other|then and now|by contrast|whereas)\b",
    re.I,
)
# Explicit multi-source framing ("across four episodes", "on three occasions").
MULTI_RE = re.compile(
    r"\b(across|spanning|over)\s+\w+\s+(episode|occasion|year|month|report)s?\b|"
    r"\b(two|three|four|five|both)\s+(episode|occasion|time|date|report)s?\b",
    re.I,
)


def classify(question: str) -> tuple[bool, str]:
    """Is this question cross-temporal? Returns (is_temporal, why).

    Fires on ANY of: two or more distinct time references, a change/comparison
    verb, or explicit multi-source framing. Deliberately biased toward firing —
    a false positive costs one ~50ms script run, a false negative costs the
    wrong answer, and the measured failure was entirely false negatives.
    """
    refs = time_refs(question)
    if len(refs) >= 2:
        return True, f"{len(refs)} distinct time references: {', '.join(sorted(refs))}"
    m = CHANGE_RE.search(question)
    if m:
        return True, f"change/comparison term: {m.group(0)!r}"
    m = MULTI_RE.search(question)
    if m:
        return True, f"multi-source framing: {m.group(0)!r}"
    return False, "one or zero time references and no comparison term"


STOPWORDS = {
    "about", "across", "after", "again", "against", "another", "argued", "back",
    "been", "before", "being", "between", "both", "call", "called", "characterize",
    "cite", "describe", "did", "does", "each", "episode", "episodes", "explain",
    "figure", "first", "from", "gave", "give", "given", "had", "has", "have",
    "his", "host", "how", "into", "its", "later", "line", "made", "make", "more",
    "most", "much", "name", "named", "occasion", "occasions", "only", "other",
    "our", "over", "own", "phrase", "phrasing", "point", "reported", "said",
    "same", "say", "set", "she", "some", "spanning", "stance", "state", "stated",
    "such", "than", "that", "the", "their", "them", "then", "there", "these",
    "they", "this", "those", "three", "time", "times", "two", "used", "using",
    "was", "were", "what", "when", "where", "which", "while", "who", "why",
    "with", "would", "year", "years", "your",
    # Question-framing vocabulary. These are rare in spoken transcript and so
    # score as "distinctive" on frequency alone while carrying no topic.
    "account", "actually", "assessment", "current", "described", "expect",
    "expectation", "gave", "gone", "justified", "noted", "outlook", "put",
    "quoted", "stack", "stacked", "stating", "view", "views", "went",
    "whether", "went", "word", "words",
}


def salient_terms(question: str, sources: list[Source], k: int = 3) -> list[str]:
    """Pick the k most DISCRIMINATING content words from the question.

    Selection is by document frequency inside a BAND, not rarest-first. Measured
    on a real question, rarest-first returned `described, gone, whether` and
    missed the episode entirely: questions are written prose and the corpus is
    spoken transcript, so the rarest words in a question are reliably its formal
    framing vocabulary, not its subject. The topical terms sat in the middle of
    the distribution (`spot` 13/50, `balance` 17/50, `sheet` 18/50) while the
    junk sat at the bottom (`described` 2/50) and the useless at the top
    (`market` 50/50).

    So: drop the ubiquitous, drop the near-absent, take the rarest of what's
    left. IDF with both tails trimmed — and the caller still supplies no terms,
    so no model judgment enters here.
    """
    cands = {
        w
        for w in re.findall(r"[a-z][a-z'-]{3,}", question.lower())
        if w not in STOPWORDS
    }
    n_src = max(len(sources), 1)
    lo, hi = max(2, round(0.08 * n_src)), max(2, round(0.70 * n_src))
    scored = [(sum(1 for s in sources if w in s.body), w) for w in cands]
    banded = sorted((n, w) for n, w in scored if lo <= n <= hi)
    if banded:
        return [w for _n, w in banded[:k]]
    # Small corpus, or every term outside the band: fall back to any term some
    # source actually contains, rather than returning nothing and sending the
    # caller back to the synthesis pages.
    return [w for _n, w in sorted((n, w) for n, w in scored if n)[:k]]


def demo() -> int:
    """Self-check on a temp fixture: one source of each date provenance."""
    import tempfile

    with tempfile.TemporaryDirectory() as d:
        raw = os.path.join(d, "raw")
        os.mkdir(raw)
        fixtures = {
            "2020-01-05-early.md": "---\nasserted_at: 2021-06-01\n---\nexport cancellations talk\n",
            "2022-03-03-mid.md": "---\nfetched_at: 2026-01-01\n---\nexport cancellations again\n",
            "no-date-memo.md": "---\nasserted_at: unknown\n---\nexport cancellations memo\n",
        }
        for name, text in fixtures.items():
            with open(os.path.join(raw, name), "w", encoding="utf-8") as fh:
                fh.write(text)

        got = load_sources(raw)
        by_name = {os.path.basename(s.path): s for s in got}

        # frontmatter beats the filename — the filename is only a fallback
        assert by_name["2020-01-05-early.md"].date == "2021-06-01", "asserted_at must win"
        assert by_name["2020-01-05-early.md"].label == "asserted"
        # fetched_at is NOT a document date; filename is used instead, labelled
        assert by_name["2022-03-03-mid.md"].date == "2022-03-03", "filename fallback"
        assert by_name["2022-03-03-mid.md"].label == "inferred"
        # undiscoverable stays undiscoverable rather than being invented
        assert by_name["no-date-memo.md"].date is None
        assert by_name["no-date-memo.md"].label == "unknown"

        rows, widened = match(got, ["export", "cancellations"])
        assert len(rows) == 3 and not widened, "AND match over all three"
        # sorted by DATE, not by provenance — an inferred 2022 row comes after an
        # asserted 2021 one. And the undated row is kept, sorted last, never dropped.
        ordered = sorted(rows, key=lambda s: (s.date is None, s.date or ""))
        assert [s.date for s in ordered] == ["2021-06-01", "2022-03-03", None], ordered
        assert [s.label for s in ordered] == ["asserted", "inferred", "unknown"], ordered

        narrow, widened = match(got, ["export", "nonexistentterm"])
        assert widened and len(narrow) == 3, "widens rather than returning nothing"

        out = render(rows, os.path.join(d, "wiki"))
        assert "3 distinct date(s)" not in out, "two dates + one undated"
        assert "2 distinct date(s)" in out, out

        # classifier — the piece whose failure produced 3/7 with 0 reads
        for q in [
            "How did his view on China change between 2021 and 2022?",   # 2 years
            "Does he still think ethanol is a wet blanket?",              # 'still'
            "At the end of September 2020 he gave a view. Three months "
            "later he described where it went. Set the two against each other.",
            "Across four episodes spanning more than two years, "
            "characterize his stance.",                                   # multi
            "Is that consistent with what he argued earlier?",
        ]:
            hit, why = classify(q)
            assert hit, f"classifier missed a cross-temporal question: {q!r} ({why})"
        for q in [
            "On 16 September 2020, what two-word phrase did he use for ethanol?",
            "What was the stocks-to-use ratio he quoted?",
        ]:
            hit, why = classify(q)
            assert not hit, f"classifier fired on a single-point question: {q!r} ({why})"

        # salient_terms must prefer the RARE word over the ubiquitous one
        picked = salient_terms("what did he say about ethanol and cancellations", got, k=1)
        assert picked == ["cancellations"], picked

    print("wiki-timeline --demo: all asserts passed")
    return 0


DIRECTIVE = """
================================ ACT ON THIS ================================
CROSS-TEMPORAL QUESTION ({why}).

This question cannot be answered from one point in time. Before you answer:

  1. READ at least TWO of the dated sources below, at DIFFERENT dates —
     the earliest and latest bearing on the question, plus any where the
     position turns. Open the raw files; a `(uncited by any page)` row exists
     ONLY in raw/, so no wiki page carries its content.
  2. Your answer must CITE at least two of those dates' own raw anchors.
  3. Before presenting, write the answer to a file and run the gate:
       bash scripts/wiki-metrics.sh query <answer-file> . --temporal
     Exit 4 means you answered from a single point in time. That is blocking.

Answering from wiki/index.md or the auto-generated synthesis pages is the
known failure mode here: those aggregate away the timeline that IS the answer.

IF, AFTER READING, the answer genuinely rests on ONE date — this detector is
deliberately over-eager and does fire on point-in-time questions — then cite
that one source, state plainly that the wiki holds a single point in time on
this topic, and run the gate WITHOUT --temporal. You are reporting what you
found, not overruling the detector. What you may NOT do is imply a trajectory
from one date, or skip the reading because the question looked simple.
============================================================================
"""


def question_mode(question: str, raw_dir: str, wiki_dir: str) -> int:
    """Classify, and when temporal, print the reading list AND the directive.

    One command, run unconditionally by the caller. When the question is not
    cross-temporal this says so in one line and gets out of the way.
    """
    is_temporal, why = classify(question)
    if not is_temporal:
        print(f"# SINGLE-POINT question ({why}) — no timeline needed, answer normally.")
        return 0

    sources = load_sources(raw_dir)
    terms = salient_terms(question, sources)
    if not terms:
        print(DIRECTIVE.format(why=why))
        print("# no distinctive term in the question resolved to any source —"
              " locate the topic yourself, but the two-date floor still applies.")
        return 0
    rows, widened = match(sources, terms)
    print(DIRECTIVE.format(why=why))
    print(f"# selected terms (mid-frequency, most discriminating): {', '.join(terms)}")
    if widened:
        print("# NOTE: no source matched every term; widened to any-term match")
    if not rows:
        print("# no source mentions these terms — say the wiki holds no evidence.")
        return 1
    print(render(rows, wiki_dir))
    return 0


def main(argv: list[str]) -> int:
    topic = question = None
    raw_dir, wiki_dir = "raw", "wiki"
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--demo":
            return demo()
        if a == "--classify" and i + 1 < len(argv):
            is_temporal, why = classify(argv[i + 1])
            print(f"{'TEMPORAL' if is_temporal else 'SINGLE-POINT'}: {why}")
            return 0 if is_temporal else 1
        if a in ("--topic", "--question", "--raw", "--wiki") and i + 1 < len(argv):
            val = argv[i + 1]
            if a == "--topic":
                topic = val
            elif a == "--question":
                question = val
            elif a == "--raw":
                raw_dir = val
            else:
                wiki_dir = val
            i += 2
            continue
        print(__doc__.strip().split("Usage:")[1], file=sys.stderr)
        return 2
    if not os.path.isdir(raw_dir):
        print(f"error: no such directory: {raw_dir}", file=sys.stderr)
        return 2
    if question is not None:
        return question_mode(question, raw_dir, wiki_dir)
    if topic is None:
        print("error: --question or --topic is required (or --demo)", file=sys.stderr)
        return 2

    rows, widened = match(load_sources(raw_dir), topic.split())
    if not rows:
        print(f"# no source mentions {topic!r} — the wiki holds no evidence on this topic")
        return 1
    if widened:
        print("# NOTE: no source matched every term; widened to any-term match")
    print(render(rows, wiki_dir))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
