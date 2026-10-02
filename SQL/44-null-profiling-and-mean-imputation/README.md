# Null Profiling & Mean Imputation

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![NULL Handling](https://img.shields.io/badge/-NULL%20Handling-34495E?style=flat-square)

> Adapted from `Scenerio35.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a students table with a nullable `age` column: (1) count how many `NULL`s are
in each column, (2) fill missing ages with the **mean of the known ages** (a common
imputation strategy), and (3) return only students who are 18 or older, using the
imputed age.

## Problem Dataset

```sql
CREATE TABLE students (
    id   INT,
    name VARCHAR(20),
    age  INT   -- nullable
);
INSERT INTO students VALUES
(1, 'John',   17),
(2, 'Maria',  20),
(3, 'Raj',    NULL),
(4, 'Rachel', 18),
(5, 'Amit',   NULL);
```

Expected output (part 1 — null counts):

| id_nulls | name_nulls | age_nulls |
|-----------|--------------|-------------|
| 0         | 0            | 2           |

Expected output (part 2 — imputed ages, 18+ only):

| id | name   | age |
|----|---------|-------|
| 2  | Maria   | 20    |
| 3  | Raj     | 18    |
| 4  | Rachel  | 18    |
| 5  | Amit    | 18    |

The mean of the three known ages (17, 20, 18) is 18.33, rounded to 18 — which is why
Raj and Amit (both imputed to 18) clear the 18+ bar, while John (a real, known age of
17) is correctly excluded.

## Problem Explanation

Two distinct `NULL`-handling ideas, chained together. **Counting** nulls per column
needs a boolean-to-number trick, since `COUNT(col)` already ignores `NULL`s by
default and so can't be used to count them — casting `col IS NULL` (a boolean) to an
integer and summing it does the opposite: counts exactly the rows where the value is
missing. **Imputation** is `COALESCE(actual_value, fallback_value)` — return the real
value if present, otherwise substitute the fallback — with the fallback here computed
dynamically from the data itself (the mean of the non-null ages) rather than a fixed
constant.

## Problem Answer & Explanation

**1. Null count per column**

```sql
SELECT
    SUM((id IS NULL)::INT)   AS id_nulls,
    SUM((name IS NULL)::INT) AS name_nulls,
    SUM((age IS NULL)::INT)  AS age_nulls
FROM students;
```

**2. Impute missing ages with the mean, then filter to 18+**

```sql
WITH mean_age AS (
    SELECT ROUND(AVG(age)) AS avg_age FROM students WHERE age IS NOT NULL
)
SELECT
    s.id, s.name,
    COALESCE(s.age, m.avg_age) AS age
FROM students s, mean_age m
WHERE COALESCE(s.age, m.avg_age) >= 18
ORDER BY s.id;
```

**Why it works**

1. `(id IS NULL)::INT` converts the boolean result of `IS NULL` into `1` (true) or `0`
   (false); `SUM(...)` across all rows then gives a total null count per column — a
   general pattern that works for counting *any* boolean condition across a table, not
   just nulls.
2. `mean_age` computes `AVG(age)` with an explicit `WHERE age IS NOT NULL` — this is
   actually redundant in Postgres, since `AVG()` already ignores `NULL` values by
   default, but making it explicit documents the intent and protects against engines
   where that default isn't guaranteed.
3. `students s, mean_age m` (a comma join, equivalent to `CROSS JOIN`) attaches the
   single computed `avg_age` value onto every student row — safe here specifically
   because `mean_age` always produces exactly one row, so there's no risk of the
   cross join causing unwanted fan-out.
4. `COALESCE(s.age, m.avg_age)` returns the real age when known, or the imputed mean
   when not — and that same expression is reused in the `WHERE` clause, so the 18+
   filter is applied to the *imputed* value, not the raw (possibly-null) column.

**Interview follow-up:** ask why the `WHERE` clause repeats the whole `COALESCE(...)`
expression instead of filtering on a `NULL`-able `age` column directly — because
`WHERE age >= 18` would silently drop every row where `age` is `NULL` (a `NULL`
comparison is neither true nor false), even though those rows have a perfectly usable
*imputed* value by this point in the query. This is the same class of bug the [Source
vs Target Reconciliation](../39-source-vs-target-reconciliation/README.md) problem
raises about `NULL`-unsafe comparisons.
