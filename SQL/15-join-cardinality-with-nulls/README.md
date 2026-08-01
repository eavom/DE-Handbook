# Join Cardinality With NULLs & Duplicates

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![JOIN](https://img.shields.io/badge/-JOIN-16A085?style=flat-square) ![NULL Handling](https://img.shields.io/badge/-NULL%20Handling-34495E?style=flat-square)

## Problem Statement

`orders15` has 4 rows; `customers15` has 4 rows. Two data-quality issues are baked in:
one order has a `NULL` `customer_id`, one order references a `customer_id` that
doesn't exist in `customers15`, and one `customer_id` appears **twice** in
`customers15` (a duplicate record). Show what `INNER JOIN` and `LEFT JOIN` each
return, and explain why the row counts don't match either input table's row count.

## Problem Dataset

```sql
CREATE TABLE customers15 (
    customer_id   INT,
    customer_name VARCHAR(50)
);
INSERT INTO customers15 VALUES
(101, 'Alpha Corp'),
(102, 'Beta Ltd'),
(102, 'Beta Ltd (dup record)'),  -- data-quality bug: duplicate customer_id
(103, 'Gamma Inc');

CREATE TABLE orders15 (
    order_id    INT,
    customer_id INT              -- nullable
);
INSERT INTO orders15 VALUES
(1, 101),
(2, 102),
(3, NULL),   -- order with no customer attached
(4, 105);    -- order referencing a customer_id that doesn't exist
```

Expected output — `INNER JOIN`:

| order_id | customer_id | customer_name          |
|----------|--------------|--------------------------|
| 1        | 101          | Alpha Corp               |
| 2        | 102          | Beta Ltd (dup record)    |
| 2        | 102          | Beta Ltd                 |

Expected output — `LEFT JOIN`:

| order_id | customer_id | customer_name          |
|----------|--------------|--------------------------|
| 1        | 101          | Alpha Corp               |
| 2        | 102          | Beta Ltd (dup record)    |
| 2        | 102          | Beta Ltd                 |
| 3        | NULL         | NULL                      |
| 4        | 105          | NULL                      |

`orders15` has 4 rows, yet `INNER JOIN` returns 3 and `LEFT JOIN` returns 5 — neither
matches the "expected" 4.

## Problem Explanation

Two independent effects are at play, and it's easy to blame the wrong one:

- **NULLs drop rows on an equi-join.** `NULL = anything` is never `TRUE` in SQL (it's
  `UNKNOWN`), so order 3 (`customer_id IS NULL`) can never match any row in
  `customers15` on `INNER JOIN`. Order 4 also drops out of the `INNER JOIN` — not
  because of `NULL`, but because `105` genuinely has no matching row.
- **Duplicates on the joined-to side cause fan-out**, independent of NULLs entirely.
  Order 2's `customer_id = 102` matches *two* rows in `customers15` (the duplicate
  record), so it appears twice in the result — this happens on both `INNER JOIN` and
  `LEFT JOIN`, and is often the more dangerous bug because it silently inflates
  `SUM()`/`COUNT()` on the order side rather than obviously dropping rows.

`LEFT JOIN` fixes the NULL/no-match problem (orders 3 and 4 are preserved with a
`NULL` customer name) but does **nothing** about the duplicate-fan-out problem — order
2 is still duplicated in both result sets.

## Problem Answer & Explanation

```sql
-- INNER JOIN: NULL-keyed and unmatched orders disappear; duplicate customer rows fan out
SELECT o.order_id, o.customer_id, c.customer_name
FROM orders15 o
JOIN customers15 c ON c.customer_id = o.customer_id
ORDER BY o.order_id;
```

```sql
-- LEFT JOIN: every order is preserved, but the duplicate-row fan-out is still there
SELECT o.order_id, o.customer_id, c.customer_name
FROM orders15 o
LEFT JOIN customers15 c ON c.customer_id = o.customer_id
ORDER BY o.order_id;
```

**Why it works**

1. `INNER JOIN` keeps only rows where the join condition evaluates `TRUE` on both
   sides — a `NULL` key or a missing match both evaluate to "not true," so both kinds
   of order silently vanish, with no error or warning.
2. `LEFT JOIN` guarantees every row from `orders15` (the left table) survives at least
   once, filling in `NULL` for `customers15` columns when there's no match — this is
   the fix for the "orders disappearing" half of the problem.
3. Neither join type deduplicates the *right* table first. If `customers15` has two
   rows for `customer_id = 102`, both joins multiply order 2 into two output rows —
   fixing this requires deduplicating `customers15` (e.g. `SELECT DISTINCT ON
   (customer_id) ...` in Postgres) **before** joining, not switching join types.

**Interview follow-up:** ask "if `SUM(amount)` were added to this query, would the
duplicate fan-out double-count order 2's revenue?" — yes, which is exactly why
row-count sanity checks (`COUNT(*)` before and after a join) are a standard first step
before trusting any aggregate built on top of a join.
