# Top-Selling Product per Year

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![DENSE_RANK](https://img.shields.io/badge/-DENSE__RANK-8E44AD?style=flat-square)

> Adapted from `Scenerio7.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a sales log with quantity sold per product per year, find the top-selling
product(s) — by quantity — for each year. If two products tie for the most units sold
in the same year, return both.

## Problem Dataset

```sql
CREATE TABLE product_sales (
    sale_id    INT,
    product_id INT,
    sale_year  INT,
    quantity   INT,
    price      NUMERIC
);

INSERT INTO product_sales VALUES
(1, 100, 2020, 25, 5000),
(2, 100, 2021, 16, 5000),
(3, 100, 2022,  8, 5000),
(4, 200, 2020, 10, 9000),
(5, 200, 2021, 25, 9000),
(6, 200, 2022, 20, 7000),
(7, 300, 2020, 25, 7000),
(8, 300, 2021, 18, 7000),
(9, 300, 2022, 20, 7000);
```

Expected output:

| sale_id | product_id | sale_year | quantity | price |
|---------|-------------|------------|------------|--------|
| 1       | 100         | 2020       | 25         | 5000   |
| 7       | 300         | 2020       | 25         | 7000   |
| 5       | 200         | 2021       | 25         | 9000   |
| 6       | 200         | 2022       | 20         | 7000   |
| 9       | 300         | 2022       | 20         | 7000   |

2020 and 2022 each have a genuine tie for top quantity; 2021 has a single clear
winner.

## Problem Explanation

"Top per group" is the rank-then-filter pattern used throughout this repo — but the
choice between `RANK()`, `DENSE_RANK()`, and `ROW_NUMBER()` changes the answer when
ties are involved, and this dataset is deliberately built to have ties. `DENSE_RANK()`
is the right choice here: it assigns the same rank to tied rows (like `RANK()`) so
both winners are kept, and — unlike `RANK()` — it doesn't leave gaps in the ranking
sequence, which matters if a later requirement ever needs "top 2" or "top 3" and a tie
at rank 1 shouldn't push the next distinct value down to rank 3.

## Problem Answer & Explanation

```sql
WITH ranked AS (
    SELECT *,
           DENSE_RANK() OVER (PARTITION BY sale_year ORDER BY quantity DESC) AS qty_rank
    FROM product_sales
)
SELECT sale_id, product_id, sale_year, quantity, price
FROM ranked
WHERE qty_rank = 1
ORDER BY sale_year, sale_id;
```

**Why it works**

1. `DENSE_RANK() OVER (PARTITION BY sale_year ORDER BY quantity DESC)` restarts the
   ranking for every year, ordering products within that year by quantity descending.
2. Ties in `quantity` (2020: two products at 25; 2022: two products at 20) receive the
   identical rank, so both survive the `qty_rank = 1` filter.
3. Contrast with `ROW_NUMBER()`, which would have arbitrarily broken each tie and kept
   only one of the two tied products per year — silently wrong for "return the top
   seller(s)," which implies ties should both count as winners.

**Interview follow-up:** ask what the query would return for 2020 and 2022 if
`RANK()` were used instead of `DENSE_RANK()` — for *this specific query* (`WHERE
qty_rank = 1`), the answer is identical, since `RANK()` and `DENSE_RANK()` only differ
in what rank the row *after* a tie gets, not in how ties themselves are ranked. The
difference only shows up if the filter changes to `qty_rank <= 2`: `RANK()` would skip
straight to whatever's tied for 3rd after a 2-way tie at 1st, while `DENSE_RANK()`
would still include the next genuinely distinct quantity value.
