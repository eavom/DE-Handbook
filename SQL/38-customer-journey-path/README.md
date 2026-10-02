# Customer Journey Path

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square) ![Array Aggregation](https://img.shields.io/badge/-Array%20Aggregation-7F8C8D?style=flat-square)

> Adapted from `Scenerio24.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a page-visit log (one row per page a user viewed, in visit order), build each
user's full navigation path as an ordered list of pages — the kind of "funnel" or
"user journey" view product analytics dashboards commonly show.

## Problem Dataset

```sql
CREATE TABLE page_visits (
    user_id     INT,
    visit_seq   INT,
    page        VARCHAR(20)
);

INSERT INTO page_visits VALUES
(1, 1, 'home'), (1, 2, 'products'), (1, 3, 'checkout'), (1, 4, 'confirmation'),
(2, 1, 'home'), (2, 2, 'products'), (2, 3, 'cart'), (2, 4, 'checkout'),
(2, 5, 'confirmation'), (2, 6, 'home'), (2, 7, 'products');
```

Expected output:

| user_id | journey                                                      |
|---------|----------------------------------------------------------------|
| 1       | {home, products, checkout, confirmation}                        |
| 2       | {home, products, cart, checkout, confirmation, home, products}  |

Notice user 2 revisits `home` and `products` later in their session — the journey
array preserves that repeat visit rather than deduplicating it, since a user's actual
path through a site is a *sequence*, not a set.

## Problem Explanation

This looks similar to [Customer Addresses as a Set](../28-customer-addresses-as-a-set/README.md),
but it's a meaningfully different requirement: that problem wanted **unique**
addresses (a set), while this one wants the **full ordered sequence** of pages,
duplicates and all — visiting "home" twice is a real, meaningful part of the user's
journey, not noise to be deduplicated. That's the difference between `ARRAY_AGG(...)`
and `ARRAY_AGG(DISTINCT ...)`, and between ordering by an explicit sequence column
versus not caring about order at all.

## Problem Answer & Explanation

```sql
SELECT
    user_id,
    ARRAY_AGG(page ORDER BY visit_seq) AS journey
FROM page_visits
GROUP BY user_id
ORDER BY user_id;
```

**Why it works**

1. `GROUP BY user_id` collapses the visit log to one row per user.
2. `ARRAY_AGG(page ORDER BY visit_seq)` — with no `DISTINCT` — keeps every page visit,
   including repeats, and the `ORDER BY visit_seq` inside the aggregate guarantees the
   array reflects the actual chronological order the user navigated in, not an
   arbitrary row order.
3. Dropping the `ORDER BY` inside `ARRAY_AGG` (a common mistake) would still produce
   an array of the right *length*, but with no guarantee the pages appear in visit
   order — a subtle bug that's easy to miss in small test data where insertion order
   happens to match visit order by coincidence.

**Interview follow-up:** ask how you'd extend this to flag which users **abandoned**
their journey (reached `checkout` but never reached `confirmation`) — that needs
`page = ANY(journey) `-style array membership checks, or more robustly, going back to
the row-level data with a semi-join: `WHERE user_id IN (SELECT user_id FROM
page_visits WHERE page = 'checkout') AND user_id NOT IN (SELECT user_id FROM
page_visits WHERE page = 'confirmation')` — the same semi-join/anti-join combination
used in [Customers Who Bought Specific Products](../37-customers-who-bought-specific-products/README.md)
and [Customer & Orders Analytics](../06-customer-and-orders-analytics/README.md).
