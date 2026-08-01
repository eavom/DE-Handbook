# SQL Practice — Master Index

![Total](https://img.shields.io/badge/Total-24-2980B9?style=flat-square) ![Written](https://img.shields.io/badge/Written-9-brightgreen?style=flat-square) ![Planned](https://img.shields.io/badge/Planned-15-lightgrey?style=flat-square)

A catalog of every SQL interview/practice question in this folder, tagged by
difficulty, query type, and SQL technique. Each row links to that question's own
folder, which has the full problem statement, dataset, and answer with explanation.

---

## Difficulty Rubric

Difficulty is assigned by how many concepts a solution combines, not by topic name —
a question using window functions can still be Basic if it applies just one function
directly.

| Level | Badge | Criteria |
|---|---|---|
| **Basic** | ![Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) | One concept applied directly — a single aggregation, a single `CASE`, or one non-partitioned window function. Usually one table, no more than one CTE. |
| **Intermediate** | ![Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) | Two or more concepts combined — a partitioned window function, a window function plus a join, `HAVING` plus aggregation, or gaps-and-islands with a single break condition. |
| **Advanced** | ![Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) | Recursive CTEs, graph traversal, gaps-and-islands with a *compound* break condition, or a gaps-and-islands result that needs an extra optimization/selection step layered on top (e.g. "smallest sufficient block"). |
| **Multi-Part** | ![Multi-Part](https://img.shields.io/badge/Difficulty-Multi--Part-blueviolet?style=flat-square) | A bundle of independent questions sharing one schema. The bundle itself isn't scored — open the file; every sub-question has its own Basic/Intermediate/Advanced tag. |

## Query Type

![DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) data query (`SELECT`) · ![DML](https://img.shields.io/badge/Query%20Type-DML-E67E22?style=flat-square) data modification (`INSERT`/`UPDATE`/`DELETE`/`MERGE`) · ![DDL](https://img.shields.io/badge/Query%20Type-DDL-7F8C8D?style=flat-square) schema definition (`CREATE`/`ALTER`)

Every question written so far is answered with **DQL**. `CREATE TABLE`/`INSERT`
statements only appear in problem setup data, never in the answer. There's no DML or
DDL question yet — see [Coverage Gaps](#coverage-gaps) below for candidates.

## Technique Color Legend

| Family | Color | Techniques |
|---|---|---|
| Window Functions | ![.](https://img.shields.io/badge/-8E44AD?style=flat-square) | Window Functions, Running Total, LAG, LEAD, ROW_NUMBER, RANK, Partitioning, COUNT OVER |
| Gaps & Islands | ![.](https://img.shields.io/badge/-E67E22?style=flat-square) | Gaps & Islands |
| Recursive / Hierarchical | ![.](https://img.shields.io/badge/-C0392B?style=flat-square) | Recursive CTE, Self-Referencing Hierarchy, Graph Traversal |
| Aggregation | ![.](https://img.shields.io/badge/-27AE60?style=flat-square) | GROUP BY, Conditional Aggregation (CASE/FILTER), HAVING, Pivoting |
| Joins | ![.](https://img.shields.io/badge/-16A085?style=flat-square) | JOIN, Anti-Join |
| Date Functions | ![.](https://img.shields.io/badge/-E91E63?style=flat-square) | Date Functions |
| String Functions | ![.](https://img.shields.io/badge/-F39C12?style=flat-square) | String Aggregation, String Concatenation |
| Array Functions | ![.](https://img.shields.io/badge/-7F8C8D?style=flat-square) | Array Functions, Array Aggregation |
| SCD | ![.](https://img.shields.io/badge/-8B0000?style=flat-square) | SCD Type 2 |

---

## All Questions

| # | Question | Difficulty | Query Type | Techniques |
|---|----------|------------|------------|------------|
| 01 | [Banking Customer Category](01-banking-customer-category/README.md) | ![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) | ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) | ![Conditional Aggregation (CASE/FILTER)](https://img.shields.io/badge/-Conditional%20Aggregation%20%28CASE%2FFILTER%29-27AE60?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square) |
| 02 | [Running Sum, Next Value, Previous Value](02-running-sum-next-prev/README.md) | ![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) | ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) | ![Window Functions](https://img.shields.io/badge/-Window%20Functions-8E44AD?style=flat-square) ![Running Total](https://img.shields.io/badge/-Running%20Total-8E44AD?style=flat-square) ![LAG/LEAD](https://img.shields.io/badge/-LAG%2FLEAD-8E44AD?style=flat-square) |
| 03 | [Connecting Flights — Minimum Hops Path](03-connecting-flights-min-hops/README.md) | ![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) | ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) | ![Recursive CTE](https://img.shields.io/badge/-Recursive%20CTE-C0392B?style=flat-square) ![Graph Traversal](https://img.shields.io/badge/-Graph%20Traversal-C0392B?style=flat-square) ![Array Functions](https://img.shields.io/badge/-Array%20Functions-7F8C8D?style=flat-square) |
| 04 | [Consecutive Logins With Dates](04-consecutive-logins-streak/README.md) | ![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) | ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) | ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) ![ROW_NUMBER](https://img.shields.io/badge/-ROW__NUMBER-8E44AD?style=flat-square) ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square) ![JOIN](https://img.shields.io/badge/-JOIN-16A085?style=flat-square) |
| 05 | [Consecutive Free Desks — Best Fit](05-consecutive-free-desks-best-fit/README.md) | ![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) | ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) | ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) ![ROW_NUMBER](https://img.shields.io/badge/-ROW__NUMBER-8E44AD?style=flat-square) ![Array Aggregation](https://img.shields.io/badge/-Array%20Aggregation-7F8C8D?style=flat-square) |
| 06 | [Customer & Orders Analytics (Multi-Part)](06-customer-and-orders-analytics/README.md) | ![Difficulty: Multi-Part](https://img.shields.io/badge/Difficulty-Multi--Part-blueviolet?style=flat-square) | ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) | ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square) ![JOIN](https://img.shields.io/badge/-JOIN-16A085?style=flat-square) ![Anti-Join](https://img.shields.io/badge/-Anti--Join-16A085?style=flat-square) ![RANK](https://img.shields.io/badge/-RANK-8E44AD?style=flat-square) ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square) ![HAVING](https://img.shields.io/badge/-HAVING-27AE60?style=flat-square) ![String Aggregation](https://img.shields.io/badge/-String%20Aggregation-F39C12?style=flat-square) ![Pivoting](https://img.shields.io/badge/-Pivoting-27AE60?style=flat-square) ![Conditional Aggregation (CASE/FILTER)](https://img.shields.io/badge/-Conditional%20Aggregation%20%28CASE%2FFILTER%29-27AE60?style=flat-square) |
| 07 | [SCD Type 2 — Merge Adjacent Duplicate Rows](07-scd2-merge-adjacent-rows/README.md) | ![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) | ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) | ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) ![LAG](https://img.shields.io/badge/-LAG-8E44AD?style=flat-square) ![Running Total](https://img.shields.io/badge/-Running%20Total-8E44AD?style=flat-square) ![SCD Type 2](https://img.shields.io/badge/-SCD%20Type%202-8B0000?style=flat-square) |
| 08 | [Employee Referral — Running Total & Latest Referral](08-employee-referral-running-total/README.md) | ![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) | ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) | ![Window Functions](https://img.shields.io/badge/-Window%20Functions-8E44AD?style=flat-square) ![Running Total](https://img.shields.io/badge/-Running%20Total-8E44AD?style=flat-square) ![Partitioning](https://img.shields.io/badge/-Partitioning-8E44AD?style=flat-square) ![ROW_NUMBER](https://img.shields.io/badge/-ROW__NUMBER-8E44AD?style=flat-square) ![COUNT OVER](https://img.shields.io/badge/-COUNT%20OVER-8E44AD?style=flat-square) |
| 09 | [Employee Hierarchy — Recursive Reporting Chain](09-employee-hierarchy-recursive/README.md) | ![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) | ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) | ![Recursive CTE](https://img.shields.io/badge/-Recursive%20CTE-C0392B?style=flat-square) ![Self-Referencing Hierarchy](https://img.shields.io/badge/-Self--Referencing%20Hierarchy-C0392B?style=flat-square) ![String Concatenation](https://img.shields.io/badge/-String%20Concatenation-F39C12?style=flat-square) |

---

## By Difficulty

**![Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square)** — [01 Banking Customer Category](01-banking-customer-category/README.md) · [02 Running Sum/Next/Prev](02-running-sum-next-prev/README.md)

**![Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square)** — [04 Consecutive Logins Streak](04-consecutive-logins-streak/README.md) · [08 Employee Referral Running Total](08-employee-referral-running-total/README.md)

**![Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square)** — [03 Connecting Flights](03-connecting-flights-min-hops/README.md) · [05 Consecutive Free Desks](05-consecutive-free-desks-best-fit/README.md) · [07 SCD Type 2 Merge](07-scd2-merge-adjacent-rows/README.md) · [09 Employee Hierarchy](09-employee-hierarchy-recursive/README.md)

**![Multi-Part](https://img.shields.io/badge/Difficulty-Multi--Part-blueviolet?style=flat-square)** — [06 Customer & Orders Analytics](06-customer-and-orders-analytics/README.md) (13 sub-questions, individually tagged Basic → Advanced inside the file)

## By SQL Technique

**Window Functions family**
![Window Functions](https://img.shields.io/badge/-Window%20Functions-8E44AD?style=flat-square) [02](02-running-sum-next-prev/README.md) · [08](08-employee-referral-running-total/README.md)
![Running Total](https://img.shields.io/badge/-Running%20Total-8E44AD?style=flat-square) [02](02-running-sum-next-prev/README.md) · [07](07-scd2-merge-adjacent-rows/README.md) · [08](08-employee-referral-running-total/README.md)
![LAG/LEAD](https://img.shields.io/badge/-LAG%2FLEAD-8E44AD?style=flat-square) [02](02-running-sum-next-prev/README.md) · ![LAG](https://img.shields.io/badge/-LAG-8E44AD?style=flat-square) [07](07-scd2-merge-adjacent-rows/README.md)
![ROW_NUMBER](https://img.shields.io/badge/-ROW__NUMBER-8E44AD?style=flat-square) [04](04-consecutive-logins-streak/README.md) · [05](05-consecutive-free-desks-best-fit/README.md) · [08](08-employee-referral-running-total/README.md)
![RANK](https://img.shields.io/badge/-RANK-8E44AD?style=flat-square) [06](06-customer-and-orders-analytics/README.md)
![Partitioning](https://img.shields.io/badge/-Partitioning-8E44AD?style=flat-square) [08](08-employee-referral-running-total/README.md) · ![COUNT OVER](https://img.shields.io/badge/-COUNT%20OVER-8E44AD?style=flat-square) [08](08-employee-referral-running-total/README.md)

**Gaps & Islands**
![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) [04](04-consecutive-logins-streak/README.md) · [05](05-consecutive-free-desks-best-fit/README.md) · [07](07-scd2-merge-adjacent-rows/README.md)

**Recursive / Hierarchical**
![Recursive CTE](https://img.shields.io/badge/-Recursive%20CTE-C0392B?style=flat-square) [03](03-connecting-flights-min-hops/README.md) · [09](09-employee-hierarchy-recursive/README.md)
![Graph Traversal](https://img.shields.io/badge/-Graph%20Traversal-C0392B?style=flat-square) [03](03-connecting-flights-min-hops/README.md) · ![Self-Referencing Hierarchy](https://img.shields.io/badge/-Self--Referencing%20Hierarchy-C0392B?style=flat-square) [09](09-employee-hierarchy-recursive/README.md)

**Aggregation**
![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square) [01](01-banking-customer-category/README.md) · [06](06-customer-and-orders-analytics/README.md)
![Conditional Aggregation (CASE/FILTER)](https://img.shields.io/badge/-Conditional%20Aggregation%20%28CASE%2FFILTER%29-27AE60?style=flat-square) [01](01-banking-customer-category/README.md) · [06](06-customer-and-orders-analytics/README.md)
![HAVING](https://img.shields.io/badge/-HAVING-27AE60?style=flat-square) [06](06-customer-and-orders-analytics/README.md) · ![Pivoting](https://img.shields.io/badge/-Pivoting-27AE60?style=flat-square) [06](06-customer-and-orders-analytics/README.md)

**Joins**
![JOIN](https://img.shields.io/badge/-JOIN-16A085?style=flat-square) [04](04-consecutive-logins-streak/README.md) · [06](06-customer-and-orders-analytics/README.md)
![Anti-Join](https://img.shields.io/badge/-Anti--Join-16A085?style=flat-square) [06](06-customer-and-orders-analytics/README.md)

**Date Functions**
![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square) [04](04-consecutive-logins-streak/README.md) · [06](06-customer-and-orders-analytics/README.md)

**String Functions**
![String Aggregation](https://img.shields.io/badge/-String%20Aggregation-F39C12?style=flat-square) [06](06-customer-and-orders-analytics/README.md) · ![String Concatenation](https://img.shields.io/badge/-String%20Concatenation-F39C12?style=flat-square) [09](09-employee-hierarchy-recursive/README.md)

**Array Functions**
![Array Functions](https://img.shields.io/badge/-Array%20Functions-7F8C8D?style=flat-square) [03](03-connecting-flights-min-hops/README.md) · ![Array Aggregation](https://img.shields.io/badge/-Array%20Aggregation-7F8C8D?style=flat-square) [05](05-consecutive-free-desks-best-fit/README.md)

**SCD**
![SCD Type 2](https://img.shields.io/badge/-SCD%20Type%202-8B0000?style=flat-square) [07](07-scd2-merge-adjacent-rows/README.md)

---

## Planned (10–24)

These folders exist with a topic name but no `README.md` yet. Techniques shown are a
best guess from the folder name only — confirm once each question is actually written.

| # | Folder | Guessed Techniques |
|---|--------|---------------------|
| 10 | employee-salary-by-department | ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square) |
| 11 | salary-prev-next-with-gaps | ![LAG/LEAD](https://img.shields.io/badge/-LAG%2FLEAD-8E44AD?style=flat-square) ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) |
| 12 | event-analysis-sessions-and-signups | ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square) ![Window Functions](https://img.shields.io/badge/-Window%20Functions-8E44AD?style=flat-square) |
| 13 | explode-and-aggregate-skills | ![Array Functions](https://img.shields.io/badge/-Array%20Functions-7F8C8D?style=flat-square) |
| 14 | gaps-and-islands-zero-balance | ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) |
| 15 | join-cardinality-with-nulls | ![JOIN](https://img.shields.io/badge/-JOIN-16A085?style=flat-square) |
| 16 | customer-order-running-total | ![Running Total](https://img.shields.io/badge/-Running%20Total-8E44AD?style=flat-square) |
| 17 | payroll-hours-and-pay | ![Date Functions](https://img.shields.io/badge/-Date%20Functions-E91E63?style=flat-square) |
| 18 | team-capacity-subset-sum | ![Recursive CTE](https://img.shields.io/badge/-Recursive%20CTE-C0392B?style=flat-square) |
| 19 | round-robin-unique-pairs | ![JOIN](https://img.shields.io/badge/-JOIN-16A085?style=flat-square) |
| 20 | fill-forward-missing-category | ![Window Functions](https://img.shields.io/badge/-Window%20Functions-8E44AD?style=flat-square) |
| 21 | recipe-page-imposition | ![Window Functions](https://img.shields.io/badge/-Window%20Functions-8E44AD?style=flat-square) |
| 22 | top-salesperson-per-region | ![RANK](https://img.shields.io/badge/-RANK-8E44AD?style=flat-square) ![GROUP BY](https://img.shields.io/badge/-GROUP%20BY-27AE60?style=flat-square) |
| 23 | server-uptime-longest-streak | ![Gaps & Islands](https://img.shields.io/badge/-Gaps%20%26%20Islands-E67E22?style=flat-square) |
| 24 | shopping-budget-greedy-knapsack | ![Recursive CTE](https://img.shields.io/badge/-Recursive%20CTE-C0392B?style=flat-square) |

## Coverage Gaps

No question currently answers with **DML** or **DDL**, and none uses a lambda-style
array construct (Snowflake/BigQuery `TRANSFORM`/`FILTER` on arrays aren't standard SQL,
so there's no direct equivalent here). Folder 13 (explode/aggregate skills) is a
natural home for array-lambda functions when written; a new SCD/upsert question
(answered with `MERGE`) would be a good DML candidate.
