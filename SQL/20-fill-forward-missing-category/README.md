# Fill Forward — Missing Category

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Window Functions](https://img.shields.io/badge/-Window%20Functions-8E44AD?style=flat-square) ![Partitioning](https://img.shields.io/badge/-Partitioning-8E44AD?style=flat-square)

## Problem Statement

A product's category is only recorded on the day it changes; on every other day it's
`NULL` in the source feed. For each product, "fill forward" every `NULL` category
with the most recent non-`NULL` category that came before it (chronologically). A
product's category should stay `NULL` only until its *first* known value appears.

## Problem Dataset

```sql
CREATE TABLE product_prices (
    product_id INT,
    price_date DATE,
    category   VARCHAR(30)   -- NULL when not re-classified that day
);

INSERT INTO product_prices VALUES
(1, '2025-01-01', 'Electronics'),
(1, '2025-01-02', NULL),
(1, '2025-01-03', NULL),
(1, '2025-01-04', 'Appliances'),
(1, '2025-01-05', NULL),
(2, '2025-01-01', NULL),          -- no category known yet at start
(2, '2025-01-02', 'Furniture'),
(2, '2025-01-03', NULL);
```

Expected output:

| product_id | price_date | original_category | filled_category |
|------------|-------------|----------------------|---------------------|
| 1          | 2025-01-01  | Electronics          | Electronics         |
| 1          | 2025-01-02  | NULL                 | Electronics         |
| 1          | 2025-01-03  | NULL                 | Electronics         |
| 1          | 2025-01-04  | Appliances           | Appliances          |
| 1          | 2025-01-05  | NULL                 | Appliances          |
| 2          | 2025-01-01  | NULL                 | NULL                |
| 2          | 2025-01-02  | Furniture            | Furniture           |
| 2          | 2025-01-03  | NULL                 | Furniture           |

Product 2's first row correctly stays `NULL` — there's no earlier known value to fill
forward from yet.

## Problem Explanation

Standard SQL has no built-in "last non-null value, ignoring nulls" window function
(some dialects offer `IGNORE NULLS` on `LAST_VALUE`, but Postgres doesn't). The
portable trick: use `COUNT(category) OVER (ORDER BY ...)` — `COUNT` on a specific
column only counts non-`NULL` values — as a **fill-forward group id**. Every row since
the last known category (inclusive) shares the same count, so grouping by that count
and taking the group's `MAX(category)` (only one non-null value per group) carries the
last known value forward.

## Problem Answer & Explanation

```sql
WITH grp AS (
    SELECT
        product_id,
        price_date,
        category,
        COUNT(category) OVER (
            PARTITION BY product_id ORDER BY price_date
        ) AS fill_group
    FROM product_prices
)
SELECT
    product_id,
    price_date,
    category AS original_category,
    MAX(category) OVER (PARTITION BY product_id, fill_group) AS filled_category
FROM grp
ORDER BY product_id, price_date;
```

**Why it works**

1. `COUNT(category) OVER (PARTITION BY product_id ORDER BY price_date)` — with no
   explicit frame, defaults to `RANGE UNBOUNDED PRECEDING AND CURRENT ROW` — counts
   how many non-`NULL` categories have been seen so far for that product. This value
   only increments on rows where `category` is actually known, so it stays flat across
   every subsequent `NULL` row until the next known value bumps it up.
2. That flat value (`fill_group`) is exactly the grouping key needed: every row from
   one known category up to (but not including) the next known category shares the
   same `fill_group`.
3. `MAX(category) OVER (PARTITION BY product_id, fill_group)` then picks the one
   non-`NULL` value present in that group and broadcasts it to every row in the group
   — `MAX` on a single-non-null-value-per-group set is just "the value," used here as
   a “pick the non-null one” trick rather than an actual maximum.
4. Product 2's leading `NULL` row has `fill_group = 0` (zero non-null values seen yet)
   with no non-null value in that group at all, so `MAX(category)` for that group is
   correctly `NULL` — there's nothing to fill forward *from* yet.

**Interview follow-up:** ask how this changes if you need to fill forward **and**
cap how far forward a value can carry (e.g. a category older than 90 days is
considered stale and should revert to `NULL`) — that needs an extra join back to the
row that actually set `fill_group`'s value to check its `price_date`, since the count
trick alone has no memory of *when* the value was last set, only *that* it was.
