# Round Robin — Unique Pairs

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Self-Join](https://img.shields.io/badge/-Self--Join-16A085?style=flat-square) ![Combinatorics](https://img.shields.io/badge/-Combinatorics-2C3E50?style=flat-square)

## Problem Statement

Given a list of players, generate every unique pairing for a round-robin tournament —
each pair should appear exactly once (no `(Arjun, Bina)` **and** `(Bina, Arjun)` as
separate rows), and no player should be paired with themselves.

## Problem Dataset

```sql
CREATE TABLE players (
    player_id   INT,
    player_name VARCHAR(30)
);

INSERT INTO players VALUES
(1, 'Arjun'), (2, 'Bina'), (3, 'Chirag'), (4, 'Deepa');
```

Expected output:

| player_a | player_b |
|----------|-----------|
| Arjun    | Bina      |
| Arjun    | Chirag    |
| Arjun    | Deepa     |
| Bina     | Chirag    |
| Bina     | Deepa     |
| Chirag   | Deepa     |

4 players produce exactly 6 pairs — matching `C(4,2) = 6`, the combinatorial count of
"4 choose 2."

## Problem Explanation

A naive self-join (`players p1 JOIN players p2 ON p1.player_id <> p2.player_id`)
produces every *ordered* pair, including both `(Arjun, Bina)` and `(Bina, Arjun)` —
double the rows you actually want, plus it still needs a separate filter to drop
self-pairs like `(Arjun, Arjun)`. Both problems disappear with one change: join on
`<` instead of `<>`. A strict less-than comparison only ever keeps one direction of
each pair and automatically excludes a row matching itself (since `id < id` is never
true).

## Problem Answer & Explanation

```sql
SELECT
    p1.player_name AS player_a,
    p2.player_name AS player_b
FROM players p1
JOIN players p2 ON p1.player_id < p2.player_id
ORDER BY p1.player_id, p2.player_id;
```

**Why it works**

1. `p1.player_id < p2.player_id` (rather than `<>`) does two jobs in one condition:
   it excludes self-pairs (`id < id` is always false), and it excludes the mirrored
   duplicate of every pair (if `1 < 2` produces `(Arjun, Bina)`, the reverse row would
   need `2 < 1`, which is false, so it's never generated).
2. Because the comparison is on a stable, unique key (`player_id`), the "which one is
   `player_a`" choice is deterministic and consistent — it's always the lower id — so
   re-running the query always produces the same canonical ordering per pair.
3. `ORDER BY p1.player_id, p2.player_id` is purely for readability; it doesn't affect
   which pairs are produced.

**Interview follow-up:** ask how you'd assign these pairs into tournament **rounds**
where no player plays twice in the same round (true round-robin scheduling) — that's
a materially harder graph-coloring/matching problem, not solvable with a single join;
it's usually solved by generating pairs first (this query) and then scheduling them
with an algorithm outside plain SQL, or with a recursive assignment CTE similar to
[Team Capacity Subset Sum](../18-team-capacity-subset-sum/README.md).
