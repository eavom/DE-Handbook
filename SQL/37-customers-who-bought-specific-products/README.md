# Customers Who Bought Specific Products

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Semi-Join](https://img.shields.io/badge/-Semi--Join-16A085?style=flat-square)

> Adapted from `Scenerio23.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a purchase log and a list of target product keys, find every distinct customer
who bought **any** of the target products — excluding customer `2` specifically (a
requirement standing in for something like "excluding a known test account" or "a
customer already handled by another process").

## Problem Dataset

```sql
CREATE TABLE purchases (
    customer_id INT,
    product_key INT
);
INSERT INTO purchases VALUES
(1, 5), (2, 6), (3, 5), (3, 6), (1, 6), (4, 7);

CREATE TABLE target_products (
    product_key INT
);
INSERT INTO target_products VALUES (5), (6);
```

Expected output:

| customer_id |
|--------------|
| 1            |
| 3            |

Customer 2 is excluded by the explicit filter even though they bought a target
product (`6`). Customer 4 is excluded because product `7` isn't in the target list.

## Problem Explanation

This is the same **semi-join** shape as
[Orders Dispatched After Being Ordered](../26-orders-dispatched-after-ordered/README.md) —
filter one table down to rows whose key exists in another set — combined with
`DISTINCT` (since a single customer can appear multiple times in `purchases`) and a
plain exclusion filter.

## Problem Answer & Explanation

```sql
SELECT DISTINCT customer_id
FROM purchases
WHERE product_key IN (SELECT product_key FROM target_products)
  AND customer_id <> 2
ORDER BY customer_id;
```

**Why it works**

1. `product_key IN (SELECT product_key FROM target_products)` is the semi-join —
   keeps only purchase rows for a targeted product, without pulling in any columns
   from `target_products` itself.
2. `AND customer_id <> 2` is a second, independent filter applied to the same rows —
   order of `AND` conditions doesn't matter for correctness, only for how the query
   planner might choose to evaluate them.
3. `DISTINCT` collapses customer 1's two matching purchase rows (`product_key = 5` and
   `product_key = 6`) down to a single output row — without it, customer 1 would
   appear twice.

**Interview follow-up:** ask how this changes if the requirement is "bought **every**
target product" instead of "bought **any** target product" — that's a genuinely
different question (relational division), and `IN` alone can't express it. It needs a
`GROUP BY customer_id HAVING COUNT(DISTINCT product_key) = (SELECT COUNT(*) FROM
target_products)` — counting how many *distinct* target products each customer
matched, and requiring that count equal the full size of the target list.
