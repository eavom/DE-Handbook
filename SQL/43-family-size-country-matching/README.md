# Family-Size Country Matching

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Non-Equi Join](https://img.shields.io/badge/-Non--Equi%20Join-16A085?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square)

> Adapted from `Scenerio33.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a table of families (with a family size) and a table of countries (each with a
minimum and maximum eligible family size for some visa/immigration program), find
every family-country combination where the family qualifies. Then find which family
qualifies for the **most** countries.

## Problem Dataset

```sql
CREATE TABLE families (
    family_id   VARCHAR(10),
    family_name VARCHAR(30),
    family_size INT
);
INSERT INTO families VALUES
('F1', 'Alex Thomas',    9),
('F2', 'Chris Gray',     2),
('F3', 'Emily Johnson',  4),
('F4', 'Michael Brown',  6),
('F5', 'Jessica Wilson', 3);

CREATE TABLE countries (
    country_id   VARCHAR(10),
    country_name VARCHAR(20),
    min_size     INT,
    max_size     INT
);
INSERT INTO countries VALUES
('C1', 'Bolivia',      2, 4),
('C2', 'Cook Islands', 4, 8),
('C3', 'Brazil',       4, 7),
('C4', 'Australia',    5, 9),
('C5', 'Canada',       3, 5),
('C6', 'Japan',       10, 12);
```

Expected output (part 1 — every qualifying match):

| family_name    | family_size | country_name  |
|------------------|--------------|-----------------|
| Alex Thomas      | 9            | Australia       |
| Chris Gray       | 2            | Bolivia         |
| Emily Johnson    | 4            | Bolivia         |
| Emily Johnson    | 4            | Brazil          |
| Emily Johnson    | 4            | Canada          |
| Emily Johnson    | 4            | Cook Islands    |
| Jessica Wilson   | 3            | Bolivia         |
| Jessica Wilson   | 3            | Canada          |
| Michael Brown    | 6            | Australia       |
| Michael Brown    | 6            | Brazil          |
| Michael Brown    | 6            | Cook Islands    |

Expected output (part 2 — family with the most matches):

| family_name    | num_countries |
|------------------|-----------------|
| Emily Johnson    | 4               |

No family qualifies for Japan (min size 10) — nobody's family is large enough.

## Problem Explanation

Every join used elsewhere in this repo matches rows on **equality** (`a.id = b.id`).
This problem needs a **non-equi join**: a family "matches" a country when its size
falls inside a *range*, not when two columns are equal. SQL handles this exactly the
same way as any other join — the `ON` clause just holds a `BETWEEN` condition instead
of `=` — but it's worth calling out explicitly, since it's easy to assume joins are
always equality-based until a range-matching problem like this one shows up.

## Problem Answer & Explanation

**1. Every qualifying family-country match**

```sql
SELECT f.family_name, f.family_size, c.country_name
FROM families f
JOIN countries c
  ON f.family_size BETWEEN c.min_size AND c.max_size
ORDER BY f.family_name, c.country_name;
```

**2. Family that qualifies for the most countries**

```sql
WITH matches AS (
    SELECT f.family_name, f.family_size, c.country_name
    FROM families f
    JOIN countries c
      ON f.family_size BETWEEN c.min_size AND c.max_size
),
counts AS (
    SELECT family_name, COUNT(*) AS num_countries
    FROM matches
    GROUP BY family_name
)
SELECT family_name, num_countries
FROM counts
ORDER BY num_countries DESC, family_name
LIMIT 1;
```

**Why it works**

1. `ON f.family_size BETWEEN c.min_size AND c.max_size` is evaluated once per
   `(family, country)` combination — the database has to check the condition for
   every possible pair, which is why non-equi joins are more expensive than equality
   joins at scale (equality joins can use a hash or index lookup; a `BETWEEN` join
   generally can't, without a specialized range index).
2. A family can appear multiple times in the result (once per qualifying country) —
   `Emily Johnson` appears in 4 rows, one per country she qualifies for — since this
   is a genuine one-to-many fan-out, not a bug.
3. Part 2 layers a `GROUP BY family_name` + `COUNT(*)` on top of the match list to
   count how many countries each family qualifies for, then `ORDER BY num_countries
   DESC LIMIT 1` picks the top family — the same "aggregate, then pick the winner"
   shape used throughout this repo (e.g.
   [Top Salesperson Per Region](../22-top-salesperson-per-region/README.md)).

**Interview follow-up:** ask what index (if any) could speed up this join at scale —
a plain B-tree index on `family_size` or `(min_size, max_size)` helps some engines
prune candidates, but the general answer is that range/non-equi joins are a known hard
case for query optimizers, and at real scale this kind of matching is often restructured
as a lookup against a small number of discrete buckets instead of a live `BETWEEN`
join against every row.
