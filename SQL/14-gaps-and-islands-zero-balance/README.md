# Gaps & Islands — Zero Balance Periods

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) ![ROW_NUMBER](https://img.shields.io/badge/-ROW__NUMBER-8E44AD?style=flat-square) ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square)

## Problem Statement

Given a daily account balance snapshot, find every period where an account's balance
stayed at **exactly zero for 3 or more consecutive days**. Return the account, and the
start/end date of each qualifying zero-balance period.

## Problem Dataset

```sql
CREATE TABLE account_balance (
    account_id   INT,
    balance_date DATE,
    balance      NUMERIC
);

INSERT INTO account_balance VALUES
(1, '2025-01-01', 500),
(1, '2025-01-02', 0),
(1, '2025-01-03', 0),
(1, '2025-01-04', 0),
(1, '2025-01-05', 200),
(1, '2025-01-06', 0),
(1, '2025-01-07', 0),
(2, '2025-01-01', 0),
(2, '2025-01-02', 0),
(2, '2025-01-03', 100),
(2, '2025-01-04', 0),
(2, '2025-01-05', 0),
(2, '2025-01-06', 0),
(2, '2025-01-07', 0);
```

Expected output:

| account_id | zero_start | zero_end   | zero_days |
|------------|-------------|-------------|------------|
| 1          | 2025-01-02  | 2025-01-04  | 3          |
| 2          | 2025-01-04  | 2025-01-07  | 4          |

Account 1's Jan 6-7 zero streak (2 days) is correctly excluded — too short. Account
2's Jan 1-2 zero streak (2 days) is also excluded; only its Jan 4-7 streak (4 days)
qualifies.

## Problem Explanation

This is the same gaps-and-islands technique as the consecutive-logins and
consecutive-desks problems, applied to a value condition (`balance = 0`) instead of a
categorical flag. The key move: filter to only the zero-balance rows *first*, then
apply the `date - ROW_NUMBER()` trick to that filtered set. Non-zero days act as the
"gap" that breaks one island from the next, exactly like a missing calendar day did in
the login-streak problem.

## Problem Answer & Explanation

```sql
WITH zero_days AS (
    SELECT
        account_id,
        balance_date,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY balance_date) AS rn
    FROM account_balance
    WHERE balance = 0
),
islands AS (
    SELECT
        account_id,
        balance_date - (rn * INTERVAL '1 day') AS island_group,
        MIN(balance_date) AS zero_start,
        MAX(balance_date) AS zero_end,
        COUNT(*)          AS zero_days
    FROM zero_days
    GROUP BY account_id, balance_date - (rn * INTERVAL '1 day')
)
SELECT account_id, zero_start, zero_end, zero_days
FROM islands
WHERE zero_days >= 3
ORDER BY account_id, zero_start;
```

**Why it works**

1. `WHERE balance = 0` filters down to only the rows that could ever be part of a
   zero-balance island — non-zero days are dropped before ranking, so they act purely
   as gaps.
2. `ROW_NUMBER()` re-numbers the *filtered* rows consecutively (1, 2, 3, ...) per
   account, ignoring the dates of the non-zero rows that were removed.
3. `balance_date - rn * 1 day` is constant across an unbroken run of zero-balance days
   (both the date and `rn` advance by 1 together), and jumps to a new value whenever a
   non-zero day breaks the sequence — the standard island grouping key.
4. Filtering `zero_days >= 3` after grouping keeps only qualifying islands, same as the
   `HAVING`-style filter in the consecutive-logins problem.

**Interview follow-up:** ask how you'd instead find periods where balance stayed
**below some threshold** (not just exactly zero) — only the `WHERE balance = 0` filter
changes (e.g. `WHERE balance < 100`); the island-detection logic underneath is
identical, which is why this pattern is worth memorizing once rather than per-variant.
