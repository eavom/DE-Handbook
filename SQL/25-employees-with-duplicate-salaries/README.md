# Employees With Duplicate Salaries

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Self-Join](https://img.shields.io/badge/-Self--Join-16A085?style=flat-square)

> Adapted from `Scenerio1.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a table of workers, return every worker whose salary is shared by at least one
other worker (i.e. their salary is not unique in the table).

## Problem Dataset

```sql
CREATE TABLE workers (
    worker_id   VARCHAR(5),
    first_name  VARCHAR(30),
    last_name   VARCHAR(30),
    salary      NUMERIC,
    department  VARCHAR(20)
);

INSERT INTO workers VALUES
('001', 'Monika',   'Arora',    100000, 'HR'),
('002', 'Niharika', 'Verma',    300000, 'Admin'),
('003', 'Vishal',   'Singhal',  300000, 'HR'),
('004', 'Amitabh',  'Singh',    500000, 'Admin'),
('005', 'Vivek',    'Bhati',    500000, 'Admin');
```

Expected output:

| worker_id | first_name | last_name | salary | department |
|-----------|-------------|-----------|---------|-------------|
| 002       | Niharika    | Verma     | 300000  | Admin       |
| 003       | Vishal      | Singhal   | 300000  | HR          |
| 004       | Amitabh     | Singh     | 500000  | Admin       |
| 005       | Vivek       | Bhati     | 500000  | Admin       |

Monika Arora (100000) is correctly excluded — she's the only worker at that salary.

## Problem Explanation

"Does this value repeat elsewhere in the table" is a self-comparison problem: every
row needs to be checked against every *other* row for a matching salary. A self-join
on `salary` does exactly that — join the table to itself where the salary matches but
the worker id doesn't, and any row that finds a match survives.

## Problem Answer & Explanation

```sql
SELECT a.worker_id, a.first_name, a.last_name, a.salary, a.department
FROM workers a
JOIN workers b ON a.salary = b.salary AND a.worker_id <> b.worker_id
ORDER BY a.salary, a.worker_id;
```

**Why it works**

1. `a.salary = b.salary` finds rows with a matching salary; `a.worker_id <> b.worker_id`
   excludes a row from being considered its own "duplicate" (without this, every row
   would trivially match itself).
2. Because this is a plain `JOIN` (not `<`), each duplicated pair produces matches in
   both directions — Niharika finds Vishal, and Vishal finds Niharika — so both
   appear in the output. This is deliberately different from a pair-generation
   self-join like [Round Robin Unique Pairs](../19-round-robin-unique-pairs/README.md),
   which uses `<` specifically to produce each pair only once; here the goal is "list
   every worker with a duplicate," not "list every duplicate pair," so both directions
   are wanted.
3. If three or more workers shared the same salary, every one of them would still
   appear exactly once in the result — each finds at least one match, regardless of
   how many others share the value.

**Interview follow-up:** ask how you'd instead return only the *count* of workers
sharing each duplicated salary, without listing every worker — that drops the
self-join entirely in favor of `GROUP BY salary HAVING COUNT(*) > 1`, which is
simpler and faster; the self-join version is really only needed when you want the
full row detail alongside the duplicate flag.
