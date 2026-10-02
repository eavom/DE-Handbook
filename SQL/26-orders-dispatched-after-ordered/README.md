# Orders Dispatched After Being Ordered

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Semi-Join](https://img.shields.io/badge/-Semi--Join-16A085?style=flat-square)

> Adapted from `Scenerio2.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given an order status log (one row per status change), return every `Dispatched`
status entry, but only for orders that were legitimately placed (i.e. that also have
an `Ordered` status entry somewhere in the log).

## Problem Dataset

```sql
CREATE TABLE order_status (
    order_id    INT,
    status_date DATE,
    status      VARCHAR(20)
);

INSERT INTO order_status VALUES
(1, '2025-01-01', 'Ordered'),
(1, '2025-01-02', 'Dispatched'),
(1, '2025-01-03', 'Dispatched'),
(1, '2025-01-04', 'Shipped'),
(1, '2025-01-06', 'Delivered'),
(2, '2025-01-01', 'Ordered'),
(2, '2025-01-02', 'Dispatched'),
(2, '2025-01-03', 'Shipped'),
(3, '2025-01-01', 'Dispatched');   -- order 3 was never actually placed as "Ordered" (data anomaly)
```

Expected output:

| order_id | status_date | status     |
|----------|--------------|------------|
| 1        | 2025-01-02   | Dispatched |
| 1        | 2025-01-03   | Dispatched |
| 2        | 2025-01-02   | Dispatched |

Order 3's `Dispatched` row is correctly excluded — it has no matching `Ordered` row,
which in a real pipeline would flag a data-integrity problem (a dispatch event with no
corresponding order event).

## Problem Explanation

This is a **semi-join**: filter one table's rows down to only those whose key exists
somewhere in another set, without actually pulling in any columns from that other
set. The cleanest way to express a semi-join in SQL is `WHERE key IN (SELECT key FROM
...)` — it answers "does a match exist," nothing more, which is exactly what's needed
here (unlike a real `JOIN`, which would also need `DISTINCT` to avoid row duplication
if an order had multiple `Ordered` rows).

## Problem Answer & Explanation

```sql
SELECT *
FROM order_status
WHERE status = 'Dispatched'
  AND order_id IN (SELECT order_id FROM order_status WHERE status = 'Ordered')
ORDER BY order_id, status_date;
```

**Why it works**

1. The outer `WHERE status = 'Dispatched'` narrows to the rows of interest first.
2. The `IN (SELECT order_id FROM order_status WHERE status = 'Ordered')` subquery
   produces the set of order ids that have ever been legitimately ordered — this runs
   independent of the outer query and is evaluated once, not once per outer row (a
   good query planner will materialize or hash it rather than re-running it per row).
3. Because `IN` only checks membership, an order with multiple `Ordered` rows (which
   shouldn't happen here, but could in messier data) wouldn't cause the outer query to
   duplicate rows — that's the key advantage of a semi-join over a regular `JOIN`
   for this kind of "does a match exist" question.

**Interview follow-up:** ask how this differs from writing the same logic as an
`EXISTS` correlated subquery instead of `IN`. Functionally they're equivalent here;
`EXISTS` is generally preferred when the subquery's matching condition needs to
reference the outer row's other columns (a true correlated subquery), while `IN` reads
more naturally when — like here — the subquery is a simple, self-contained lookup of
one column.
