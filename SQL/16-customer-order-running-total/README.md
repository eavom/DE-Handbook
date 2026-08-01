# Customer Order Running Total & Tier Crossing

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Window Functions](https://img.shields.io/badge/-Window%20Functions-8E44AD?style=flat-square) ![Running Total](https://img.shields.io/badge/-Running%20Total-8E44AD?style=flat-square) ![LAG](https://img.shields.io/badge/-LAG-8E44AD?style=flat-square)

## Problem Statement

Given a customer's orders over time, compute a running total of order amount per
customer, and label each order with the loyalty tier that running total falls into
(`Bronze` under 5,000, `Silver` from 5,000, `Gold` from 10,000). Then, separately,
identify the exact order at which each customer **first** crossed into `Silver` and
`Gold`.

## Problem Dataset

```sql
CREATE TABLE orders16 (
    customer_id INT,
    order_date  DATE,
    amount      NUMERIC
);

INSERT INTO orders16 VALUES
(1, '2025-01-05', 2000),
(1, '2025-02-10', 2500),
(1, '2025-03-11', 1200),
(1, '2025-04-02', 4500),
(2, '2025-01-20', 6000),
(2, '2025-03-15', 3000),
(2, '2025-05-01', 2500);
```

Expected output (part 1 — running total + tier):

| customer_id | order_date  | amount | running_total | tier_after_order |
|-------------|--------------|---------|------------------|---------------------|
| 1           | 2025-01-05   | 2000    | 2000             | Bronze              |
| 1           | 2025-02-10   | 2500    | 4500             | Bronze              |
| 1           | 2025-03-11   | 1200    | 5700             | Silver              |
| 1           | 2025-04-02   | 4500    | 10200            | Gold                |
| 2           | 2025-01-20   | 6000    | 6000             | Silver              |
| 2           | 2025-03-15   | 3000    | 9000             | Silver              |
| 2           | 2025-05-01   | 2500    | 11500            | Gold                |

Expected output (part 2 — first crossing per tier):

| customer_id | order_date  | running_total | tier_crossed |
|-------------|--------------|------------------|-----------------|
| 1           | 2025-03-11   | 5700             | Silver           |
| 1           | 2025-04-02   | 10200            | Gold             |
| 2           | 2025-01-20   | 6000             | Silver           |
| 2           | 2025-05-01   | 11500            | Gold             |

## Problem Explanation

Part 1 is the standard partitioned running total (`SUM() OVER (PARTITION BY ... ORDER
BY ...)`), the same core pattern as [Running Sum, Next, Prev](../02-running-sum-next-prev/README.md)
and [Employee Referral Running Total](../08-employee-referral-running-total/README.md).
Part 2 is a step harder: "the order where it *first* crossed" means comparing each
row's running total against the *previous* row's running total — which means running
`LAG()` on a value that is itself the output of a window function. Postgres won't let
you nest one window function directly inside another, so that comparison has to happen
in a second pass over a CTE that already has the running total computed.

## Problem Answer & Explanation

**1. Running total + tier label**

```sql
WITH running AS (
    SELECT
        customer_id,
        order_date,
        amount,
        SUM(amount) OVER (
            PARTITION BY customer_id ORDER BY order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_total
    FROM orders16
)
SELECT
    customer_id, order_date, amount, running_total,
    CASE
        WHEN running_total >= 10000 THEN 'Gold'
        WHEN running_total >= 5000  THEN 'Silver'
        ELSE 'Bronze'
    END AS tier_after_order
FROM running
ORDER BY customer_id, order_date;
```

**2. First order that crossed each tier**

```sql
WITH running AS (
    SELECT
        customer_id, order_date, amount,
        SUM(amount) OVER (PARTITION BY customer_id ORDER BY order_date
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
    FROM orders16
),
with_prev AS (
    SELECT *,
           LAG(running_total) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_total
    FROM running
)
SELECT customer_id, order_date, running_total, 'Silver' AS tier_crossed
FROM with_prev
WHERE running_total >= 5000 AND COALESCE(prev_total, 0) < 5000
UNION ALL
SELECT customer_id, order_date, running_total, 'Gold'
FROM with_prev
WHERE running_total >= 10000 AND COALESCE(prev_total, 0) < 10000
ORDER BY customer_id, order_date;
```

**Why it works**

1. `running` computes the cumulative spend once, using the explicit
   `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` frame (same reasoning as the
   referral running-total problem: explicit beats relying on the implicit default).
2. Trying to write `LAG(SUM(amount) OVER (...)) OVER (...)` directly throws `window
   function calls cannot be nested` — Postgres requires the inner window function's
   result to already exist as a plain column before a second window function can read
   it. That's why `with_prev` is a separate CTE layered on top of `running`, rather
   than one combined `SELECT`.
3. "First crossed Silver" means: this row's running total is `>= 5000` **and** the
   previous row's running total was `< 5000`. `COALESCE(prev_total, 0)` handles a
   customer's very first order, where `prev_total` is `NULL` (treated as `0`, i.e.
   "hadn't started").
4. The two tiers are computed as separate `WHERE` clauses combined with `UNION ALL`
   rather than one query, since a single order could theoretically satisfy both
   conditions in the same row (a huge first order jumping straight to Gold) and both
   crossings should be reported.

**Interview follow-up:** ask what happens if a single order is large enough to jump a
customer from Bronze straight to Gold, skipping Silver entirely — walk through the
`UNION ALL` and confirm it still reports *both* the Silver and Gold crossing on that
same order (correct, since both `WHERE` conditions are independently true for that
row), which is arguably more useful than only reporting the highest tier reached.
