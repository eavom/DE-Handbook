# Banking Customer Category

## Problem Statement

Given a bank's transaction log for a set of customers, classify every customer into a
category based on their **net balance** (total deposits minus total withdrawals):

- `Premium Customer` — net balance >= 30,000
- `Gold Customer` — net balance >= 15,000 and < 30,000
- `Other Customer` — net balance < 15,000

Write a query that returns one row per customer with their computed category.

## Problem Dataset

```sql
CREATE TABLE transactions (
    customer_id      INT,
    transaction_date DATE,
    transaction_type VARCHAR(10),   -- 'deposit' | 'withdrawal'
    amount            NUMERIC
);

INSERT INTO transactions VALUES
(1, '2025-09-01', 'deposit',    12000),
(1, '2025-09-02', 'deposit',    15000),
(1, '2025-09-03', 'deposit',    11000),
(1, '2025-09-04', 'withdrawal',  5000),
(2, '2025-09-01', 'deposit',     6000),
(2, '2025-09-02', 'deposit',     7000),
(2, '2025-09-03', 'deposit',     6500),
(2, '2025-09-04', 'withdrawal',  2000),
(3, '2025-09-01', 'deposit',     3000),
(3, '2025-09-03', 'deposit',     4000),
(3, '2025-09-04', 'withdrawal',  1000);
```

Expected output:

| customer_id | customer_category |
|-------------|--------------------|
| 1           | Premium Customer   |
| 2           | Gold Customer      |
| 3           | Other Customer     |

## Problem Explanation

This is a classic **conditional aggregation** problem: collapse many transaction rows
into one summary row per customer, then bucket that summary with a `CASE` expression.
The trick people miss is computing "net balance" in a single pass instead of two
separate aggregates joined together — `SUM` with a signed `CASE` (or `FILTER`) does
both the deposit/withdrawal split and the subtraction at once.

Customer totals:

| customer_id | deposits | withdrawals | net balance |
|-------------|----------|-------------|-------------|
| 1           | 38,000   | 5,000       | 33,000      |
| 2           | 19,500   | 2,000       | 17,500      |
| 3           | 7,000    | 1,000       | 6,000       |

## Problem Answer & Explanation

```sql
WITH customer_totals AS (
    SELECT
        customer_id,
        SUM(CASE WHEN transaction_type = 'deposit'    THEN amount ELSE 0 END)
          - SUM(CASE WHEN transaction_type = 'withdrawal' THEN amount ELSE 0 END)
          AS net_balance
    FROM transactions
    GROUP BY customer_id
)
SELECT
    customer_id,
    CASE
        WHEN net_balance >= 30000 THEN 'Premium Customer'
        WHEN net_balance >= 15000 THEN 'Gold Customer'
        ELSE 'Other Customer'
    END AS customer_category
FROM customer_totals
ORDER BY customer_id;
```

**Why it works**

1. `customer_totals` collapses the transaction log to one row per customer by summing
   deposits and subtracting withdrawals in the same `SUM(CASE ...)` expression — no
   self-join or separate subquery needed for each transaction type.
2. The outer query applies the tiering rule with `CASE`. Because the `WHEN` clauses are
   evaluated top-down, ordering them from the highest threshold down means you don't
   need to repeat the lower bound (e.g. `net_balance >= 15000 AND net_balance < 30000`
   is unnecessary — the first matching branch wins).
3. Postgres/Snowflake also support `FILTER (WHERE ...)` as a more readable alternative
   to `SUM(CASE WHEN ...)`:

```sql
SELECT
    customer_id,
    SUM(amount) FILTER (WHERE transaction_type = 'deposit')
      - SUM(amount) FILTER (WHERE transaction_type = 'withdrawal') AS net_balance
FROM transactions
GROUP BY customer_id;
```

**Interview follow-up:** if thresholds needed to be data-driven (configurable per bank
product) instead of hardcoded, you'd join against a `tier_thresholds` table and pick
the tier with `MAX(threshold) WHERE threshold <= net_balance` instead of `CASE`.
