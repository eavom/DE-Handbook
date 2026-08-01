# Employee Referral — Running Total & Latest Referral

## Problem Statement

Given a log of employee referral bonuses paid over time, compute:

1. A **running total** of referral bonus per employee, ordered by referral date.
2. Each employee's **latest** referral (by date), along with how many referrals
   they've received in total.

## Problem Dataset

```sql
CREATE TABLE employee_referral (
    employee_id    INT,
    referral_bonus NUMERIC,
    referral_date  DATE
);

INSERT INTO employee_referral VALUES
(1,  300, '2021-01-31'),
(1,  400, '2021-02-28'),
(1,  200, '2021-03-31'),
(1,  400, '2022-01-01'),
(1,  100, '2022-02-05'),
(2, 1000, '2021-10-31'),
(2,  200, '2021-11-08'),
(2,  900, '2021-12-31');
```

Expected output (part 1):

| employee_id | referral_bonus | referral_date | running_referral_bonus |
|-------------|-----------------|----------------|--------------------------|
| 1           | 300             | 2021-01-31     | 300                      |
| 1           | 400             | 2021-02-28     | 700                      |
| 1           | 200             | 2021-03-31     | 900                      |
| 1           | 400             | 2022-01-01     | 1300                     |
| 1           | 100             | 2022-02-05     | 1400                     |
| 2           | 1000            | 2021-10-31     | 1000                     |
| 2           | 200             | 2021-11-08     | 1200                     |
| 2           | 900             | 2021-12-31     | 2100                     |

## Problem Explanation

Part 1 is a **partitioned running total** — the same `SUM() OVER (ORDER BY ...)`
pattern from [Running Sum, Next, Prev](../02-running-sum-next-prev/README.md), just
scoped per employee with `PARTITION BY`. Part 2 combines a partitioned `ROW_NUMBER()`
(to pick the latest row per employee) with a partitioned `COUNT()` (to get the total
number of referrals) in the same pass.

## Problem Answer & Explanation

**1. Running total per employee**

```sql
SELECT
    employee_id,
    referral_bonus,
    referral_date,
    SUM(referral_bonus) OVER (
        PARTITION BY employee_id ORDER BY referral_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_referral_bonus
FROM employee_referral
ORDER BY employee_id, referral_date;
```

**2. Latest referral + total referral count per employee**

```sql
SELECT employee_id, referral_bonus AS latest_referral_bonus, referral_date AS latest_referral_date,
       total_referrals
FROM (
    SELECT
        employee_id,
        referral_bonus,
        referral_date,
        ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY referral_date DESC) AS rn,
        COUNT(*)     OVER (PARTITION BY employee_id) AS total_referrals
    FROM employee_referral
) ranked
WHERE rn = 1;
```

**Why it works**

- `PARTITION BY employee_id` restarts the window calculation for each employee, so
  employee 2's running total doesn't carry over employee 1's total.
- `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` makes the running-total frame
  explicit (equivalent to the default frame when `ORDER BY` is present, but spelling
  it out avoids surprises if the query is later changed to use `RANGE`, which behaves
  differently with tied `ORDER BY` values).
- In part 2, `ROW_NUMBER() ... ORDER BY referral_date DESC` ranks each employee's most
  recent referral as `1`; filtering `rn = 1` keeps just that row. `COUNT(*) OVER
  (PARTITION BY employee_id)` — with **no** `ORDER BY` — counts all rows in the
  partition (not a running count), giving the total referrals for that employee
  attached to every one of their rows, including the one that survives the filter.

**Interview follow-up:** ask what changes if two referrals for the same employee land
on the exact same date — `ROW_NUMBER()` would arbitrarily break the tie; if "latest"
needs a documented tiebreaker (e.g. highest bonus, or highest surrogate key), add it
as a second `ORDER BY` column inside the same window.
