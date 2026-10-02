# Deduplicate — Keep the Earliest Record

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![ROW_NUMBER](https://img.shields.io/badge/-ROW__NUMBER-8E44AD?style=flat-square) ![Partitioning](https://img.shields.io/badge/-Partitioning-8E44AD?style=flat-square)

> Adapted from `Scenerio16.scala` in `interview-scenerios-spark-sql`, which used
> `dropDuplicates("name")` — Spark's `dropDuplicates` keeps an arbitrary surviving row
> per key unless the data is sorted first. This version makes "keep the earliest by
> id" an explicit, deterministic rule.

## Problem Statement

An employee table has accidental duplicate rows for the same `name` (e.g. from a
double-loaded feed). For each `name`, keep only the row with the **lowest `id`**
(the earliest record) and drop the rest.

## Problem Dataset

```sql
CREATE TABLE employee_records (
    id     INT,
    name   VARCHAR(20),
    dept   VARCHAR(20),
    salary NUMERIC
);

INSERT INTO employee_records VALUES
(1, 'John', 'Testing',     5000),
(2, 'Tim',  'Development', 6000),
(3, 'John', 'Development', 5500),
(4, 'Sky',  'Production',  8000);
```

Expected output:

| id | name | dept        | salary |
|----|-------|--------------|----------|
| 1  | John  | Testing      | 5000     |
| 2  | Tim   | Development  | 6000     |
| 4  | Sky   | Production   | 8000     |

John's second record (`id = 3`, `Development`, 5500) is dropped — only his earliest
row survives.

## Problem Explanation

"Keep one row per key, chosen by some tiebreak rule" is exactly what `ROW_NUMBER()`
is for: number each `name` group's rows in the desired tiebreak order, then keep only
`rn = 1`. This is more reliable than a tool-level "drop duplicates" operation, which
often doesn't let you control *which* duplicate survives — here, correctness depends
on keeping the *earliest* one specifically, not an arbitrary one.

## Problem Answer & Explanation

```sql
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY name ORDER BY id) AS rn
    FROM employee_records
)
SELECT id, name, dept, salary
FROM ranked
WHERE rn = 1
ORDER BY id;
```

**Why it works**

1. `PARTITION BY name` groups rows by the deduplication key.
2. `ORDER BY id` (ascending, the default) ranks the earliest row (lowest `id`) as
   `rn = 1` within each name group — this is the tiebreak rule that makes the
   deduplication deterministic and repeatable.
3. `WHERE rn = 1` keeps exactly one row per `name`, discarding every later duplicate.
4. `ROW_NUMBER()` (not `RANK()`) is the right choice here, deliberately unlike most
   other ranking problems in this repo — deduplication needs *exactly one* survivor
   per group even if two rows technically tie on the order column (e.g. two rows with
   the same `id`, which shouldn't happen with a proper primary key but could with
   messy source data); `RANK()` would let both ties through and defeat the purpose.

**Interview follow-up:** ask how the rule changes if "duplicate" should be defined by
*multiple* columns instead of just `name` (e.g. same `name` **and** `dept` counts as a
true duplicate, but same name in a different dept doesn't) — only the `PARTITION BY`
clause changes, to `PARTITION BY name, dept`; the rest of the pattern is identical,
which is why this technique scales cleanly to more complex dedup keys.
