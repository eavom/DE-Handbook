# Event Analysis — Sessionization & Signups

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) ![LAG](https://img.shields.io/badge/-LAG-8E44AD?style=flat-square) ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square)

## Problem Statement

Given a raw event log (page views, clicks, signups) per user, group events into
**sessions**: a new session starts whenever there's a gap of more than 30 minutes
since the user's previous event. For each session, report its start time, end time,
event count, and whether it contains a `signup` event.

## Problem Dataset

```sql
CREATE TABLE events (
    user_id    INT,
    event_time TIMESTAMP,
    event_type VARCHAR(20)
);

INSERT INTO events VALUES
(1, '2025-01-01 09:00:00', 'page_view'),
(1, '2025-01-01 09:05:00', 'page_view'),
(1, '2025-01-01 09:08:00', 'signup'),
(1, '2025-01-01 10:15:00', 'page_view'),
(1, '2025-01-01 10:20:00', 'click'),
(2, '2025-01-01 11:00:00', 'page_view'),
(2, '2025-01-01 11:29:00', 'page_view'),
(2, '2025-01-01 11:31:00', 'signup'),
(2, '2025-01-01 13:00:00', 'page_view');
```

Expected output:

| user_id | session_id | session_start        | session_end          | event_count | has_signup |
|---------|------------|------------------------|------------------------|--------------|-------------|
| 1       | 1          | 2025-01-01 09:00:00    | 2025-01-01 09:08:00    | 3            | true        |
| 1       | 2          | 2025-01-01 10:15:00    | 2025-01-01 10:20:00    | 2            | false       |
| 2       | 1          | 2025-01-01 11:00:00    | 2025-01-01 11:31:00    | 3            | true        |
| 2       | 2          | 2025-01-01 13:00:00    | 2025-01-01 13:00:00    | 1            | false       |

User 1's events at 09:00-09:08 form one session (gaps under 30 min); the next event at
10:15 is 67 minutes later, so it starts a new session. User 2's 11:00 and 11:29 events
are 29 minutes apart — still the same session — but 11:31 to 13:00 is a 89-minute gap.

## Problem Explanation

This is the **gaps-and-islands** pattern applied to timestamps instead of dates: the
"island" is a session, and the break condition is "more than 30 minutes since the
previous event" rather than "date isn't the very next day." The mechanics are the same
as a date-streak problem — flag every row where a break happens, then turn those flags
into a monotonically increasing group id with a running `SUM()`.

## Problem Answer & Explanation

```sql
WITH ordered AS (
    SELECT
        user_id,
        event_time,
        event_type,
        LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event_time
    FROM events
),
flagged AS (
    SELECT
        *,
        CASE
            WHEN prev_event_time IS NULL
              OR event_time - prev_event_time > INTERVAL '30 minutes'
            THEN 1 ELSE 0
        END AS is_new_session
    FROM ordered
),
sessions AS (
    SELECT
        *,
        SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY event_time) AS session_id
    FROM flagged
)
SELECT
    user_id,
    session_id,
    MIN(event_time)                 AS session_start,
    MAX(event_time)                 AS session_end,
    COUNT(*)                        AS event_count,
    BOOL_OR(event_type = 'signup')  AS has_signup
FROM sessions
GROUP BY user_id, session_id
ORDER BY user_id, session_id;
```

**Why it works**

1. `ordered` computes, per user, the previous event's timestamp via `LAG`.
2. `flagged` marks a row `1` (new session) either when it's the very first event for
   that user (`prev_event_time IS NULL`) or when more than 30 minutes passed since the
   last one.
3. A running `SUM(is_new_session)` in `sessions` turns those 0/1 flags into a
   `session_id` that increments only when a real break occurs — the exact same
   "flag then running-sum" trick used for the SCD2 merge problem, just driven by a
   time delta instead of an attribute change.
4. `BOOL_OR(event_type = 'signup')` is the cleanest way to answer "does this group
   contain at least one matching row" — equivalent to
   `MAX(CASE WHEN event_type = 'signup' THEN 1 ELSE 0 END) = 1` on engines without
   `BOOL_OR` (e.g. MySQL).

**Interview follow-up:** ask how the query changes if "session" needs a *maximum*
duration cap too (e.g. force a new session after 2 hours even with no gap) — that
needs a second break condition (`event_time - FIRST_VALUE(event_time) OVER (...) >
INTERVAL '2 hours'`) OR'd into the existing one, since gaps-and-islands supports
compound break conditions the same way the SCD2 problem does.
