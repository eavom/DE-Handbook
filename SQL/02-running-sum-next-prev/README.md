# Running Sum, Next Value, Previous Value

## Problem Statement

Given a simple table of IDs, return each row along with:

- a **running sum** of `id` up to and including the current row
- the **next** row's `id` (`NULL` if there isn't one)
- the **previous** row's `id` (`NULL` if there isn't one)

## Problem Dataset

```sql
CREATE TABLE numbers (id INT);

INSERT INTO numbers VALUES (1), (2), (3), (4), (5);
```

Expected output:

| id | running_sum | next_value | prev_value |
|----|-------------|------------|------------|
| 1  | 1           | 2          | NULL       |
| 2  | 3           | 3          | 1          |
| 3  | 6           | 4          | 2          |
| 4  | 10          | 5          | 3          |
| 5  | 15          | NULL       | 4          |

## Problem Explanation

This is the canonical introduction to **window functions**: three different frame
types answer three different questions over the same ordered sequence —

- a *cumulative* window (`SUM() OVER (ORDER BY ...)`) for the running total
- an *offset* window (`LAG`/`LEAD`) for looking at neighboring rows

Nothing here needs a self-join or a correlated subquery; that's exactly the class of
problem window functions exist to replace.

## Problem Answer & Explanation

```sql
SELECT
    id,
    SUM(id) OVER (ORDER BY id) AS running_sum,
    LEAD(id) OVER (ORDER BY id) AS next_value,
    LAG(id)  OVER (ORDER BY id) AS prev_value
FROM numbers
ORDER BY id;
```

**Why it works**

- `SUM(id) OVER (ORDER BY id)` — when a window function has an `ORDER BY` but no
  explicit frame, the default frame is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT
  ROW`, which is exactly a running total.
- `LEAD(id)` looks one row ahead in the same `ORDER BY id` sequence; `LAG(id)` looks one
  row behind. Both default to an offset of 1 and return `NULL` when there's no such row
  (first row has no `LAG`, last row has no `LEAD`) — no manual boundary handling needed.
- All three window functions share the same `ORDER BY`, so a single pass over the
  sorted data computes all of them together; the engine doesn't need three separate
  sorts.

**Interview follow-up:** ask what happens if `id` isn't unique, or if you need the
running sum partitioned per group (`SUM(id) OVER (PARTITION BY group_col ORDER BY id)`)
— that's the natural next step tested in [Employee Referral Running Total](../08-employee-referral-running-total/README.md).
