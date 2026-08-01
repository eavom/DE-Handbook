# Recipe Page Imposition

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Recursive CTE](https://img.shields.io/badge/-Recursive%20CTE-C0392B?style=flat-square) ![Sequencing/Bin-Packing](https://img.shields.io/badge/-Sequencing%2FBin--Packing-2C3E50?style=flat-square)

## Problem Statement

Recipes are printed onto pages in a fixed order (`recipe_id`). Each page holds 6
"slots." A recipe without a photo takes 1 slot; a recipe with a photo takes 2 slots.
A recipe can **never** be split across two pages — if it doesn't fully fit in the
current page's remaining slots, the whole recipe moves to the next page (wasting
whatever slots were left over). Assign every recipe a page number.

## Problem Dataset

```sql
CREATE TABLE recipes (
    recipe_id   INT,
    recipe_name VARCHAR(30),
    has_photo   BOOLEAN
);

INSERT INTO recipes VALUES
(1, 'Pasta',       FALSE),
(2, 'Salad',       FALSE),
(3, 'Bread',       FALSE),
(4, 'Photo Cake',  TRUE),
(5, 'Photo Soup',  TRUE),
(6, 'Rice',        FALSE),
(7, 'Photo Steak', TRUE),
(8, 'Photo Pie',   TRUE);
```

Expected output:

| recipe_id | recipe_name  | slots_needed | page_number |
|-----------|---------------|-----------------|----------------|
| 1         | Pasta         | 1               | 1              |
| 2         | Salad         | 1               | 1              |
| 3         | Bread         | 1               | 1              |
| 4         | Photo Cake    | 2               | 1              |
| 5         | Photo Soup    | 2               | 2              |
| 6         | Rice          | 1               | 2              |
| 7         | Photo Steak   | 2               | 2              |
| 8         | Photo Pie     | 2               | 3              |

Page 1 fills to 1+1+1+2 = 5 of 6 slots — recipe 5 needs 2 more slots (would make 7),
so it can't fit and the whole recipe moves to page 2, **wasting 1 slot on page 1**.
The same thing happens again at the end of page 2.

## Problem Explanation

This is **sequential bin-packing**, and it's fundamentally different from every other
problem in this set: the decision for row N (does it fit on the current page?)
depends on the *running, path-dependent state* built up by every row before it, and
that state can reset mid-stream (a new page starts). A window function's running
`SUM()` can't express "reset the running total, but only sometimes, based on a
condition that depends on the running total itself" — that circular dependency is
exactly what a **recursive CTE** is for: each recursion step carries forward the
current page number and current page's slot usage, decides whether the *next* recipe
fits, and either adds to the running total or resets it and bumps the page number.

## Problem Answer & Explanation

```sql
WITH RECURSIVE sized AS (
    SELECT recipe_id, recipe_name,
           CASE WHEN has_photo THEN 2 ELSE 1 END AS slots_needed
    FROM recipes
),
imposition AS (
    -- anchor: the very first recipe always starts page 1
    SELECT s.recipe_id, s.recipe_name, s.slots_needed,
           1 AS page_number, s.slots_needed AS slots_used_on_page
    FROM sized s
    WHERE s.recipe_id = (SELECT MIN(recipe_id) FROM sized)

    UNION ALL

    -- recursive step: does the next recipe fit in what's left on the current page?
    SELECT s.recipe_id, s.recipe_name, s.slots_needed,
           CASE WHEN i.slots_used_on_page + s.slots_needed <= 6
                THEN i.page_number ELSE i.page_number + 1 END,
           CASE WHEN i.slots_used_on_page + s.slots_needed <= 6
                THEN i.slots_used_on_page + s.slots_needed ELSE s.slots_needed END
    FROM imposition i
    JOIN sized s ON s.recipe_id = (SELECT MIN(recipe_id) FROM sized WHERE recipe_id > i.recipe_id)
)
SELECT recipe_id, recipe_name, slots_needed, page_number
FROM imposition
ORDER BY recipe_id;
```

**Why it works**

1. `sized` precomputes each recipe's slot requirement once, so the recursive part only
   deals with the packing logic.
2. The **anchor member** always assigns the very first recipe (lowest `recipe_id`) to
   page 1, seeding both `page_number` and `slots_used_on_page`.
3. The **recursive member** looks up the *next* recipe (`recipe_id >` the last one
   processed) and checks whether it fits in the remaining space on the current page
   (`slots_used_on_page + slots_needed <= 6`). If it fits, the page number stays the
   same and slot usage accumulates; if it doesn't, the page number increments and slot
   usage **resets** to just this recipe's requirement — the leftover space on the old
   page is simply never reclaimed, matching the "no splitting a recipe" rule.
4. This has to be a recursive CTE (not a window function) precisely because "does this
   fit" depends on the *actual outcome* of every prior decision, not on a fixed
   partition or a simple running sum — the running total can reset mid-sequence based
   on a condition that only the recursion, evaluated one row at a time, can track.

**Interview follow-up:** ask how you'd calculate total **wasted slots** across all
pages — group the final result by `page_number`, sum `slots_needed` per page, and
subtract from 6 (page capacity) per page, then sum those leftovers; here that's 1
wasted slot on page 1, 1 on page 2, and 4 on page 3 (only 2 of 6 slots used) = 6
wasted slots total.
