# Employee Salary by Department

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square) ![RANK](https://img.shields.io/badge/-RANK-8E44AD?style=flat-square)

## Problem Statement

Given a table of employees with their department and salary, produce two views:

1. A department rollup — headcount, total salary, average salary, and max salary.
2. The highest-paid employee(s) in each department. If two employees in the same
   department are tied for the top salary, both should be returned.

## Problem Dataset

```sql
CREATE TABLE employees (
    emp_id     INT,
    emp_name   VARCHAR(50),
    department VARCHAR(30),
    salary     NUMERIC
);

INSERT INTO employees VALUES
(1, 'Rohan Mehta',    'Engineering', 95000),
(2, 'Sneha Kulkarni',  'Engineering', 110000),
(3, 'Aditya Rao',      'Engineering', 110000),
(4, 'Pooja Nair',      'Sales',        62000),
(5, 'Vivek Iyer',      'Sales',        71000),
(6, 'Divya Menon',     'Sales',        58000),
(7, 'Kunal Shah',      'HR',           49000),
(8, 'Ritika Bose',     'HR',           52000),
(9, 'Manish Verma',    'Finance',      88000);
```

Expected output (part 1 — department rollup):

| department  | headcount | total_salary | avg_salary | max_salary |
|-------------|-----------|---------------|------------|------------|
| Engineering | 3         | 315000        | 105000.00  | 110000     |
| Finance     | 1         | 88000         | 88000.00   | 88000      |
| HR          | 2         | 101000        | 50500.00   | 52000      |
| Sales       | 3         | 191000        | 63666.67   | 71000      |

Expected output (part 2 — top earner per department, ties included):

| department  | emp_name       | salary |
|-------------|-----------------|--------|
| Engineering | Aditya Rao      | 110000 |
| Engineering | Sneha Kulkarni  | 110000 |
| Finance     | Manish Verma    | 88000  |
| HR          | Ritika Bose     | 52000  |
| Sales       | Vivek Iyer      | 71000  |

## Problem Explanation

Part 1 is a plain `GROUP BY` rollup. Part 2 looks like it should be a `MAX(salary)`
per department, but that only gives you the salary value — not *which* employee(s)
earn it, and a naive `WHERE salary = (SELECT MAX(salary) ...)` correlated subquery
gets awkward once you need it per-department. `RANK() OVER (PARTITION BY department
ORDER BY salary DESC)` solves both problems in one pass: it ranks every employee
within their department, and — critically — using `RANK()` instead of `ROW_NUMBER()`
means a genuine tie (Sneha and Aditya both at 110000) correctly produces two `rnk = 1`
rows instead of arbitrarily picking one.

## Problem Answer & Explanation

**1. Department rollup**

```sql
SELECT
    department,
    COUNT(*)              AS headcount,
    SUM(salary)            AS total_salary,
    ROUND(AVG(salary), 2)  AS avg_salary,
    MAX(salary)            AS max_salary
FROM employees
GROUP BY department
ORDER BY department;
```

**2. Highest-paid employee(s) per department**

```sql
SELECT department, emp_name, salary
FROM (
    SELECT
        department,
        emp_name,
        salary,
        RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rnk
    FROM employees
) ranked
WHERE rnk = 1
ORDER BY department, emp_name;
```

**Why it works**

1. `RANK() OVER (PARTITION BY department ORDER BY salary DESC)` restarts the ranking
   for every department, so each department's own top earner(s) get `rnk = 1`
   independent of what other departments' salaries look like.
2. `RANK()` (not `ROW_NUMBER()`) is the deliberate choice: ties share the same rank
   and both surface in the result, which is what "highest-paid employee(s)" — plural —
   actually asks for.
3. The outer `WHERE rnk = 1` filter has to live outside the window function's own
   `SELECT`, since window functions can't be referenced directly in a `WHERE` clause
   — hence the wrapping subquery.

**Interview follow-up:** ask what changes if the requirement becomes "top *2* earners
per department" — only the filter changes (`WHERE rnk <= 2`), which is exactly why
`RANK()` generalizes better here than a `MAX()`-based approach that would need to be
rewritten entirely for "top N."
