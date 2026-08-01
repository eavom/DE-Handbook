# Salary History — Previous Value & Review Gaps

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![LAG](https://img.shields.io/badge/-LAG-8E44AD?style=flat-square) ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square)

## Problem Statement

Given a salary revision history (one row per employee per pay change), for every row
show the previous salary, the change in salary since that previous revision, and how
many days elapsed since the last revision. Flag any revision that came more than a
year (365 days) after the previous one as `Stale (>1yr gap)`.

## Problem Dataset

```sql
CREATE TABLE salary_history (
    emp_id         INT,
    effective_date DATE,
    salary         NUMERIC
);

INSERT INTO salary_history VALUES
(1, '2021-01-01', 60000),
(1, '2022-01-01', 66000),
(1, '2023-06-01', 72000),
(1, '2025-01-01', 80000),
(2, '2021-03-01', 55000),
(2, '2022-03-01', 60000),
(2, '2023-03-01', 65000),
(3, '2020-06-01', 70000),
(3, '2024-06-01', 90000);
```

Expected output:

| emp_id | effective_date | salary | prev_salary | salary_change | prev_effective_date | days_since_last_change | review_status     |
|--------|-----------------|--------|--------------|-----------------|------------------------|----------------------------|---------------------|
| 1      | 2021-01-01      | 60000  | NULL         | NULL            | NULL                   | NULL                        | Normal              |
| 1      | 2022-01-01      | 66000  | 60000        | 6000            | 2021-01-01             | 365                         | Normal              |
| 1      | 2023-06-01      | 72000  | 66000        | 6000            | 2022-01-01             | 516                         | Stale (>1yr gap)    |
| 1      | 2025-01-01      | 80000  | 72000        | 8000            | 2023-06-01             | 580                         | Stale (>1yr gap)    |
| 2      | 2021-03-01      | 55000  | NULL         | NULL            | NULL                   | NULL                        | Normal              |
| 2      | 2022-03-01      | 60000  | 55000        | 5000            | 2021-03-01             | 365                         | Normal              |
| 2      | 2023-03-01      | 65000  | 60000        | 5000            | 2022-03-01             | 365                         | Normal              |
| 3      | 2020-06-01      | 70000  | NULL         | NULL            | NULL                   | NULL                        | Normal              |
| 3      | 2024-06-01      | 90000  | 70000        | 20000           | 2020-06-01             | 1461                        | Stale (>1yr gap)    |

Employee 1's third revision (2023-06-01) is flagged because it's 516 days after the
prior one; employee 2 never goes stale since every gap is exactly 365 days (not
*greater than* 365).

## Problem Explanation

This is the `LAG()` counterpart to a running total: instead of accumulating a value,
you're comparing each row directly to the one before it. Getting the previous salary,
the previous date, and the day-gap between them are all the same `LAG()` pattern
applied to different columns of the same window — one `PARTITION BY emp_id ORDER BY
effective_date` window serves every comparison.

## Problem Answer & Explanation

```sql
SELECT
    emp_id,
    effective_date,
    salary,
    LAG(salary) OVER w          AS prev_salary,
    salary - LAG(salary) OVER w AS salary_change,
    LAG(effective_date) OVER w  AS prev_effective_date,
    effective_date - LAG(effective_date) OVER w AS days_since_last_change,
    CASE
        WHEN LAG(effective_date) OVER w IS NOT NULL
         AND effective_date - LAG(effective_date) OVER w > 365
        THEN 'Stale (>1yr gap)'
        ELSE 'Normal'
    END AS review_status
FROM salary_history
WINDOW w AS (PARTITION BY emp_id ORDER BY effective_date)
ORDER BY emp_id, effective_date;
```

**Why it works**

1. The named `WINDOW w AS (...)` clause defines the partition/order once and reuses it
   across five separate `LAG()` calls — avoids repeating the same `OVER (...)` five
   times and keeps them guaranteed-consistent.
2. `effective_date - LAG(effective_date) OVER w` on two `DATE` columns returns an
   integer day count directly in Postgres — no need to cast to `INTERVAL` first.
3. The `CASE` guards on `LAG(effective_date) OVER w IS NOT NULL` before comparing —
   without that guard, the first revision of each employee (which has no previous row)
   would evaluate `NULL > 365`, which is `NULL`/unknown, not `TRUE`, so it would
   silently fall through to `'Normal'` anyway; the explicit check just makes the intent
   readable rather than relying on `NULL` propagation.

**Interview follow-up:** ask how this changes if you need the gap measured against the
employee's *first* revision instead of the *previous* one — swap `LAG(...) OVER w` for
`FIRST_VALUE(...) OVER w` (same window), since `FIRST_VALUE` always returns the
partition's first row regardless of how many rows precede the current one.
