# Most Frequent Rank-1 Finisher

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Array Functions](https://img.shields.io/badge/-Array%20Functions-7F8C8D?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square)

> Adapted from `Scenerio9.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Each driver's race results are stored as an array of finishing positions (one array
per driver, one element per race). Find the driver with the most **1st-place**
finishes.

## Problem Dataset

```sql
CREATE TABLE race_results (
    driver_name VARCHAR(10),
    finishes    INT[]
);

INSERT INTO race_results VALUES
('a', ARRAY[1,1,1,3]),
('b', ARRAY[1,2,3,4]),
('c', ARRAY[1,1,1,1,4]),
('d', ARRAY[3]);
```

Expected output:

| driver_name | win_count |
|--------------|-------------|
| c            | 4           |

Driver `c` has four 1st-place finishes, edging out driver `a`'s three.

## Problem Explanation

Unlike [Explode & Aggregate Skills](../13-explode-and-aggregate-skills/README.md),
where the array first had to be *parsed* out of a delimited string, this dataset
already stores a native `INT[]` array column — so the explode step is simpler, just
`UNNEST()` directly with no `STRING_TO_ARRAY()` first. Once every finishing position
is its own row, the rest is the familiar "filter, count, pick the top one" chain.

## Problem Answer & Explanation

```sql
WITH exploded AS (
    SELECT driver_name, UNNEST(finishes) AS finish_position
    FROM race_results
),
wins AS (
    SELECT driver_name, COUNT(*) AS win_count
    FROM exploded
    WHERE finish_position = 1
    GROUP BY driver_name
)
SELECT driver_name, win_count
FROM wins
ORDER BY win_count DESC
LIMIT 1;
```

**Why it works**

1. `UNNEST(finishes)` expands each driver's array into one row per race result,
   carrying `driver_name` along for every element — the same fan-out mechanic as
   `UNNEST(STRING_TO_ARRAY(...))` elsewhere in this repo, just skipping the string-
   parsing step since the array already exists as a native type.
2. `WHERE finish_position = 1` in the `wins` CTE keeps only the races each driver won,
   before counting — filtering before grouping is what makes `COUNT(*)` mean "count of
   wins" rather than "count of all races," which would need a `CASE`/`FILTER` instead.
3. `ORDER BY win_count DESC LIMIT 1` picks the single top driver. If a tie for most
   wins were possible and both should be returned, this would need to become the same
   `RANK() = 1` pattern used in [Top-Selling Product per Year](../29-top-selling-product-per-year/README.md)
   instead of `LIMIT 1`.

**Interview follow-up:** ask how the query changes if you need the win count for
*every* driver, not just the winner — drop the final `ORDER BY ... LIMIT 1` and select
straight from `wins`; note that drivers with **zero** wins (like driver `d`, who never
finishes 1st) won't appear at all, since the `WHERE finish_position = 1` filter in
`wins` removes their rows before the `GROUP BY` — a `LEFT JOIN` back to the full
driver list (with `COALESCE(win_count, 0)`) would be needed to include them.
