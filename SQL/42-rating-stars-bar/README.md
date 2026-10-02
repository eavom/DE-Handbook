# Rating Stars Bar

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![String Formatting](https://img.shields.io/badge/-String%20Formatting-F39C12?style=flat-square)

> Adapted from `Scenerio32 Scala.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a food menu and a 1-5 star rating per item, render each rating as a visual bar
of asterisks (`"****"` for a rating of 4, `"*****"` for a rating of 5, and so on) —
the kind of formatting a reporting tool would apply before displaying ratings to a
non-technical audience.

## Problem Dataset

```sql
CREATE TABLE food_items (food_id INT, food_item VARCHAR(30));
INSERT INTO food_items VALUES
(1, 'Veg Biryani'), (2, 'Veg Fried Rice'), (3, 'Kaju Fried Rice'),
(4, 'Chicken Biryani'), (5, 'Chicken Dum Biryani'), (6, 'Prawns Biryani'), (7, 'Fish Biryani');

CREATE TABLE food_ratings (food_id INT, rating INT);
INSERT INTO food_ratings VALUES
(1,5), (2,3), (3,4), (4,4), (5,5), (6,4), (7,4);
```

Expected output:

| food_id | food_item            | rating | stars_out_of_5 |
|---------|------------------------|----------|-------------------|
| 1       | Veg Biryani            | 5        | *****             |
| 2       | Veg Fried Rice         | 3        | ***               |
| 3       | Kaju Fried Rice        | 4        | ****              |
| 4       | Chicken Biryani        | 4        | ****              |
| 5       | Chicken Dum Biryani    | 5        | *****             |
| 6       | Prawns Biryani         | 4        | ****              |
| 7       | Fish Biryani           | 4        | ****              |

## Problem Explanation

This is a small but genuinely useful pattern: turning a numeric value directly into a
proportional visual string, without any conditional logic. `REPEAT(string, n)`
produces a string by repeating its first argument `n` times — feeding it the numeric
rating directly as the repeat count does the entire "bar chart in text" conversion in
one function call, no `CASE` statement needed.

## Problem Answer & Explanation

```sql
SELECT
    f.food_id,
    f.food_item,
    r.rating,
    REPEAT('*', r.rating) AS stars_out_of_5
FROM food_items f
JOIN food_ratings r ON f.food_id = r.food_id
ORDER BY f.food_id;
```

**Why it works**

1. A standard `JOIN` combines each food item with its rating — nothing unusual here.
2. `REPEAT('*', r.rating)` takes the literal `'*'` character and repeats it exactly
   `rating` times, producing `'****'` for a rating of 4 directly from the numeric
   column — no lookup table or `CASE WHEN rating = 4 THEN '****' ...` mapping needed.

**Interview follow-up:** ask how you'd render a rating **out of 5** where the empty
slots are also visible (e.g. `"★★★★☆"` for a 4-star rating, showing one empty star)
instead of just the filled stars — that needs two `REPEAT()` calls concatenated:
`REPEAT('★', rating) || REPEAT('☆', 5 - rating)`, filling the remainder of a
fixed-width 5-slot bar with the empty-star character.
