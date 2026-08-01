# Top Salesperson Per Region

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square) ![RANK](https://img.shields.io/badge/-RANK-8E44AD?style=flat-square)

## Problem Statement

Given individual sale transactions, find the top-selling salesperson (by total sale
amount) in each region.

## Problem Dataset

```sql
CREATE TABLE sales (
    sale_id     INT,
    region      VARCHAR(20),
    salesperson VARCHAR(30),
    amount      NUMERIC
);

INSERT INTO sales VALUES
(1, 'North', 'Kabir Anand',  12000),
(2, 'North', 'Kabir Anand',   8000),
(3, 'North', 'Leela Nair',   15000),
(4, 'South', 'Meera Pillai',  9000),
(5, 'South', 'Meera Pillai',  9000),
(6, 'South', 'Naveen Raj',   11000),
(7, 'East',  'Om Prakash',   20000);
```

Expected output:

| region | salesperson  | total_sales |
|--------|---------------|----------------|
| East   | Om Prakash    | 20000          |
| North  | Kabir Anand   | 20000          |
| South  | Meera Pillai  | 18000          |

Kabir Anand wins North with two transactions totaling 20,000, beating Leela Nair's
single 15,000 sale — a reminder that "top salesperson" means top by **total**
revenue, not top by single largest sale.

## Problem Explanation

This is a two-step problem disguised as one: first roll individual transactions up to
a total per (region, salesperson), then rank those totals within each region and keep
only the winner. Doing it in one un-nested query (e.g. `MAX(SUM(amount))`) doesn't
work because you also need to know *which* salesperson produced that max — the same
"aggregate first, then rank" shape as [Employee Salary by Department](../10-employee-salary-by-department/README.md).

## Problem Answer & Explanation

```sql
WITH totals AS (
    SELECT region, salesperson, SUM(amount) AS total_sales
    FROM sales
    GROUP BY region, salesperson
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY region ORDER BY total_sales DESC) AS rnk
    FROM totals
)
SELECT region, salesperson, total_sales
FROM ranked
WHERE rnk = 1
ORDER BY region;
```

**Why it works**

1. `totals` first collapses every transaction down to one row per
   (region, salesperson) — this has to happen before ranking, since ranking
   individual transactions would let a salesperson's *biggest single sale* win
   instead of their total.
2. `RANK() OVER (PARTITION BY region ORDER BY total_sales DESC)` restarts the ranking
   independently per region, so East's single salesperson and North's two
   salespeople don't interfere with each other's ranks.
3. `RANK()` over `ROW_NUMBER()` again matters for ties — if two salespeople in the
   same region tied for the top total, both should show up as the region's winner
   rather than one being arbitrarily dropped.
4. Filtering `rnk = 1` after the fact (rather than trying to filter inside the window
   function's own query) is required because window function results aren't visible
   to the `WHERE` clause of the same `SELECT` they're computed in.

**Interview follow-up:** ask how the query changes if "top salesperson" should be
weighted by **number of deals** as a tiebreaker (e.g. more deals wins if totals are
equal) — add a second `ORDER BY` key inside the same window:
`RANK() OVER (PARTITION BY region ORDER BY total_sales DESC, deal_count DESC)`, where
`deal_count` would need to be added to the `totals` CTE as `COUNT(*)`.
