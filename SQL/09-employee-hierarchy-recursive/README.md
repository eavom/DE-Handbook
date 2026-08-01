# Employee Hierarchy — Recursive Reporting Chain

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Recursive CTE](https://img.shields.io/badge/-Recursive%20CTE-C0392B?style=flat-square) ![Self-Referencing Hierarchy](https://img.shields.io/badge/-Self--Referencing%20Hierarchy-C0392B?style=flat-square) ![String Concatenation](https://img.shields.io/badge/-String%20Concatenation-F39C12?style=flat-square)

## Problem Statement

Given an employee table with a self-referencing `reporting_to` manager column, find
every employee who reports **directly or indirectly** to a given manager ("Aarti").
For each match, show whether the relationship is `direct` or `indirect`, and render
the full reporting chain from Aarti down to that employee.

## Problem Dataset

```sql
CREATE TABLE employee (
    emp_id       INT,
    emp_name     VARCHAR(50),
    reporting_to INT,
    designation  VARCHAR(50)
);

INSERT INTO employee VALUES
(10, 'Darpan',  NULL, 'CTO'),
(21, 'Ramesh',  10,   'Manager'),
(22, 'Aarti',   10,   'Manager'),
(31, 'Shubham', 21,   'Tech Lead'),
(32, 'Ritesh',  22,   'Tech Lead'),
(41, 'Vaibhav', 31,   'Senior Engineer'),
(42, 'Ayesha',  32,   'Senior Engineer'),
(43, 'Nilesh',  32,   'Senior Engineer'),
(51, 'Heena',   44,   'Junior Engineer'),   -- reports to a manager not in this subtree
(52, 'Kiran',   43,   'Junior Engineer');
```

Expected output:

| emp_id | emp_name | direction | hierarchy_tree                        |
|--------|----------|-----------|-----------------------------------------|
| 32     | Ritesh   | direct    | Aarti -> Ritesh                         |
| 42     | Ayesha   | indirect  | Aarti -> Ritesh -> Ayesha               |
| 43     | Nilesh   | indirect  | Aarti -> Ritesh -> Nilesh               |
| 52     | Kiran    | indirect  | Aarti -> Ritesh -> Nilesh -> Kiran      |

## Problem Explanation

A self-referencing "manager id" column is the classic use case for a
**recursive CTE**: start at the anchor employee (Aarti), then repeatedly join to find
everyone whose `reporting_to` matches someone already found, accumulating depth and a
display path as you go. Depth `1` is `direct`; anything deeper is `indirect`.

## Problem Answer & Explanation

```sql
WITH RECURSIVE reports AS (
    -- anchor: Aarti herself, depth 0, not part of the output
    SELECT emp_id, emp_name, 0 AS depth, emp_name::TEXT AS hierarchy_tree
    FROM employee
    WHERE emp_name = 'Aarti'

    UNION ALL

    -- recursive step: anyone reporting to someone already in `reports`
    SELECT e.emp_id, e.emp_name, r.depth + 1, r.hierarchy_tree || ' -> ' || e.emp_name
    FROM employee e
    JOIN reports r ON e.reporting_to = r.emp_id
)
SELECT
    emp_id,
    emp_name,
    CASE WHEN depth = 1 THEN 'direct' ELSE 'indirect' END AS direction,
    hierarchy_tree
FROM reports
WHERE depth > 0          -- exclude Aarti herself from the result
ORDER BY depth, emp_id;
```

**Why it works**

1. The anchor member picks Aarti as the root of the traversal, at `depth = 0` — she's
   in the working set so her direct reports can be found, but excluded from the final
   result with `WHERE depth > 0`.
2. The recursive member joins `employee` to the `reports` CTE **on itself**
   (`e.reporting_to = r.emp_id`): each iteration finds the next layer of reports one
   level deeper, and Postgres keeps re-running this join against the newly added rows
   until no new rows are produced.
3. `depth` increments once per recursion level, so `depth = 1` is a direct report and
   anything greater is indirect — no separate lookup needed.
4. `hierarchy_tree` is built incrementally by string-concatenating the parent's
   already-built path with the current employee's name, so the full chain is
   available at every depth without a second pass.
5. Heena (`51`) is correctly excluded — her `reporting_to` (`44`) doesn't exist in
   this subtree, so she never joins into `reports`.

**Interview follow-up:** ask what would go wrong with a malformed hierarchy that has a
cycle (e.g. A reports to B, B reports to A) — an unguarded recursive CTE would loop
forever. The fix is the same visited-set guard used in
[Connecting Flights](../03-connecting-flights-min-hops/README.md): track visited
`emp_id`s in an array and stop recursing if the next id is already present.
