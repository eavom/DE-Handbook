# Consecutive Free Desks — Best Fit

## Problem Statement

A desk allocation table marks each desk with an `is_free` flag (`X` = free, blank =
already allocated) within a `row_number` (physical row of desks). Three team members
need to sit together, so find **3 consecutive free desks in the same row**. If more
than one row qualifies, prefer the **tightest fit** — the smallest contiguous free
block that's still big enough — so seats aren't wasted.

## Problem Dataset

```sql
CREATE TABLE desk_allocation (
    desk_id     VARCHAR(10),
    row_number  INT,
    is_free     CHAR(1)   -- 'X' = free, NULL = allocated
);

INSERT INTO desk_allocation VALUES
('SURF001', 1, NULL), ('SURF002', 1, 'X'), ('SURF003', 1, 'X'), ('SURF004', 1, 'X'), ('SURF005', 1, 'X'),
('SURF006', 2, 'X'),  ('SURF007', 2, NULL),('SURF008', 2, 'X'), ('SURF009', 2, NULL),('SURF010', 2, NULL),
('SURF011', 3, 'X'),  ('SURF012', 3, NULL),('SURF013', 3, 'X'), ('SURF014', 3, 'X'), ('SURF015', 3, 'X');
```

Expected output:

| desk_id |
|---------|
| SURF013 |
| SURF014 |
| SURF015 |

Row 1 has a free block of 4 desks (`SURF002-005`) — big enough, but wastes a seat.
Row 2's free desks are isolated (no 3 in a row). Row 3's free block (`SURF013-015`) is
exactly 3 desks — the best fit.

## Problem Explanation

Same **gaps-and-islands** technique as consecutive-day streaks, applied to a
`desk_id` sequence instead of dates: subtract a row-number sequence (computed only
over the free desks) from the desk's own position to get a constant "island key" for
each unbroken run of free desks. Then it becomes a two-step filter: keep islands of
length >= 3, and among those, pick the smallest one (least wasted capacity).

## Problem Answer & Explanation

```sql
WITH free_desks AS (
    SELECT
        desk_id,
        row_number,
        ROW_NUMBER() OVER (ORDER BY row_number, desk_id) AS overall_seq,
        ROW_NUMBER() OVER (PARTITION BY row_number ORDER BY desk_id) AS row_seq
    FROM desk_allocation
    WHERE is_free = 'X'
),
islands AS (
    SELECT
        row_number,
        overall_seq - row_seq AS island_group,   -- constant within one unbroken run
        MIN(desk_id) AS first_desk,
        MAX(desk_id) AS last_desk,
        COUNT(*)     AS block_size,
        ARRAY_AGG(desk_id ORDER BY desk_id) AS desk_ids
    FROM free_desks
    GROUP BY row_number, overall_seq - row_seq
)
SELECT unnest(desk_ids) AS desk_id
FROM islands
WHERE block_size >= 3
ORDER BY block_size ASC   -- tightest fit first
LIMIT 1;
```

**Why it works**

1. `free_desks` filters to only free desks, then numbers them twice: `overall_seq`
   (global order) and `row_seq` (order restarted per row). Their difference is stable
   only for desks that are physically adjacent *and* free — a subtle but important
   detail: because `row_seq` restarts at each `row_number`, the difference
   automatically breaks between rows without needing a separate per-row reset step.
2. Grouping by `(row_number, island_group)` collapses each unbroken run of free desks
   into one row with its size (`block_size`) and member desk IDs.
3. `WHERE block_size >= 3` keeps only rows with enough contiguous capacity.
4. `ORDER BY block_size ASC LIMIT 1` picks the **smallest sufficient block** — the
   "best fit" — instead of just the first one found; without this a naive query would
   wrongly prefer row 1's 4-desk block over row 3's exact 3-desk match.

**Interview follow-up:** ask how this generalizes to "seat groups of size N" — the
query is unchanged except the `WHERE block_size >= N` threshold, which is why solving
it with the general island-size pattern (rather than hardcoding "3") pays off.
