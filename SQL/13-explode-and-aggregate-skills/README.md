# Explode & Aggregate Skills

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Array Functions](https://img.shields.io/badge/-Array%20Functions-7F8C8D?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square)

## Problem Statement

A candidates table stores each person's skills as a single comma-separated string
(`'SQL,Python,Excel'`). Using only that string column:

1. Find the most in-demand skills across all candidates (skill, candidate count).
2. Find how many skills each candidate lists.

## Problem Dataset

```sql
CREATE TABLE candidates (
    candidate_id   INT,
    candidate_name VARCHAR(50),
    skills         TEXT   -- comma-separated
);

INSERT INTO candidates VALUES
(1, 'Ishaan Kapoor', 'SQL,Python,Excel'),
(2, 'Neha Trivedi',  'SQL,Tableau'),
(3, 'Aman Gupta',    'Python,Spark,SQL'),
(4, 'Simran Kaur',   'Excel,Tableau,SQL'),
(5, 'Rahul Sinha',   'Python');
```

Expected output (part 1 — skill demand):

| skill   | candidate_count |
|---------|-------------------|
| SQL     | 4                 |
| Python  | 3                 |
| Excel   | 2                 |
| Tableau | 2                 |
| Spark   | 1                 |

Expected output (part 2 — skills per candidate):

| candidate_name  | skill_count |
|------------------|--------------|
| Aman Gupta       | 3            |
| Ishaan Kapoor    | 3            |
| Simran Kaur      | 3            |
| Neha Trivedi     | 2            |
| Rahul Sinha      | 1            |

## Problem Explanation

A delimited string column can't be grouped or counted meaningfully as-is — `'SQL,
Python,Excel'` is one opaque value, not three. The fix is to **explode** it: split
the string into an array (`STRING_TO_ARRAY`), then turn the array into one row per
element (`UNNEST`). Once every skill is its own row, both questions become ordinary
`GROUP BY` aggregations.

## Problem Answer & Explanation

```sql
WITH exploded AS (
    SELECT
        candidate_id,
        candidate_name,
        TRIM(skill) AS skill
    FROM candidates,
         UNNEST(STRING_TO_ARRAY(skills, ',')) AS skill
)
-- 1. Most in-demand skills
SELECT skill, COUNT(*) AS candidate_count
FROM exploded
GROUP BY skill
ORDER BY candidate_count DESC, skill;
```

```sql
-- 2. Skills per candidate (same exploded CTE, different aggregation)
SELECT candidate_name, COUNT(*) AS skill_count
FROM exploded
GROUP BY candidate_name
ORDER BY skill_count DESC, candidate_name;
```

**Why it works**

1. `STRING_TO_ARRAY(skills, ',')` turns `'SQL,Python,Excel'` into the array
   `{SQL,Python,Excel}`.
2. `UNNEST(...)` in the `FROM` clause (a **lateral** cross join, implicit in Postgres
   when a set-returning function appears there) expands that array into one row per
   element, automatically repeating `candidate_id`/`candidate_name` for each one — this
   is the SQL equivalent of Python's `explode()`/`flatMap`.
3. `TRIM()` guards against stray whitespace if the source data has `'SQL, Python'`
   with a space after the comma.
4. Because the explode happens once in the `exploded` CTE, both aggregations reuse it
   — no need to repeat the `UNNEST` logic per question.

**Interview follow-up:** ask how this differs on MySQL/Snowflake, which don't have
`STRING_TO_ARRAY`/`UNNEST` in the same form — MySQL needs a numbers-table join with
`SUBSTRING_INDEX`, while Snowflake uses `SPLIT` + `FLATTEN`. The *concept* (turn a
delimited string into rows before aggregating) is portable even when the exact
functions aren't.
