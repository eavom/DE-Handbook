# Customer Addresses as a Set

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square) ![Array Aggregation](https://img.shields.io/badge/-Array%20Aggregation-7F8C8D?style=flat-square)

> Adapted from `Scenerio4.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a log of customer addresses (one row per address a customer has ever used),
return each customer with the **distinct set** of addresses associated with them —
no duplicate addresses, even if the same address appears multiple times in the log.

## Problem Dataset

```sql
CREATE TABLE customer_addresses (
    cust_id   INT,
    cust_name VARCHAR(30),
    address   VARCHAR(10)
);

INSERT INTO customer_addresses VALUES
(1, 'Mark Ray',    'AB'),
(2, 'Peter Smith', 'CD'),
(1, 'Mark Ray',    'EF'),
(2, 'Peter Smith', 'GH'),
(2, 'Peter Smith', 'CD'),   -- duplicate address for Peter Smith
(3, 'Kate',        'IJ');
```

Expected output:

| cust_id | cust_name    | addresses |
|---------|---------------|--------------|
| 1       | Mark Ray      | {AB, EF}     |
| 2       | Peter Smith   | {CD, GH}     |
| 3       | Kate          | {IJ}         |

Peter Smith's repeated `CD` address collapses to a single entry in his address set.

## Problem Explanation

`GROUP BY` alone collapses rows down to one per customer, but a plain `GROUP BY`
needs every non-aggregated column to be summarized by *some* aggregate function —
there's no way to just "keep all the addresses" with `SUM`/`COUNT`/`MAX`. The fix is
`ARRAY_AGG`, which collects every value in the group into an array instead of
reducing it to a scalar; adding `DISTINCT` inside it removes duplicates the same way
`DISTINCT` would in a plain `SELECT`.

## Problem Answer & Explanation

```sql
SELECT
    cust_id,
    cust_name,
    ARRAY_AGG(DISTINCT address ORDER BY address) AS addresses
FROM customer_addresses
GROUP BY cust_id, cust_name
ORDER BY cust_id;
```

**Why it works**

1. `GROUP BY cust_id, cust_name` collapses the address log to one row per customer.
2. `ARRAY_AGG(DISTINCT address ORDER BY address)` does two things at once: `DISTINCT`
   drops repeated address values within the group, and `ORDER BY address` (inside the
   aggregate, not the outer query) guarantees a stable, alphabetized order in the
   resulting array — without it, the array's element order would be arbitrary and
   could differ between runs.
3. This is the array-native equivalent of [Explode & Aggregate Skills](../13-explode-and-aggregate-skills/README.md)'s
   `STRING_TO_ARRAY`/`UNNEST` combo run in reverse: that problem exploded a delimited
   string into rows to aggregate; this problem aggregates rows back into an array.

**Interview follow-up:** ask how you'd get a comma-separated string instead of a
Postgres array (e.g. for exporting to a system that doesn't understand array types) —
swap `ARRAY_AGG(DISTINCT address ORDER BY address)` for
`STRING_AGG(DISTINCT address, ', ' ORDER BY address)`, the same aggregate used in
sub-question 12 of [Customer & Orders Analytics](../06-customer-and-orders-analytics/README.md).
