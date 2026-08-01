# Team Capacity — Subset Sum

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Recursive CTE](https://img.shields.io/badge/-Recursive%20CTE-C0392B?style=flat-square) ![Combinatorics](https://img.shields.io/badge/-Combinatorics-2C3E50?style=flat-square)

## Problem Statement

Given a pool of employees each with a weekly capacity (in hours), a new project needs
a sub-team whose combined weekly capacity is **exactly 40 hours**. Find every
combination of employees that adds up to exactly 40.

## Problem Dataset

```sql
CREATE TABLE team_members (
    employee_id           INT,
    name                  VARCHAR(50),
    weekly_capacity_hours INT
);

INSERT INTO team_members VALUES
(1, 'Aarav',  10),
(2, 'Bhavna', 15),
(3, 'Chetan', 20),
(4, 'Divya',   5),
(5, 'Esha',   25),
(6, 'Farhan', 30);
```

Expected output:

| team                   | total_hours |
|-------------------------|---------------|
| {Aarav, Divya, Esha}     | 40            |
| {Aarav, Farhan}          | 40            |
| {Bhavna, Chetan, Divya}  | 40            |
| {Bhavna, Esha}           | 40            |

Four distinct sub-teams hit exactly 40 hours; every other combination either falls
short or overshoots.

## Problem Explanation

This is the classic **subset sum** problem, which has no closed-form aggregate
solution — you genuinely have to enumerate combinations. SQL can do this with a
**recursive CTE that builds combinations instead of hierarchies**: each recursion step
adds one more employee (with a higher `employee_id` than the last one added, to avoid
generating both `{Aarav, Divya}` and `{Divya, Aarav}` as separate "different"
combinations), and a `WHERE` clause **prunes** any partial combination that has already
exceeded 40 — without that prune, the recursion would explore every possible subset of
all 6 employees before filtering, which gets expensive fast as the pool grows.

## Problem Answer & Explanation

```sql
WITH RECURSIVE combos AS (
    -- anchor: every single employee is a size-1 combination
    SELECT
        employee_id,
        weekly_capacity_hours AS total_hours,
        ARRAY[name]::TEXT[]   AS team
    FROM team_members

    UNION ALL

    -- recursive step: extend a combination with an employee later in employee_id order
    SELECT
        e.employee_id,
        c.total_hours + e.weekly_capacity_hours,
        c.team || e.name
    FROM combos c
    JOIN team_members e ON e.employee_id > c.employee_id
    WHERE c.total_hours + e.weekly_capacity_hours <= 40   -- prune: never add past the target
)
SELECT team, total_hours
FROM combos
WHERE total_hours = 40
ORDER BY team;
```

**Why it works**

1. The **anchor member** seeds the recursion with all six single-employee
   "combinations" — each one is trivially a valid starting point.
2. The **recursive member** joins each existing combination back to `team_members`,
   but only to employees whose `employee_id` is *greater than* the last one added
   (`e.employee_id > c.employee_id`). Since combinations are built by always
   appending a higher id, `{Aarav(1), Divya(4)}` can only ever be generated once — the
   reverse order never gets explored, which is what keeps this an *unordered*
   combination search instead of a permutation search (which would 2x-6x overcount).
3. The `WHERE` clause inside the recursive term prunes any branch that has already
   passed 40 — an essential optimization, since without it the recursion keeps
   growing every combination all the way up to all 6 employees before the outer
   filter discards the too-large ones.
4. The final `WHERE total_hours = 40` keeps only combinations that hit the target
   exactly; loosen it to `<= 40` (with `ORDER BY total_hours DESC`) to instead find
   the best-fitting combination that doesn't exceed the budget.

**Interview follow-up:** ask how this scales — recursive-CTE subset sum is
exponential in the number of rows considered, so it's fine for a pool of a dozen
candidates but not hundreds; at that scale you'd push the problem to application code
(dynamic programming) or a database extension built for combinatorial search, and use
SQL only to pull the candidate pool.
