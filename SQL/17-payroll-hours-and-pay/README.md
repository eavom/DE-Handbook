# Payroll — Weekly Hours & Overtime Pay

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square) ![Conditional Aggregation (CASE/FILTER)](https://img.shields.io/badge/-Conditional%20Aggregation%20%28CASE%2FFILTER%29-27AE60?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square)

## Problem Statement

Given daily timesheet entries, compute each employee's **weekly** pay. The first 40
hours in a calendar week are paid at the normal hourly rate; anything beyond 40 hours
that same week is paid at 1.5x (overtime).

## Problem Dataset

```sql
CREATE TABLE timesheets (
    employee_id  INT,
    work_date    DATE,
    hours_worked NUMERIC,
    hourly_rate  NUMERIC
);

INSERT INTO timesheets VALUES
(1, '2025-06-02', 9, 20), (1, '2025-06-03', 9, 20), (1, '2025-06-04', 9, 20),
(1, '2025-06-05', 9, 20), (1, '2025-06-06', 9, 20),          -- week of Jun 2: 45 hrs
(1, '2025-06-09', 8, 20), (1, '2025-06-10', 8, 20), (1, '2025-06-11', 8, 20),
(1, '2025-06-12', 8, 20), (1, '2025-06-13', 8, 20),          -- week of Jun 9: 40 hrs
(2, '2025-06-02', 6, 25), (2, '2025-06-03', 6, 25), (2, '2025-06-04', 6, 25),
(2, '2025-06-05', 6, 25), (2, '2025-06-06', 6, 25);          -- week of Jun 2: 30 hrs
```

Expected output:

| employee_id | week_start | total_hours | regular_hours | overtime_hours | weekly_pay |
|-------------|-------------|---------------|------------------|-------------------|--------------|
| 1           | 2025-06-02  | 45            | 40               | 5                 | 950.0        |
| 1           | 2025-06-09  | 40            | 40               | 0                 | 800.0        |
| 2           | 2025-06-02  | 30            | 30               | 0                 | 750.0        |

Employee 1's first week: 40 hours × 20 + 5 overtime hours × 20 × 1.5 = 800 + 150 =
950. Employee 2 never hits 40, so no overtime applies.

## Problem Explanation

Two ideas stack here: bucketing daily rows into calendar weeks (`DATE_TRUNC('week',
...)`), and splitting a total into "regular" vs "overtime" once you know the weekly
sum — which can't be decided per-row, only after the days are rolled up. The clean way
to split a number at a threshold without `CASE` gymnastics is `LEAST`/`GREATEST`:
`LEAST(total, 40)` caps at 40, and `GREATEST(total - 40, 0)` floors the overflow at 0.

## Problem Answer & Explanation

```sql
WITH weekly AS (
    SELECT
        employee_id,
        DATE_TRUNC('week', work_date)::DATE AS week_start,
        SUM(hours_worked)                    AS total_hours,
        MAX(hourly_rate)                     AS hourly_rate
    FROM timesheets
    GROUP BY employee_id, DATE_TRUNC('week', work_date)
)
SELECT
    employee_id,
    week_start,
    total_hours,
    LEAST(total_hours, 40)        AS regular_hours,
    GREATEST(total_hours - 40, 0) AS overtime_hours,
    LEAST(total_hours, 40) * hourly_rate
      + GREATEST(total_hours - 40, 0) * hourly_rate * 1.5 AS weekly_pay
FROM weekly
ORDER BY employee_id, week_start;
```

**Why it works**

1. `DATE_TRUNC('week', work_date)` collapses every date to the Monday that starts its
   ISO calendar week, so `GROUP BY employee_id, DATE_TRUNC('week', work_date)` rolls
   up all of one employee's days within the same week into a single row.
2. `MAX(hourly_rate)` in the rollup is a "pick any value, they're all the same"
   aggregate — it's not really a max in the mathematical sense, it's just how you
   carry a per-employee constant through a `GROUP BY` that would otherwise force you
   to repeat it in the grouping key.
3. `LEAST(total_hours, 40)` and `GREATEST(total_hours - 40, 0)` split `total_hours`
   into two non-overlapping, non-negative pieces that always sum back to
   `total_hours` — equivalent to but shorter than a two-branch `CASE`.
4. The rates differ (1x vs 1.5x) so the split has to happen before multiplying by
   `hourly_rate`, not after — computing `total_hours * hourly_rate` first and trying
   to patch in overtime afterward would double-count the base pay on the overtime
   hours.

**Interview follow-up:** ask what changes if overtime rules are *daily* (any hours
over 8 in a single day) instead of weekly — the `GROUP BY` disappears entirely, since
each day is now independently evaluated: `LEAST(hours_worked, 8)` and
`GREATEST(hours_worked - 8, 0)` per row, no aggregation needed.
