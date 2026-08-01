# Shopping Budget — Greedy Knapsack

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Recursive CTE](https://img.shields.io/badge/-Recursive%20CTE-C0392B?style=flat-square) ![Greedy Algorithm](https://img.shields.io/badge/-Greedy%20Algorithm-2C3E50?style=flat-square)

## Problem Statement

Given a wishlist ranked by priority (1 = must-have) and a fixed budget of 5,000, decide
which items to buy: go down the priority list and buy every item that still fits in
the **remaining** budget, skipping (not buying) any item that doesn't fit, and
continuing to try the rest of the list against whatever budget is still left. This is
the classic greedy heuristic for knapsack-style problems — not a guarantee of the
mathematically optimal combination, just "take the best-priority items you can
afford, in order."

## Problem Dataset

```sql
CREATE TABLE shopping_items (
    item_id   INT,
    item_name VARCHAR(30),
    price     NUMERIC,
    priority  INT     -- 1 = highest priority
);

INSERT INTO shopping_items VALUES
(1, 'Backpack',     1800, 1),
(2, 'Headphones',   2500, 2),
(3, 'Water Bottle',  400, 3),
(4, 'Notebook Set',  350, 4),
(5, 'Desk Lamp',    1200, 5),
(6, 'Umbrella',      600, 6);
```

Expected output (budget = 5,000):

| item_id | item_name     | price | priority | spent_so_far | decision            |
|---------|-----------------|--------|-------------|-----------------|-------------------------|
| 1       | Backpack        | 1800   | 1           | 1800            | Buy                     |
| 2       | Headphones      | 2500   | 2           | 4300            | Buy                     |
| 3       | Water Bottle    | 400    | 3           | 4700            | Buy                     |
| 4       | Notebook Set    | 350    | 4           | 4700            | Skip (over budget)      |
| 5       | Desk Lamp       | 1200   | 5           | 4700            | Skip (over budget)      |
| 6       | Umbrella        | 600    | 6           | 4700            | Skip (over budget)      |

Total spend: 4,700 of 5,000. Notebook Set (350) is skipped because 4,700 + 350 = 5,050
exceeds budget — even though 350 alone is affordable, there just isn't 350 left. Desk
Lamp and Umbrella are then also evaluated against the *same* 4,700 remaining spend
(not against 5,050), since Notebook Set was never actually bought.

## Problem Explanation

The tempting first approach is a plain running-total window function — `SUM(price)
OVER (ORDER BY priority ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` — and then
flagging `'Buy'` wherever that running sum stays under budget. **That approach is
wrong here**, and seeing why is the actual point of the exercise: a window function's
running sum always adds every row's price in order, whether or not that row was
"kept." Once one item is skipped for being over budget, a plain running `SUM()` keeps
including its price anyway, permanently inflating every subsequent row's total and
causing items further down the list to be skipped even when there's real budget left
for them. This is a decision problem where each row's outcome depends on the *actual*
outcome of every prior row, not on a fixed, order-independent aggregate — exactly the
same reason [Recipe Page Imposition](../21-recipe-page-imposition/README.md) needed a
recursive CTE instead of a window function.

## Problem Answer & Explanation

**The naive (incorrect) attempt, for comparison:**

```sql
-- WRONG: keeps accumulating skipped items' prices into the running total
SELECT
    item_id, item_name, price, priority,
    SUM(price) OVER (ORDER BY priority
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_spend,
    CASE WHEN SUM(price) OVER (ORDER BY priority
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) <= 5000
         THEN 'Buy' ELSE 'Skip (over budget)' END AS decision
FROM shopping_items
ORDER BY priority;
-- Notebook Set (priority 4) pushes running_spend to 5050 and gets skipped — correct
-- so far — but Desk Lamp (priority 5) is then compared against 6250 (still counting
-- Notebook Set's price), not the true remaining budget of 300. Every item from here
-- on is wrongly evaluated against an inflated total.
```

**The correct answer:**

```sql
WITH RECURSIVE greedy AS (
    -- anchor: the highest-priority item is evaluated against the full budget
    SELECT
        item_id, item_name, price, priority,
        CASE WHEN price <= 5000 THEN price ELSE 0 END AS spent_so_far,
        CASE WHEN price <= 5000 THEN 'Buy' ELSE 'Skip (over budget)' END AS decision
    FROM shopping_items
    WHERE priority = (SELECT MIN(priority) FROM shopping_items)

    UNION ALL

    -- recursive step: does the NEXT item fit in what's actually left of the budget?
    SELECT
        s.item_id, s.item_name, s.price, s.priority,
        CASE WHEN g.spent_so_far + s.price <= 5000 THEN g.spent_so_far + s.price ELSE g.spent_so_far END,
        CASE WHEN g.spent_so_far + s.price <= 5000 THEN 'Buy' ELSE 'Skip (over budget)' END
    FROM greedy g
    JOIN shopping_items s ON s.priority = (SELECT MIN(priority) FROM shopping_items WHERE priority > g.priority)
)
SELECT item_id, item_name, price, priority, spent_so_far, decision
FROM greedy
ORDER BY priority;
```

**Why it works**

1. The **anchor member** evaluates the top-priority item against the full budget and
   sets the true starting `spent_so_far`.
2. The **recursive member** looks at the next item in priority order and compares it
   to `g.spent_so_far` — the *actual* running total carried forward from the previous
   step, which only increased on rows that were really bought. A skipped item's price
   never enters `spent_so_far`, so later items get evaluated against a true remaining
   budget rather than an inflated one.
3. This is why the correct answer and the naive window-function answer happen to
   agree on *this* dataset up through Notebook Set, but would diverge on a dataset
   where a cheap item appears after a skipped one and should be buyable — the
   recursive version would correctly buy it; the window-function version would
   wrongly skip it too.

**Interview follow-up:** ask for a concrete dataset where the two approaches produce
*different* `decision` columns — for example, insert a 7th item priced at 200 with
priority 7. The recursive (correct) version buys it (4700 + 200 = 4900 ≤ 5000); the
naive window-function version still compares it against the inflated running total
that includes every previously skipped item's price, and wrongly skips it too.
