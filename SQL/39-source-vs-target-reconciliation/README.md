# Source vs Target Reconciliation

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Full Outer Join](https://img.shields.io/badge/-Full%20Outer%20Join-16A085?style=flat-square) ![NULL Handling](https://img.shields.io/badge/-NULL%20Handling-34495E?style=flat-square)

> Adapted from `Scenerio26.scala` in `interview-scenerios-spark-sql`. The original's
> filter (`s.name != t.name1 OR s.name IS NULL OR t.name1 IS NULL`) has a subtle bug —
> `!=` against a `NULL` value evaluates to `NULL` (not `TRUE`), so on some engines that
> clause would need the extra `OR ... IS NULL` checks to compensate. This version uses
> `IS DISTINCT FROM`, which handles the `NULL` case correctly on its own.

## Problem Statement

You have a `source` table (the "before" snapshot) and a `target` table (the "after"
snapshot, e.g. after a downstream sync). Reconcile them: for every row that differs
between the two, report whether it's new in the source (missing from target), new in
the target (missing from source), or a genuine mismatch (present in both, but with
different values).

## Problem Dataset

```sql
CREATE TABLE source_tab (id INT, name VARCHAR(10));
INSERT INTO source_tab VALUES (1, 'A'), (2, 'B'), (3, 'C'), (4, 'D');

CREATE TABLE target_tab (id INT, name VARCHAR(10));
INSERT INTO target_tab VALUES (1, 'A'), (2, 'B'), (4, 'X'), (5, 'F');
```

Expected output:

| id | comment       |
|----|-----------------|
| 3  | new in source   |
| 4  | mismatch        |
| 5  | new in target   |

Rows `1` and `2` match exactly in both tables and are correctly excluded — this report
only surfaces the *differences*.

## Problem Explanation

A reconciliation report needs to see **every** row from both sides at once, including
rows that exist on only one side — which is exactly what `FULL OUTER JOIN` is for
(unlike `LEFT JOIN`, which would silently drop target-only rows, or `INNER JOIN`,
which would drop both kinds of one-sided rows entirely). Once every row is present,
the classification logic is a `CASE` that checks, in order, which side is missing
before checking whether the values actually differ.

## Problem Answer & Explanation

```sql
SELECT
    COALESCE(s.id, t.id) AS id,
    CASE
        WHEN t.name IS NULL THEN 'new in source'
        WHEN s.name IS NULL THEN 'new in target'
        WHEN s.name <> t.name THEN 'mismatch'
    END AS comment
FROM source_tab s
FULL OUTER JOIN target_tab t ON s.id = t.id
WHERE s.name IS DISTINCT FROM t.name
ORDER BY id;
```

**Why it works**

1. `FULL OUTER JOIN ... ON s.id = t.id` keeps every row from both tables: matched rows
   get both sides' columns populated, and unmatched rows get `NULL` on whichever side
   has no match.
2. `COALESCE(s.id, t.id)` produces a single `id` column regardless of which side
   actually had the match — necessary because a target-only row has `s.id = NULL`, and
   a source-only row has `t.id = NULL`.
3. The `CASE` checks `t.name IS NULL` (source-only row) and `s.name IS NULL`
   (target-only row) **before** checking for a value mismatch — order matters here,
   since a source-only row also technically has `s.name <> t.name` evaluate to `NULL`
   (unknown), so the missing-side checks have to come first to correctly label it
   `'new in source'` rather than falling through unclassified.
4. The outer `WHERE s.name IS DISTINCT FROM t.name` is what filters the report down to
   only genuine differences. `IS DISTINCT FROM` is `<>` with `NULL`-safe semantics
   built in: normal `<>` treats any comparison involving `NULL` as unknown (neither
   true nor false) and such rows would be silently dropped by a plain `WHERE ... <>
   ...` filter, so `IS DISTINCT FROM` is what's needed to correctly catch a matching
   row on one side against a missing row on the other.

**Interview follow-up:** ask how this generalizes to a table with many columns instead
of just `name` — the `CASE` and `IS DISTINCT FROM` logic would need to check every
comparable column, which gets unwieldy by hand; at that point it's common to hash each
row's full column set (e.g. `MD5(ROW(col1, col2, ...)::TEXT)`) on both sides and
compare the hashes instead of comparing column-by-column.
