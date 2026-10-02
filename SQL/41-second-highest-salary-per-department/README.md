# Second-Highest Salary per Department

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![DENSE_RANK](https://img.shields.io/badge/-DENSE__RANK-8E44AD?style=flat-square) ![JOIN](https://img.shields.io/badge/-JOIN-16A085?style=flat-square)

> Adapted from `Scenerio30.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given employees (with a department code) and a department lookup table, find the
employee with the **second-highest** salary in each department.

## Problem Dataset

```sql
CREATE TABLE emp_dept (
    emp_id  INT,
    name    VARCHAR(5),
    dept_id VARCHAR(5),
    salary  NUMERIC
);
INSERT INTO emp_dept VALUES
(1, 'A', 'A', 1000000),
(2, 'B', 'A', 2500000),
(3, 'C', 'G',  500000),
(4, 'D', 'G',  800000),
(5, 'E', 'W', 9000000),
(6, 'F', 'W', 2000000);

CREATE TABLE dept_lookup (
    dept_id   VARCHAR(5),
    dept_name VARCHAR(10)
);
INSERT INTO dept_lookup VALUES ('A', 'AZURE'), ('G', 'GCP'), ('W', 'AWS');
```

Expected output:

| emp_id | name | dept_name | salary   |
|--------|-------|-------------|------------|
| 6      | F     | AWS         | 2000000    |
| 1      | A     | AZURE       | 1000000    |
| 3      | C     | GCP         | 500000     |

## Problem Explanation

This is the classic "Nth highest per group" interview question — the natural harder
sibling of [Employee Salary by Department](../10-employee-salary-by-department/README.md),
which asked for the *top* earner per department. "2nd highest" can't be answered with
a simple `MAX()`; it needs the same rank-then-filter approach, just with the filter
changed from `= 1` to `= 2`. `DENSE_RANK()` is the right ranking function for "Nth
highest" specifically — it's the only one of the three ranking functions where "2nd
highest" reliably means "the 2nd *distinct* salary value," regardless of how many
employees are tied at 1st place.

## Problem Answer & Explanation

```sql
WITH ranked AS (
    SELECT
        e.emp_id, e.name, d.dept_name, e.salary,
        DENSE_RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS salary_rank
    FROM emp_dept e
    JOIN dept_lookup d ON e.dept_id = d.dept_id
)
SELECT emp_id, name, dept_name, salary
FROM ranked
WHERE salary_rank = 2
ORDER BY dept_name;
```

**Why it works**

1. The `JOIN` to `dept_lookup` replaces the raw `dept_id` code with a readable
   `dept_name` — a plain lookup join, independent of the ranking logic.
2. `DENSE_RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC)` ranks salaries
   within each department, highest first.
3. `WHERE salary_rank = 2` picks out the second-highest **distinct** salary value's
   employee(s) per department. Contrast with `RANK()`: if two employees in a
   department tied for 1st place, `RANK()` would skip rank 2 entirely (the next
   employee would be rank 3), and `WHERE salary_rank = 2` would return nothing for
   that department — clearly not what "2nd highest" should mean when there's a genuine
   3rd distinct salary value waiting right behind the tie.

**Interview follow-up:** ask the candidate to trace through what `ROW_NUMBER()` would
do differently here if two employees tied for the department's *highest* salary —
`ROW_NUMBER()` would arbitrarily assign one of them rank 1 and the other rank 2,
making the "2nd highest" result actually just be the *other person tied for 1st* —
silently wrong. This is the same ties-change-the-answer lesson from
[Top-Selling Product per Year](../29-top-selling-product-per-year/README.md), applied
to a scenario where getting it wrong is easy to miss without deliberately tied test
data.
