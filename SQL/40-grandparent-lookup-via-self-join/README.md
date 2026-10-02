# Grandparent Lookup via Self-Join

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Self-Join](https://img.shields.io/badge/-Self--Join-16A085?style=flat-square)

> Adapted from `Scenerio28.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a `child -> parent` relationship table, find each child's **grandparent** —
their parent's parent.

## Problem Dataset

```sql
CREATE TABLE family_tree (
    child  VARCHAR(5),
    parent VARCHAR(5)
);

INSERT INTO family_tree VALUES
('A', 'AA'), ('B', 'BB'), ('C', 'CC'),
('AA', 'AAA'), ('BB', 'BBB'), ('CC', 'CCC');
```

Expected output:

| child | parent | grandparent |
|-------|---------|----------------|
| A     | AA      | AAA            |
| B     | BB      | BBB            |
| C     | CC      | CCC            |

## Problem Explanation

`AA` is both a parent (of `A`) and a child (of `AAA`) in the same table — the exact
kind of self-referencing structure that showed up in
[Employee Hierarchy](../09-employee-hierarchy-recursive/README.md), which needed a
**recursive** CTE because it had to walk an *arbitrary* number of levels down. This
problem is deliberately simpler: it only ever needs to look **exactly one level up**
from the parent, which a single, ordinary self-join can do without any recursion at
all — a good reminder that recursive CTEs are for *unbounded*-depth traversal, not for
every problem that happens to involve a hierarchy.

## Problem Answer & Explanation

```sql
SELECT
    f1.child,
    f1.parent,
    f2.parent AS grandparent
FROM family_tree f1
JOIN family_tree f2 ON f1.parent = f2.child
ORDER BY f1.child;
```

**Why it works**

1. `f1` represents the "child -> parent" relationship as given.
2. `f2` represents the *same table*, but the join condition `f1.parent = f2.child`
   reinterprets each `f2` row as "this parent's own parent" — i.e., it looks up the
   row where the current parent (`f1.parent`) appears as *someone else's* child, and
   that row's `parent` column is the grandparent.
3. This only works because the hierarchy in this dataset is exactly 3 levels deep
   (grandparent -> parent -> child) and every child has exactly one traceable
   grandparent. If some chains were shorter (a parent with no recorded parent of their
   own), those children would simply drop out of an inner join — switching to a `LEFT
   JOIN` would keep them with a `NULL` grandparent instead.

**Interview follow-up:** ask what happens if you need the **great-grandparent**
instead — a second self-join, `JOIN family_tree f3 ON f2.parent = f3.child`, extends
the pattern by one more level. Ask the follow-up question: at what point does adding
another `JOIN` per level stop being reasonable, and the query should switch to a
recursive CTE instead? The honest answer is "whenever the maximum depth isn't fixed
and known in advance" — a bounded, known depth is fine with chained joins; an
unbounded or data-dependent depth needs recursion, exactly as in
[Employee Hierarchy](../09-employee-hierarchy-recursive/README.md).
