# Consecutive Logins With Dates

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) ![ROW_NUMBER](https://img.shields.io/badge/-ROW__NUMBER-8E44AD?style=flat-square) ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square) ![JOIN](https://img.shields.io/badge/-JOIN-16A085?style=flat-square)

## Problem Statement

Given per-user login history, find every streak of **3 or more consecutive calendar
days** a user logged in. Return the user, and the first and last date of each streak
(`login_date` / `logout_date`). A user can have more than one qualifying streak.

## Problem Dataset

```sql
CREATE TABLE users (
    user_id INT,
    name    VARCHAR(50),
    email   VARCHAR(100)
);

INSERT INTO users VALUES
(1, 'Aarti Sharma',     'aarti.sharma@code.code'),
(2, 'Nilesh Chaudhari', 'nilesh.chaudhari@code.code'),
(3, 'Meena Joshi',      'meena.joshi@code.code'),
(4, 'Karan Verma',      'karan.verma@code.code'),
(5, 'Ritu Deshmukh',    'ritu.deshmukh@code.code');

CREATE TABLE login_history (
    user_id    INT,
    login_date DATE
);

INSERT INTO login_history VALUES
(1, '2025-08-10'), (1, '2025-08-11'), (1, '2025-08-12'), (1, '2025-08-14'),
(2, '2025-08-09'), (2, '2025-08-10'), (2, '2025-08-11'), (2, '2025-08-13'),
(3, '2025-08-08'), (3, '2025-08-09'), (3, '2025-08-10'), (3, '2025-08-11'),
(3, '2025-08-15'), (3, '2025-08-16'), (3, '2025-08-17'),
(4, '2025-08-10'), (4, '2025-08-12'),
(5, '2025-08-10'), (5, '2025-08-11'), (5, '2025-08-13');
```

> Note: the source material referenced a "user 3" (Meena Joshi) in its expected output
> without listing her in the `users` sample rows — she's included above so the dataset
> is self-consistent.

Expected output:

| user_id | name             | email                       | login_date | logout_date |
|---------|------------------|------------------------------|------------|-------------|
| 1       | Aarti Sharma     | aarti.sharma@code.code       | 2025-08-10 | 2025-08-12  |
| 2       | Nilesh Chaudhari | nilesh.chaudhari@code.code   | 2025-08-09 | 2025-08-11  |
| 3       | Meena Joshi      | meena.joshi@code.code        | 2025-08-08 | 2025-08-11  |
| 3       | Meena Joshi      | meena.joshi@code.code        | 2025-08-15 | 2025-08-17  |

Users 4 and 5 never have 3 consecutive days, so they're correctly excluded.

## Problem Explanation

This is the textbook **gaps-and-islands** pattern. The trick: subtract a
row-numbering sequence from the actual date. Within an unbroken run of consecutive
dates, `date - ROW_NUMBER()` is *constant*, because both the date and the row number
advance by exactly 1 each day. As soon as there's a gap, the row number keeps
climbing by 1 but the date jumps by more than 1, so the difference changes — which
is exactly the signal that marks the start of a new island.

## Problem Answer & Explanation

```sql
WITH ranked AS (
    SELECT
        user_id,
        login_date,
        login_date - (ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        ) * INTERVAL '1 day') AS island_group
    FROM login_history
),
islands AS (
    SELECT
        user_id,
        MIN(login_date) AS login_date,
        MAX(login_date) AS logout_date,
        COUNT(*)        AS streak_length
    FROM ranked
    GROUP BY user_id, island_group
)
SELECT
    i.user_id,
    u.name,
    u.email,
    i.login_date,
    i.logout_date
FROM islands i
JOIN users u ON u.user_id = i.user_id
WHERE i.streak_length >= 3
ORDER BY i.user_id, i.login_date;
```

**Why it works**

1. `ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date)` gives each user's
   logins a sequential rank (1, 2, 3, ...).
2. `login_date - row_number * 1 day` produces the **same value** for every date inside
   one unbroken run, and a **different value** once a gap breaks the run — that value
   becomes the island's grouping key (`island_group`).
3. Grouping by `(user_id, island_group)` collapses each island to one row, where
   `MIN`/`MAX` give the streak's start/end date and `COUNT(*)` gives its length.
4. The `HAVING`-style filter (`streak_length >= 3`) keeps only qualifying streaks, then
   a join back to `users` attaches the display columns.

**Interview follow-up:** the same `date - row_number` trick works for any "evenly
spaced sequence" island problem — numeric IDs, hourly timestamps, etc. — you just
scale the subtracted unit to match the spacing (see [Server Uptime](../23-server-uptime-longest-streak/README.md) and
[Zero-Balance Islands](../14-gaps-and-islands-zero-balance/README.md) for hour-based
and pure gaps-and-islands variants).
