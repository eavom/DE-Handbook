# Server Uptime — Longest Streak

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) ![ROW_NUMBER](https://img.shields.io/badge/-ROW__NUMBER-8E44AD?style=flat-square) ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square)

## Problem Statement

Given hourly server health checks (`UP`/`DOWN`), find each server's **single longest**
consecutive streak of `UP` checks. Return the streak's start time, end time, and
length in hours.

## Problem Dataset

```sql
CREATE TABLE server_status (
    server_id  INT,
    check_time TIMESTAMP,
    status     VARCHAR(10)   -- 'UP' | 'DOWN'
);

INSERT INTO server_status VALUES
(1, '2025-01-01 00:00', 'UP'),   (1, '2025-01-01 01:00', 'UP'),
(1, '2025-01-01 02:00', 'DOWN'), (1, '2025-01-01 03:00', 'UP'),
(1, '2025-01-01 04:00', 'UP'),   (1, '2025-01-01 05:00', 'UP'),
(1, '2025-01-01 06:00', 'UP'),   (1, '2025-01-01 07:00', 'DOWN'),
(2, '2025-01-01 00:00', 'UP'),   (2, '2025-01-01 01:00', 'DOWN'),
(2, '2025-01-01 02:00', 'UP'),   (2, '2025-01-01 03:00', 'DOWN');
```

Expected output:

| server_id | streak_start          | streak_end            | streak_hours |
|-----------|-------------------------|--------------------------|-----------------|
| 1         | 2025-01-01 03:00:00     | 2025-01-01 06:00:00      | 4               |
| 2         | 2025-01-01 00:00:00     | 2025-01-01 00:00:00      | 1               |

Server 1 has two `UP` streaks (00:00-01:00, length 2, and 03:00-06:00, length 4) — only
the longer one is returned. Server 2 never has two consecutive `UP` checks, so its
longest streak is a single hour.

## Problem Explanation

This combines two techniques already used separately elsewhere in this set: the
**gaps-and-islands** pattern from [Consecutive Logins](../04-consecutive-logins-streak/README.md)
to find every `UP` streak, plus the **rank-and-filter-to-top-1** pattern from
[Employee Salary by Department](../10-employee-salary-by-department/README.md) to pick
only the single longest one per server. Neither pattern alone answers this question —
gaps-and-islands finds *all* streaks, and you still need a second pass to pick the
best one, same as [Consecutive Free Desks](../05-consecutive-free-desks-best-fit/README.md)
needed an extra selection step on top of its islands.

## Problem Answer & Explanation

```sql
WITH up_checks AS (
    SELECT
        server_id,
        check_time,
        ROW_NUMBER() OVER (PARTITION BY server_id ORDER BY check_time) AS rn
    FROM server_status
    WHERE status = 'UP'
),
islands AS (
    SELECT
        server_id,
        check_time - (rn * INTERVAL '1 hour') AS island_group,
        MIN(check_time) AS streak_start,
        MAX(check_time) AS streak_end,
        COUNT(*)        AS streak_hours
    FROM up_checks
    GROUP BY server_id, check_time - (rn * INTERVAL '1 hour')
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY server_id ORDER BY streak_hours DESC, streak_start) AS rnk
    FROM islands
)
SELECT server_id, streak_start, streak_end, streak_hours
FROM ranked
WHERE rnk = 1
ORDER BY server_id;
```

**Why it works**

1. `up_checks` filters to only `UP` rows and numbers them consecutively per server —
   identical setup to the zero-balance-days problem, just on hourly timestamps instead
   of daily dates.
2. `check_time - rn * 1 hour` is the same island-detection trick scaled to an hourly
   grain instead of daily: constant within one unbroken run of `UP` checks, and it
   jumps whenever a `DOWN` check breaks the sequence.
3. `islands` collapses each run to one row with its length in hours (`streak_hours`).
4. `ranked` uses `ROW_NUMBER()` (not `RANK()`) deliberately here — unlike the
   "top earner" problems, "the single longest streak" should return exactly one row
   per server even if two streaks tie in length; `ROW_NUMBER()` breaks that tie with
   the secondary `ORDER BY streak_start` (earliest streak wins), whereas `RANK()`
   would return both tied streaks.

**Interview follow-up:** ask how you'd handle a data gap — e.g. no health check
recorded at all for a given hour, versus an explicit `DOWN` row — differently. A
missing row is invisible to this query entirely (it only reasons about rows that
exist), so a true "was the server actually up this whole time" answer would need to
first generate a complete expected timeline (e.g. `generate_series`) and `LEFT JOIN`
the actual checks onto it, treating missing rows as `DOWN` (or `UNKNOWN`) before
running the same gaps-and-islands logic.
