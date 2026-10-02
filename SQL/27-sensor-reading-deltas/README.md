# Sensor Reading Deltas

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Window Functions](https://img.shields.io/badge/-Window%20Functions-8E44AD?style=flat-square) ![LEAD](https://img.shields.io/badge/-LEAD-8E44AD?style=flat-square)

> Adapted from `Scenerio3.scala` in `interview-scenerios-spark-sql`. The original
> ordered readings by *value* rather than *timestamp* before computing the delta —
> that only produces a meaningful "change over time" if values happen to already be
> sorted chronologically, which is a coincidence, not a guarantee. This version fixes
> that by ordering by `reading_ts`.

## Problem Statement

Given per-sensor readings over time, compute how much each reading changed compared
to the **next** reading (`next_value - current_value`), in chronological order. Drop
the final reading of each sensor, since it has no "next" reading to compare against.

## Problem Dataset

```sql
CREATE TABLE sensor_readings (
    sensor_id     INT,
    reading_ts    TIMESTAMP,
    reading_value NUMERIC
);

INSERT INTO sensor_readings VALUES
(1111, '2025-01-15 08:00', 10),
(1111, '2025-01-16 08:00', 15),
(1111, '2025-01-17 08:00', 30),
(1112, '2025-01-15 08:00', 10),
(1112, '2025-01-15 09:00', 20),
(1112, '2025-01-15 10:00', 30);
```

Expected output:

| sensor_id | reading_ts          | reading_value | delta_to_next |
|-----------|----------------------|-----------------|-----------------|
| 1111      | 2025-01-15 08:00:00  | 10              | 5               |
| 1111      | 2025-01-16 08:00:00  | 15              | 15              |
| 1112      | 2025-01-15 08:00:00  | 10              | 10              |
| 1112      | 2025-01-15 09:00:00  | 20              | 10              |

## Problem Explanation

"Compare this row to the *next* one" is `LEAD()`'s reason for existing — the mirror
image of `LAG()`. Ordering the window by the correct column matters more here than in
most `LEAD`/`LAG` problems: if the window were ordered by `reading_value` instead of
`reading_ts` (an easy mistake when the two happen to correlate in sample data), the
"next" reading would be the next-*largest* value, not the next reading *in time* —
silently wrong for any real sensor stream where values fluctuate.

## Problem Answer & Explanation

```sql
WITH deltas AS (
    SELECT
        sensor_id, reading_ts, reading_value,
        LEAD(reading_value) OVER w - reading_value AS delta_to_next
    FROM sensor_readings
    WINDOW w AS (PARTITION BY sensor_id ORDER BY reading_ts)
)
SELECT sensor_id, reading_ts, reading_value, delta_to_next
FROM deltas
WHERE delta_to_next IS NOT NULL
ORDER BY sensor_id, reading_ts;
```

**Why it works**

1. `PARTITION BY sensor_id ORDER BY reading_ts` is the crux of the fix — sensors are
   compared independently, and readings within a sensor are strictly time-ordered
   before `LEAD` looks ahead.
2. `LEAD(reading_value) OVER w` returns the *next* reading in that time-ordered
   sequence; subtracting the current `reading_value` gives the change *to* that next
   reading.
3. The last reading of each sensor has no next row, so `LEAD` returns `NULL` there —
   filtering `delta_to_next IS NOT NULL` in the outer query drops those trailing rows,
   matching the requirement that every output row represents an actual observed
   change.

**Interview follow-up:** ask what changes if readings can arrive with **duplicate
timestamps** for the same sensor (two readings logged in the same second) — `ORDER BY
reading_ts` alone no longer fully determines row order, so `LEAD` could non-
deterministically pick either duplicate as "next." Fixing that needs a tiebreaker
column added to the `ORDER BY` (e.g. an ingestion sequence number), the same lesson as
the tie-handling follow-up in [Employee Referral Running Total](../08-employee-referral-running-total/README.md).
