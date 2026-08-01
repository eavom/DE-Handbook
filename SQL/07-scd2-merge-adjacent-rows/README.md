# SCD Type 2 — Merge Adjacent Duplicate Rows

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) ![LAG](https://img.shields.io/badge/-LAG-8E44AD?style=flat-square) ![Running Total](https://img.shields.io/badge/-Running%20Total-8E44AD?style=flat-square) ![SCD Type 2](https://img.shields.io/badge/-SCD%20Type%202-8B0000?style=flat-square)

## Problem Statement

A Type-2 slowly changing dimension table has one row per attribute-change period per
`client_id`, with `start_date`/`end_date` validity ranges. Due to an upstream bug, some
consecutive rows for the same client have **identical attribute values**
(`client_name`, `address`) but were still split into separate rows. Collapse each run
of consecutive, adjacent, identical rows into a single row spanning the full period.

## Problem Dataset

```sql
CREATE TABLE client_scd (
    surrogate_key INT,
    client_id     INT,
    client_name   VARCHAR(50),
    address       VARCHAR(50),
    start_date    DATE,
    end_date      DATE
);

INSERT INTO client_scd VALUES
(1,  101, 'Alice Smith',   'NY',            '2022-01-01', '2023-01-01'),
(2,  101, 'Alice Smith',   'NY',            '2023-01-01', '2024-01-01'),
(3,  101, 'Alice Smith',   'Boston',        '2024-01-01', '2025-01-01'),
(4,  101, 'Alice Johnson', 'Boston',        '2025-01-01', '9999-12-31'),
(5,  102, 'Bob Martin',    'Chicago',       '2019-05-10', '2020-05-10'),
(6,  102, 'Bob Martin',    'Chicago',       '2020-05-10', '2021-05-10'),
(7,  102, 'Bob Martin',    'NY',            '2021-05-10', '2022-05-10'),
(8,  102, 'Bob Martin',    'Chicago',       '2022-05-10', '2023-05-10'),
(9,  102, 'Bob Martin',    'Chicago',       '2023-05-10', '2024-05-10'),
(10, 102, 'Bob Martin',    'Chicago',       '2024-05-10', '2025-05-10'),
(11, 102, 'Bob Martin',    'San Francisco', '2025-05-10', '9999-12-31'),
(12, 103, 'Clara Brown',   'Seattle',       '2023-03-15', '2024-03-15'),
(13, 103, 'Clara Brown',   'Seattle',       '2024-03-15', '2025-03-15'),
(14, 103, 'Clara Brown',   'Seattle',       '2025-03-18', '2025-08-01'),
(15, 103, 'Clara Brown',   'Seattle',       '2025-08-01', '9999-12-31');
```

Expected output:

| client_id | client_name   | address       | start_date | end_date   |
|-----------|---------------|---------------|------------|------------|
| 101       | Alice Smith   | NY            | 2022-01-01 | 2024-01-01 |
| 101       | Alice Smith   | Boston        | 2024-01-01 | 2025-01-01 |
| 101       | Alice Johnson | Boston        | 2025-01-01 | 9999-12-31 |
| 102       | Bob Martin    | Chicago       | 2019-05-10 | 2021-05-10 |
| 102       | Bob Martin    | NY            | 2021-05-10 | 2022-05-10 |
| 102       | Bob Martin    | Chicago       | 2022-05-10 | 2025-05-10 |
| 102       | Bob Martin    | San Francisco | 2025-05-10 | 9999-12-31 |
| 103       | Clara Brown   | Seattle       | 2023-03-15 | 2025-03-15 |
| 103       | Clara Brown   | Seattle       | 2025-03-18 | 9999-12-31 |

Note client 103's rows 13 and 14 are **not** merged even though both have identical
attributes — `end_date` of row 13 (`2025-03-15`) doesn't match `start_date` of row 14
(`2025-03-18`), so they aren't *adjacent* (there's a 3-day gap where the client had no
active row). Only value-identical **and** date-adjacent rows merge.

## Problem Explanation

This is gaps-and-islands again, but the island boundary condition is different from
the earlier problems: instead of "date jumped by more than 1 unit", the break
condition here is **"attributes changed from the previous row, OR the previous row's
`end_date` doesn't equal this row's `start_date`"**. Either condition starts a new
island. `LAG()` is the natural tool to compare each row to the one immediately before
it (in client + start_date order).

## Problem Answer & Explanation

```sql
WITH flagged AS (
    SELECT
        *,
        CASE
            WHEN client_name = LAG(client_name) OVER w
             AND address     = LAG(address)     OVER w
             AND start_date  = LAG(end_date)     OVER w
            THEN 0 ELSE 1
        END AS is_new_group
    FROM client_scd
    WINDOW w AS (PARTITION BY client_id ORDER BY start_date)
),
grouped AS (
    SELECT
        *,
        SUM(is_new_group) OVER (PARTITION BY client_id ORDER BY start_date) AS group_id
    FROM flagged
)
SELECT
    client_id,
    client_name,
    address,
    MIN(start_date) AS start_date,
    MAX(end_date)   AS end_date
FROM grouped
GROUP BY client_id, group_id, client_name, address
ORDER BY client_id, start_date;
```

**Why it works**

1. `is_new_group` compares each row to its immediate predecessor (`LAG` in
   `client_id, start_date` order): it's `0` only when the attributes are unchanged
   **and** the previous row's `end_date` exactly abuts this row's `start_date`. Any
   attribute change, or any gap/overlap in the dates, flags a new group (`1`).
2. A running `SUM(is_new_group)` turns those 0/1 flags into a monotonically
   increasing **group id** — every row in one mergeable run shares the same
   `group_id`, and it increments each time a break is flagged. This is the general
   form of the "constant value inside an island" trick from the date/desk problems,
   just driven by a boolean flag instead of an arithmetic difference.
3. Grouping by `(client_id, group_id, client_name, address)` collapses each run into
   one row; `MIN(start_date)`/`MAX(end_date)` gives the merged validity range.
4. Because client 103's rows 13-14 have a date gap, `is_new_group` is `1` for row 14
   even though the attributes match — correctly keeping them as separate rows.

**Interview follow-up:** this pattern — "collapse consecutive rows where nothing
meaningful changed" — is one of the most common real-world SCD2 cleanup tasks (it
happens whenever an upstream CDC feed emits a row on every load even when nothing
changed). Ask whether the fix should happen here in a query, or upstream in the
CDC/merge logic that writes the SCD table in the first place.
