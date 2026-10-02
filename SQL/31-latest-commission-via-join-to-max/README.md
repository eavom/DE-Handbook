# Latest Commission via Join-to-Max

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![JOIN](https://img.shields.io/badge/-JOIN-16A085?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square)

> Adapted from `Scenerio10.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a monthly commission log per employee, return each employee's **most recent**
commission record (amount and date).

## Problem Dataset

```sql
CREATE TABLE commissions (
    emp_id         INT,
    commission_amt NUMERIC,
    month_end_date DATE
);

INSERT INTO commissions VALUES
(1, 300, '2021-01-31'),
(1, 400, '2021-02-28'),
(1, 200, '2021-03-31'),
(2, 1000, '2021-10-31'),
(2, 900, '2021-12-31');
```

Expected output:

| emp_id | commission_amt | month_end_date |
|--------|-------------------|-------------------|
| 1      | 200               | 2021-03-31        |
| 2      | 900               | 2021-12-31        |

## Problem Explanation

This is the same "latest row per group" question answered elsewhere in this repo with
`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ... DESC) WHERE rn = 1` (see
[Employee Referral Running Total](../08-employee-referral-running-total/README.md)).
This version deliberately uses a **different, older technique** to reach the same
answer: aggregate to find each group's max date first, then join back to the original
table on both the group key and that max date. It's worth knowing both approaches —
this join-to-max pattern predates window functions and still shows up constantly in
codebases and interview answers, especially from engineers who learned SQL before
window functions were widely supported.

## Problem Answer & Explanation

```sql
WITH latest_month AS (
    SELECT emp_id, MAX(month_end_date) AS max_date
    FROM commissions
    GROUP BY emp_id
)
SELECT c.emp_id, c.commission_amt, c.month_end_date
FROM commissions c
JOIN latest_month lm
  ON c.emp_id = lm.emp_id AND c.month_end_date = lm.max_date
ORDER BY c.emp_id;
```

**Why it works**

1. `latest_month` computes, per employee, the single latest `month_end_date` — a
   simple `GROUP BY` + `MAX()` rollup.
2. Joining `commissions` back to `latest_month` on **both** `emp_id` and
   `month_end_date = max_date` filters each employee's rows down to just the one that
   matches their own latest date — the join condition does the filtering that a
   `WHERE rn = 1` clause does in the window-function version.
3. This approach has a real weakness the window-function version doesn't: if two rows
   for the same employee share the exact same `month_end_date` (a tie), **both** would
   match the join and both would appear in the output — there's no equivalent of
   `ROW_NUMBER()`'s automatic single-row tiebreak. A window function with an explicit
   secondary `ORDER BY` column is the more robust choice whenever ties are possible.

**Interview follow-up:** ask the candidate to state, out loud, when they'd reach for
this join-to-max pattern over a window function, and when they wouldn't. A reasonable
answer: it's fine (and sometimes clearer to a mixed-skill-level team) for a single
"latest per group" lookup with no tie risk; a window function is the safer default
once ties are possible, once multiple "latest N" rows are needed instead of just one,
or once several different rankings are needed from the same base query — see
[Employee Salary by Department](../10-employee-salary-by-department/README.md) for
why `RANK()` generalizes better than a `MAX()`-based approach in exactly that
situation.
