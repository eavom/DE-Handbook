-- Databricks notebook source
-- MAGIC %md
-- MAGIC # DE-Handbook SQL Practice -- Databricks Compatibility Verification
-- MAGIC
-- MAGIC This notebook contains all 44 questions from `DE-Handbook/SQL`, rewritten wherever the
-- MAGIC original (Postgres-verified) query used syntax that Spark SQL / Databricks SQL does not
-- MAGIC support. Where a query needed NO changes, it appears unchanged. Where it needed a
-- MAGIC rewrite, a short comment explains what changed and why -- see the full write-up in
-- MAGIC `databricks_compatibility_report.md` for the reasoning behind every fix.
-- MAGIC
-- MAGIC **How to use this notebook:** run `CREATE SCHEMA IF NOT EXISTS de_handbook_verify; USE de_handbook_verify;`
-- MAGIC first, then run the cells for any question top-to-bottom (each question's `DROP TABLE IF EXISTS`
-- MAGIC statements make it safe to re-run). Compare each result grid against the "Expected output"
-- MAGIC table in that question's README -- they should match exactly, with two known cosmetic
-- MAGIC exceptions noted in the report (decimal-column display, and 0-based vs 1-based ordinality
-- MAGIC internals that don't affect final output).
-- MAGIC
-- MAGIC Questions using `WITH RECURSIVE` (03, 09, 18, 21, 24) require a Databricks Runtime / SQL
-- MAGIC warehouse recent enough to support recursive CTEs -- this is a newer Databricks-specific
-- MAGIC extension, not part of open-source Apache Spark. If those specific cells fail with a parser
-- MAGIC error and the rest of the notebook runs fine, that's the reason.

-- COMMAND ----------

CREATE SCHEMA IF NOT EXISTS de_handbook_verify;
USE de_handbook_verify;

-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 01: Banking Customer Category
-- MAGIC **Databricks changes:** FILTER(WHERE) -> CASE WHEN
-- COMMAND ----------
-- Setup: dataset for Question 01
DROP TABLE IF EXISTS transactions;

CREATE TABLE transactions (
    customer_id      INT,
    transaction_date DATE,
    transaction_type STRING,
    amount            NUMERIC
);

INSERT INTO transactions VALUES
(1, '2025-09-01', 'deposit',    12000),
(1, '2025-09-02', 'deposit',    15000),
(1, '2025-09-03', 'deposit',    11000),
(1, '2025-09-04', 'withdrawal',  5000),
(2, '2025-09-01', 'deposit',     6000),
(2, '2025-09-02', 'deposit',     7000),
(2, '2025-09-03', 'deposit',     6500),
(2, '2025-09-04', 'withdrawal',  2000),
(3, '2025-09-01', 'deposit',     3000),
(3, '2025-09-03', 'deposit',     4000),
(3, '2025-09-04', 'withdrawal',  1000);
-- COMMAND ----------
-- Primary answer (unchanged)
WITH customer_totals AS (
    SELECT
        customer_id,
        SUM(CASE WHEN transaction_type = 'deposit'    THEN amount ELSE 0 END)
          - SUM(CASE WHEN transaction_type = 'withdrawal' THEN amount ELSE 0 END)
          AS net_balance
    FROM transactions
    GROUP BY customer_id
)
SELECT
    customer_id,
    CASE
        WHEN net_balance >= 30000 THEN 'Premium Customer'
        WHEN net_balance >= 15000 THEN 'Gold Customer'
        ELSE 'Other Customer'
    END AS customer_category
FROM customer_totals
ORDER BY customer_id;
-- COMMAND ----------
-- Alternate (FILTER rewritten as CASE WHEN -- Spark SQL has no FILTER clause)
SELECT
    customer_id,
    SUM(CASE WHEN transaction_type = 'deposit'    THEN amount END)
      - SUM(CASE WHEN transaction_type = 'withdrawal' THEN amount END) AS net_balance
FROM transactions
GROUP BY customer_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 01:**
-- MAGIC - Postgres `FILTER (WHERE ...)` has no Spark SQL equivalent -> rewritten to `CASE WHEN ... THEN x END` inside the aggregate (NULL for non-matching rows, which SUM ignores, same as FILTER).
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 02: Running Sum, Next Value, Previous Value
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 02
DROP TABLE IF EXISTS numbers;

CREATE TABLE numbers (id INT);

INSERT INTO numbers VALUES (1), (2), (3), (4), (5);
-- COMMAND ----------
-- Primary answer (unchanged)
SELECT
    id,
    SUM(id) OVER (ORDER BY id) AS running_sum,
    LEAD(id) OVER (ORDER BY id) AS next_value,
    LAG(id)  OVER (ORDER BY id) AS prev_value
FROM numbers
ORDER BY id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 02:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 03: Connecting Flights - Minimum Hops Path
-- MAGIC **Databricks changes:** WITH RECURSIVE (caveat), ARRAY[...] -> array(), || -> concat(), ANY() -> array_contains(), UNNEST -> explode() (restructured)
-- COMMAND ----------
-- Setup: dataset for Question 03
DROP TABLE IF EXISTS flights;

CREATE TABLE flights (
    flight      STRING,
    source      STRING,
    destination STRING
);

INSERT INTO flights VALUES
('AIR 0087', 'Pune',      'Rajasthan'),
('AIR 0187', 'Delhi',     'Ahmedabad'),
('AIR 0767', 'Rajasthan', 'Delhi'),
('AIR 1678', 'Kolkata',   'Ahmedabad'),
('AIR 0369', 'Bangalore', 'Pune'),
('AIR 0029', 'Rajasthan', 'Ahmedabad'),
('AIR 8878', 'Delhi',     'Hyderabad');
-- COMMAND ----------
-- Primary answer (rewritten)
WITH RECURSIVE route AS (
    -- anchor: start at Bangalore
    SELECT
        flight,
        source,
        destination,
        1 AS hop_count,
        array(flight)             AS flight_path,
        array(source, destination) AS visited_cities
    FROM flights
    WHERE source = 'Bangalore'

    UNION ALL

    -- recursive step: extend the path by one more flight
    SELECT
        f.flight,
        f.source,
        f.destination,
        r.hop_count + 1,
        concat(r.flight_path, array(f.flight))       AS flight_path,
        concat(r.visited_cities, array(f.destination)) AS visited_cities
    FROM route r
    JOIN flights f
      ON f.source = r.destination
    WHERE r.destination <> 'Ahmedabad'
      AND NOT array_contains(r.visited_cities, f.destination)
),
winner AS (
    -- pick the single shortest route BEFORE exploding its array (avoids mixing
    -- a generator function with ORDER BY/LIMIT on the same query, which Spark
    -- does not resolve the same way Postgres does)
    SELECT flight_path
    FROM route
    WHERE destination = 'Ahmedabad'
    ORDER BY hop_count
    LIMIT 1
)
SELECT explode(flight_path) AS flight FROM winner;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 03:**
-- MAGIC - Recursive CTEs (`WITH RECURSIVE`) require a Databricks Runtime / SQL warehouse recent enough to support them (this is a fairly recent Databricks-specific extension, not part of open-source Apache Spark as of Spark 3.5). If your workspace errors on `WITH RECURSIVE` with a parser error, the runtime predates this feature and the traversal must be done procedurally in PySpark instead of pure SQL.
-- MAGIC - Postgres `ARRAY[x]` literal -> Spark `array(x)` function call.
-- MAGIC - Postgres `arr || elem` (array append) -> Spark `concat(arr, array(elem))`.
-- MAGIC - Postgres `elem = ANY(arr)` -> Spark `array_contains(arr, elem)`.
-- MAGIC - Restructured so `ORDER BY hop_count LIMIT 1` picks the winning row BEFORE `explode()` runs, instead of mixing a set-returning function with ORDER BY/LIMIT in one query (ambiguous/unsupported in Spark).
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 04: Consecutive Logins With Dates
-- MAGIC **Databricks changes:** INTERVAL*int -> date_sub()
-- COMMAND ----------
-- Setup: dataset for Question 04
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS login_history;

CREATE TABLE users (
    user_id INT,
    name    STRING,
    email   STRING
);

INSERT INTO users VALUES
(1, 'Aarti Sharma',     'aarti.sharma@code.code'),
(2, 'Nilesh Chaudhari', 'nilesh.chaudhari@code.code'),
(3, 'Meena Joshi',      'meena.joshi@code.code'),
(4, 'Karan Verma',      'karan.verma@code.code'),
(5, 'Ritu Deshmukh',    'ritu.deshmukh@code.code');

CREATE TABLE login_history (
    user_id    INT,
    login_date DATE
);

INSERT INTO login_history VALUES
(1, '2025-08-10'), (1, '2025-08-11'), (1, '2025-08-12'), (1, '2025-08-14'),
(2, '2025-08-09'), (2, '2025-08-10'), (2, '2025-08-11'), (2, '2025-08-13'),
(3, '2025-08-08'), (3, '2025-08-09'), (3, '2025-08-10'), (3, '2025-08-11'),
(3, '2025-08-15'), (3, '2025-08-16'), (3, '2025-08-17'),
(4, '2025-08-10'), (4, '2025-08-12'),
(5, '2025-08-10'), (5, '2025-08-11'), (5, '2025-08-13');
-- COMMAND ----------
-- Primary answer (rewritten)
WITH ranked AS (
    SELECT
        user_id,
        login_date,
        date_sub(login_date, CAST(ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        ) AS INT)) AS island_group
    FROM login_history
),
islands AS (
    SELECT
        user_id,
        MIN(login_date) AS login_date,
        MAX(login_date) AS logout_date,
        COUNT(*)        AS streak_length
    FROM ranked
    GROUP BY user_id, island_group
)
SELECT
    i.user_id,
    u.name,
    u.email,
    i.login_date,
    i.logout_date
FROM islands i
JOIN users u ON u.user_id = i.user_id
WHERE i.streak_length >= 3
ORDER BY i.user_id, i.login_date;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 04:**
-- MAGIC - Postgres `date - (n * INTERVAL '1 day')` -> Spark `date_sub(date, n)`, which takes a plain integer day-count directly and sidesteps any ambiguity around multiplying an INTERVAL by a column value.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 05: Consecutive Free Desks - Best Fit
-- MAGIC **Databricks changes:** ARRAY_AGG(...ORDER BY) -> sort_array(collect_list()), UNNEST -> explode() (restructured)
-- COMMAND ----------
-- Setup: dataset for Question 05
DROP TABLE IF EXISTS desk_allocation;

CREATE TABLE desk_allocation (
    desk_id     STRING,
    row_number  INT,
    is_free     STRING   -- 'X' = free, NULL = allocated
);

INSERT INTO desk_allocation VALUES
('SURF001', 1, NULL), ('SURF002', 1, 'X'), ('SURF003', 1, 'X'), ('SURF004', 1, 'X'), ('SURF005', 1, 'X'),
('SURF006', 2, 'X'),  ('SURF007', 2, NULL),('SURF008', 2, 'X'), ('SURF009', 2, NULL),('SURF010', 2, NULL),
('SURF011', 3, 'X'),  ('SURF012', 3, NULL),('SURF013', 3, 'X'), ('SURF014', 3, 'X'), ('SURF015', 3, 'X');
-- COMMAND ----------
-- Primary answer (rewritten)
WITH free_desks AS (
    SELECT
        desk_id,
        row_number,
        ROW_NUMBER() OVER (ORDER BY row_number, desk_id) AS overall_seq,
        ROW_NUMBER() OVER (PARTITION BY row_number ORDER BY desk_id) AS row_seq
    FROM desk_allocation
    WHERE is_free = 'X'
),
islands AS (
    SELECT
        row_number,
        overall_seq - row_seq AS island_group,
        MIN(desk_id) AS first_desk,
        MAX(desk_id) AS last_desk,
        COUNT(*)     AS block_size,
        sort_array(collect_list(desk_id)) AS desk_ids
    FROM free_desks
    GROUP BY row_number, overall_seq - row_seq
),
winner AS (
    SELECT desk_ids
    FROM islands
    WHERE block_size >= 3
    ORDER BY block_size ASC
    LIMIT 1
)
SELECT explode(desk_ids) AS desk_id FROM winner;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 05:**
-- MAGIC - `ARRAY_AGG(col ORDER BY col)` -> `sort_array(collect_list(col))` (ascending sort of the collected array; no duplicates exist in this dataset so `collect_list` vs `collect_set` doesn't matter here).
-- MAGIC - Same ORDER BY/LIMIT-before-explode restructuring as question 03.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 06: Customer & Orders Analytics (Multi-Part)
-- MAGIC **Databricks changes:** comma join -> CROSS JOIN, INTERVAL 'N months' -> INTERVAL N MONTH, row-tuple compare -> boolean expr, STRING_AGG(DISTINCT...ORDER BY) -> array_join(sort_array(collect_set())), FILTER(WHERE) -> CASE WHEN
-- COMMAND ----------
-- Setup: dataset for Question 06
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS orders;

CREATE TABLE customers (
    customer_id   INT,
    customer_name STRING,
    city          STRING,
    signup_date   DATE
);

INSERT INTO customers VALUES
(101, 'Aarav Sharma',  'Delhi',      '2022-01-15'),
(102, 'Meera Iyer',    'Mumbai',     '2022-02-20'),
(103, 'Raj Patel',     'Ahmedabad',  '2021-12-01'),
(104, 'Ananya Reddy',  'Hyderabad',  '2023-03-11'),
(105, 'Karan Singh',   'Chandigarh', '2022-07-30'),
(106, 'Priya Desai',   'Surat',      '2023-01-05'),
(107, 'Arjun Menon',   'Kochi',      '2021-11-18'),
(108, 'Neha Agarwal',  'Jaipur',     '2022-10-25'),
(109, 'Vikram Joshi',  'Pune',       '2022-08-14'),
(110, 'Ishita Kapoor', 'Lucknow',    '2023-06-01');

CREATE TABLE orders (
    order_id     INT,
    customer_id  INT,
    order_date   DATE,
    amount       NUMERIC,
    payment_mode STRING,
    status       STRING
);

INSERT INTO orders VALUES
(5001, 101, '2023-04-01', 1500.00, 'UPI',        'Delivered'),
(5002, 103, '2023-04-03', 2300.00, 'Card',       'Cancelled'),
(5003, 101, '2023-05-21',  890.00, 'Cash',       'Delivered'),
(5004, 104, '2023-07-19', 1200.00, 'UPI',        'Returned'),
(5005, 106, '2023-08-12',  640.00, 'Card',       'Delivered'),
(5006, 105, '2023-06-11', 4500.00, 'Netbanking', 'Delivered'),
(5007, 102, '2023-09-02', 3000.00, 'UPI',        'Delivered'),
(5008, 109, '2023-09-07', 1750.00, 'Cash',       'Shipped'),
(5009, 110, '2023-09-09', 2200.00, 'UPI',        'Delivered'),
(5010, 107, '2023-05-13',  999.00, 'Card',       'Returned'),
(5011, 108, '2023-06-30', 1350.00, 'UPI',        'Delivered'),
(5012, 102, '2023-08-15', 2999.00, 'Netbanking', 'Delivered');
-- COMMAND ----------
-- 1. Total orders & amount per customer (unchanged)
SELECT c.customer_name,
       COUNT(o.order_id)      AS total_orders,
       COALESCE(SUM(o.amount), 0) AS total_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_amount DESC;
-- COMMAND ----------
-- 2. Customers with zero orders (unchanged)
SELECT c.customer_id, c.customer_name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;
-- COMMAND ----------
-- 3. Orders in the last 3 months (rewritten: CROSS JOIN + Spark interval syntax)
WITH bounds AS (
    SELECT MAX(order_date) AS latest_date FROM orders
)
SELECT COUNT(*) AS order_count, SUM(o.amount) AS revenue
FROM orders o
CROSS JOIN bounds b
WHERE o.order_date > b.latest_date - INTERVAL 3 MONTH;
-- COMMAND ----------
-- 4. Rank orders by amount per customer (unchanged)
SELECT c.customer_name, o.order_id, o.order_date, o.amount,
       RANK() OVER (PARTITION BY o.customer_id ORDER BY o.amount DESC) AS amount_rank
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
ORDER BY c.customer_name, amount_rank;
-- COMMAND ----------
-- 5. Orders by status (unchanged)
SELECT status, COUNT(*) AS order_count
FROM orders
GROUP BY status
ORDER BY order_count DESC;
-- COMMAND ----------
-- 6. Most-used payment mode (unchanged)
SELECT payment_mode, COUNT(*) AS uses
FROM orders
GROUP BY payment_mode
ORDER BY uses DESC
LIMIT 1;
-- COMMAND ----------
-- 7. Orders before/after signup anniversary (rewritten: no row-tuple comparison)
SELECT
    c.customer_id, c.customer_name,
    SUM(CASE
            WHEN EXTRACT(MONTH FROM o.order_date) < EXTRACT(MONTH FROM c.signup_date)
              OR (EXTRACT(MONTH FROM o.order_date) = EXTRACT(MONTH FROM c.signup_date)
                  AND EXTRACT(DAY FROM o.order_date) < EXTRACT(DAY FROM c.signup_date))
            THEN 1 ELSE 0
        END) AS orders_before_anniversary,
    SUM(CASE
            WHEN NOT (EXTRACT(MONTH FROM o.order_date) < EXTRACT(MONTH FROM c.signup_date)
              OR (EXTRACT(MONTH FROM o.order_date) = EXTRACT(MONTH FROM c.signup_date)
                  AND EXTRACT(DAY FROM o.order_date) < EXTRACT(DAY FROM c.signup_date)))
            THEN 1 ELSE 0
        END) AS orders_on_or_after_anniversary
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name;
-- COMMAND ----------
-- 8. City-level rollup (unchanged)
SELECT
    c.city,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(o.order_id)             AS total_orders,
    AVG(o.amount)                 AS avg_order_amount
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.city;
-- COMMAND ----------
-- 9. Customers with no cancellations (unchanged)
SELECT c.customer_id, c.customer_name
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING SUM(CASE WHEN o.status = 'Cancelled' THEN 1 ELSE 0 END) = 0;
-- COMMAND ----------
-- 10. HAVING count+avg (unchanged)
SELECT c.customer_id, c.customer_name,
       COUNT(*) AS order_count, AVG(o.amount) AS avg_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(*) > 2 AND AVG(o.amount) > 1000;
-- COMMAND ----------
-- 11. Top 3 customers by spend (unchanged)
SELECT c.customer_name, SUM(o.amount) AS total_spent
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_spent DESC
LIMIT 3;
-- COMMAND ----------
-- 12. Distinct payment modes as CSV (rewritten: no STRING_AGG DISTINCT/ORDER BY)
SELECT c.customer_id, c.customer_name,
       array_join(sort_array(collect_set(o.payment_mode)), ', ') AS payment_modes
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name;
-- COMMAND ----------
-- 13. Status pivot (rewritten: FILTER -> CASE WHEN)
SELECT
    c.customer_id, c.customer_name,
    SUM(CASE WHEN o.status = 'Delivered' THEN 1 ELSE 0 END) AS delivered,
    SUM(CASE WHEN o.status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN o.status = 'Returned'  THEN 1 ELSE 0 END) AS returned,
    SUM(CASE WHEN o.status = 'Shipped'   THEN 1 ELSE 0 END) AS shipped
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 06:**
-- MAGIC - Sub-question 3: Postgres implicit comma-cross-join (`FROM orders o, bounds b`) rewritten to explicit `CROSS JOIN`; `INTERVAL '3 months'` (quoted) rewritten to Spark's `INTERVAL 3 MONTH` (unquoted number + unit).
-- MAGIC - Sub-question 7: Postgres row-value comparison `(a,b) < (c,d)` is not reliably supported in Spark SQL, so it's expanded into an explicit lexicographic boolean expression with the same meaning.
-- MAGIC - Sub-question 12: `STRING_AGG(DISTINCT x, ', ' ORDER BY x)` has no direct Spark equivalent with guaranteed DISTINCT+ORDER BY support; rewritten as `array_join(sort_array(collect_set(x)), ', ')`, which dedupes (collect_set) and sorts ascending (sort_array) identically.
-- MAGIC - Sub-question 13: `COUNT(*) FILTER (WHERE ...)` rewritten to `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` (Spark SQL has no FILTER clause on aggregates).
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 07: SCD Type 2 - Merge Adjacent Duplicate Rows
-- MAGIC **Databricks changes:** none needed (WINDOW clause supported)
-- COMMAND ----------
-- Setup: dataset for Question 07
DROP TABLE IF EXISTS client_scd;

CREATE TABLE client_scd (
    surrogate_key INT,
    client_id     INT,
    client_name   STRING,
    address       STRING,
    start_date    DATE,
    end_date      DATE
);

INSERT INTO client_scd VALUES
(1,  101, 'Alice Smith',   'NY',            '2022-01-01', '2023-01-01'),
(2,  101, 'Alice Smith',   'NY',            '2023-01-01', '2024-01-01'),
(3,  101, 'Alice Smith',   'Boston',        '2024-01-01', '2025-01-01'),
(4,  101, 'Alice Johnson', 'Boston',        '2025-01-01', '9999-12-31'),
(5,  102, 'Bob Martin',    'Chicago',       '2019-05-10', '2020-05-10'),
(6,  102, 'Bob Martin',    'Chicago',       '2020-05-10', '2021-05-10'),
(7,  102, 'Bob Martin',    'NY',            '2021-05-10', '2022-05-10'),
(8,  102, 'Bob Martin',    'Chicago',       '2022-05-10', '2023-05-10'),
(9,  102, 'Bob Martin',    'Chicago',       '2023-05-10', '2024-05-10'),
(10, 102, 'Bob Martin',    'Chicago',       '2024-05-10', '2025-05-10'),
(11, 102, 'Bob Martin',    'San Francisco', '2025-05-10', '9999-12-31'),
(12, 103, 'Clara Brown',   'Seattle',       '2023-03-15', '2024-03-15'),
(13, 103, 'Clara Brown',   'Seattle',       '2024-03-15', '2025-03-15'),
(14, 103, 'Clara Brown',   'Seattle',       '2025-03-18', '2025-08-01'),
(15, 103, 'Clara Brown',   'Seattle',       '2025-08-01', '9999-12-31');
-- COMMAND ----------
-- Primary answer (unchanged)
WITH flagged AS (
    SELECT
        *,
        CASE
            WHEN client_name = LAG(client_name) OVER w
             AND address     = LAG(address)     OVER w
             AND start_date  = LAG(end_date)     OVER w
            THEN 0 ELSE 1
        END AS is_new_group
    FROM client_scd
    WINDOW w AS (PARTITION BY client_id ORDER BY start_date)
),
grouped AS (
    SELECT
        *,
        SUM(is_new_group) OVER (PARTITION BY client_id ORDER BY start_date) AS group_id
    FROM flagged
)
SELECT
    client_id,
    client_name,
    address,
    MIN(start_date) AS start_date,
    MAX(end_date)   AS end_date
FROM grouped
GROUP BY client_id, group_id, client_name, address
ORDER BY client_id, start_date;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 07:**
-- MAGIC - Named `WINDOW w AS (...)` clause is standard SQL and supported by Spark SQL; runs unchanged.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 08: Employee Referral - Running Total & Latest Referral
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 08
DROP TABLE IF EXISTS employee_referral;

CREATE TABLE employee_referral (
    employee_id    INT,
    referral_bonus NUMERIC,
    referral_date  DATE
);

INSERT INTO employee_referral VALUES
(1,  300, '2021-01-31'),
(1,  400, '2021-02-28'),
(1,  200, '2021-03-31'),
(1,  400, '2022-01-01'),
(1,  100, '2022-02-05'),
(2, 1000, '2021-10-31'),
(2,  200, '2021-11-08'),
(2,  900, '2021-12-31');
-- COMMAND ----------
-- 1. Running total (unchanged)
SELECT
    employee_id,
    referral_bonus,
    referral_date,
    SUM(referral_bonus) OVER (
        PARTITION BY employee_id ORDER BY referral_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_referral_bonus
FROM employee_referral
ORDER BY employee_id, referral_date;
-- COMMAND ----------
-- 2. Latest referral + total count (unchanged)
SELECT employee_id, referral_bonus AS latest_referral_bonus, referral_date AS latest_referral_date,
       total_referrals
FROM (
    SELECT
        employee_id,
        referral_bonus,
        referral_date,
        ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY referral_date DESC) AS rn,
        COUNT(*)     OVER (PARTITION BY employee_id) AS total_referrals
    FROM employee_referral
) ranked
WHERE rn = 1;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 08:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 09: Employee Hierarchy - Recursive Reporting Chain
-- MAGIC **Databricks changes:** WITH RECURSIVE (caveat), ::TEXT -> CAST(...AS STRING)
-- COMMAND ----------
-- Setup: dataset for Question 09
DROP TABLE IF EXISTS employee;

CREATE TABLE employee (
    emp_id       INT,
    emp_name     STRING,
    reporting_to INT,
    designation  STRING
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
(51, 'Heena',   44,   'Junior Engineer'),
(52, 'Kiran',   43,   'Junior Engineer');
-- COMMAND ----------
-- Primary answer (rewritten: :: cast -> CAST)
WITH RECURSIVE reports AS (
    SELECT emp_id, emp_name, 0 AS depth, CAST(emp_name AS STRING) AS hierarchy_tree
    FROM employee
    WHERE emp_name = 'Aarti'

    UNION ALL

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
WHERE depth > 0
ORDER BY depth, emp_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 09:**
-- MAGIC - Postgres `::TEXT` cast -> Spark `CAST(... AS STRING)`; `||` string concatenation is supported natively in Spark SQL, unchanged.
-- MAGIC - Same `WITH RECURSIVE` runtime-version caveat as question 03.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 10: Employee Salary by Department
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 10
DROP TABLE IF EXISTS employees;

CREATE TABLE employees (
    emp_id     INT,
    emp_name   STRING,
    department STRING,
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
-- COMMAND ----------
-- 1. Department rollup (unchanged)
SELECT
    department,
    COUNT(*)              AS headcount,
    SUM(salary)            AS total_salary,
    ROUND(AVG(salary), 2)  AS avg_salary,
    MAX(salary)            AS max_salary
FROM employees
GROUP BY department
ORDER BY department;
-- COMMAND ----------
-- 2. Top earner per department (unchanged)
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
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 10:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 11: Salary History - Previous Value & Review Gaps
-- MAGIC **Databricks changes:** date - date -> datediff()
-- COMMAND ----------
-- Setup: dataset for Question 11
DROP TABLE IF EXISTS salary_history;

CREATE TABLE salary_history (
    emp_id         INT,
    effective_date DATE,
    salary         NUMERIC
);

INSERT INTO salary_history VALUES
(1, '2021-01-01', 60000),
(1, '2022-01-01', 66000),
(1, '2023-06-01', 72000),
(1, '2025-01-01', 80000),
(2, '2021-03-01', 55000),
(2, '2022-03-01', 60000),
(2, '2023-03-01', 65000),
(3, '2020-06-01', 70000),
(3, '2024-06-01', 90000);
-- COMMAND ----------
-- Primary answer (rewritten: date-date subtraction -> datediff)
SELECT
    emp_id,
    effective_date,
    salary,
    LAG(salary) OVER w          AS prev_salary,
    salary - LAG(salary) OVER w AS salary_change,
    LAG(effective_date) OVER w  AS prev_effective_date,
    datediff(effective_date, LAG(effective_date) OVER w) AS days_since_last_change,
    CASE
        WHEN LAG(effective_date) OVER w IS NOT NULL
         AND datediff(effective_date, LAG(effective_date) OVER w) > 365
        THEN 'Stale (>1yr gap)'
        ELSE 'Normal'
    END AS review_status
FROM salary_history
WINDOW w AS (PARTITION BY emp_id ORDER BY effective_date)
ORDER BY emp_id, effective_date;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 11:**
-- MAGIC - Postgres `date1 - date2` returns a plain integer day-count; Spark `date1 - date2` returns an INTERVAL type instead, which can't be compared to a bare integer like `365` directly -> rewritten to `datediff(date1, date2)`, which returns the integer day-count directly in both engines.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 12: Event Analysis - Sessionization & Signups
-- MAGIC **Databricks changes:** INTERVAL literal format, BOOL_OR -> MAX(CASE...)=1
-- COMMAND ----------
-- Setup: dataset for Question 12
DROP TABLE IF EXISTS events;

CREATE TABLE events (
    user_id    INT,
    event_time TIMESTAMP,
    event_type STRING
);

INSERT INTO events VALUES
(1, '2025-01-01 09:00:00', 'page_view'),
(1, '2025-01-01 09:05:00', 'page_view'),
(1, '2025-01-01 09:08:00', 'signup'),
(1, '2025-01-01 10:15:00', 'page_view'),
(1, '2025-01-01 10:20:00', 'click'),
(2, '2025-01-01 11:00:00', 'page_view'),
(2, '2025-01-01 11:29:00', 'page_view'),
(2, '2025-01-01 11:31:00', 'signup'),
(2, '2025-01-01 13:00:00', 'page_view');
-- COMMAND ----------
-- Primary answer (rewritten: interval literal + BOOL_OR)
WITH ordered AS (
    SELECT
        user_id,
        event_time,
        event_type,
        LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event_time
    FROM events
),
flagged AS (
    SELECT
        *,
        CASE
            WHEN prev_event_time IS NULL
              OR event_time - prev_event_time > INTERVAL 30 MINUTES
            THEN 1 ELSE 0
        END AS is_new_session
    FROM ordered
),
sessions AS (
    SELECT
        *,
        SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY event_time) AS session_id
    FROM flagged
)
SELECT
    user_id,
    session_id,
    MIN(event_time)                 AS session_start,
    MAX(event_time)                 AS session_end,
    COUNT(*)                        AS event_count,
    MAX(CASE WHEN event_type = 'signup' THEN 1 ELSE 0 END) = 1 AS has_signup
FROM sessions
GROUP BY user_id, session_id
ORDER BY user_id, session_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 12:**
-- MAGIC - Interval literal reformatted from Postgres's `INTERVAL '30 minutes'` to Spark's `INTERVAL 30 MINUTES` (unquoted). `timestamp - timestamp` yields an INTERVAL in both engines here, so the comparison itself needs no other change.
-- MAGIC - `BOOL_OR(cond)` rewritten to `MAX(CASE WHEN cond THEN 1 ELSE 0 END) = 1` for guaranteed portability across Spark/Databricks versions (BOOL_OR may not exist on older runtimes).
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 13: Explode & Aggregate Skills
-- MAGIC **Databricks changes:** UNNEST(STRING_TO_ARRAY()) -> LATERAL VIEW EXPLODE(SPLIT())
-- COMMAND ----------
-- Setup: dataset for Question 13
DROP TABLE IF EXISTS candidates;

CREATE TABLE candidates (
    candidate_id   INT,
    candidate_name STRING,
    skills         STRING   -- comma-separated
);

INSERT INTO candidates VALUES
(1, 'Ishaan Kapoor', 'SQL,Python,Excel'),
(2, 'Neha Trivedi',  'SQL,Tableau'),
(3, 'Aman Gupta',    'Python,Spark,SQL'),
(4, 'Simran Kaur',   'Excel,Tableau,SQL'),
(5, 'Rahul Sinha',   'Python');
-- COMMAND ----------
-- 1. Most in-demand skills (rewritten)
WITH exploded AS (
    SELECT
        candidate_id,
        candidate_name,
        TRIM(skill) AS skill
    FROM candidates
    LATERAL VIEW EXPLODE(SPLIT(skills, ',')) exploded_tbl AS skill
)
SELECT skill, COUNT(*) AS candidate_count
FROM exploded
GROUP BY skill
ORDER BY candidate_count DESC, skill;
-- COMMAND ----------
-- 2. Skills per candidate (same rewritten exploded CTE)
WITH exploded AS (
    SELECT
        candidate_id,
        candidate_name,
        TRIM(skill) AS skill
    FROM candidates
    LATERAL VIEW EXPLODE(SPLIT(skills, ',')) exploded_tbl AS skill
)
SELECT candidate_name, COUNT(*) AS skill_count
FROM exploded
GROUP BY candidate_name
ORDER BY skill_count DESC, candidate_name;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 13:**
-- MAGIC - Postgres `FROM t, UNNEST(STRING_TO_ARRAY(col, ','))` -> Spark `FROM t LATERAL VIEW EXPLODE(SPLIT(col, ','))`. `STRING_TO_ARRAY(s, sep)` -> `SPLIT(s, sep)`; `UNNEST(arr)` in a FROM-clause cross join -> `LATERAL VIEW EXPLODE(arr)`.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 14: Gaps & Islands - Zero Balance Periods
-- MAGIC **Databricks changes:** INTERVAL*int -> date_sub()
-- COMMAND ----------
-- Setup: dataset for Question 14
DROP TABLE IF EXISTS account_balance;

CREATE TABLE account_balance (
    account_id   INT,
    balance_date DATE,
    balance      NUMERIC
);

INSERT INTO account_balance VALUES
(1, '2025-01-01', 500),
(1, '2025-01-02', 0),
(1, '2025-01-03', 0),
(1, '2025-01-04', 0),
(1, '2025-01-05', 200),
(1, '2025-01-06', 0),
(1, '2025-01-07', 0),
(2, '2025-01-01', 0),
(2, '2025-01-02', 0),
(2, '2025-01-03', 100),
(2, '2025-01-04', 0),
(2, '2025-01-05', 0),
(2, '2025-01-06', 0),
(2, '2025-01-07', 0);
-- COMMAND ----------
-- Primary answer (rewritten)
WITH zero_days AS (
    SELECT
        account_id,
        balance_date,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY balance_date) AS rn
    FROM account_balance
    WHERE balance = 0
),
islands AS (
    SELECT
        account_id,
        date_sub(balance_date, CAST(rn AS INT)) AS island_group,
        MIN(balance_date) AS zero_start,
        MAX(balance_date) AS zero_end,
        COUNT(*)          AS zero_days
    FROM zero_days
    GROUP BY account_id, date_sub(balance_date, CAST(rn AS INT))
)
SELECT account_id, zero_start, zero_end, zero_days
FROM islands
WHERE zero_days >= 3
ORDER BY account_id, zero_start;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 14:**
-- MAGIC - Same `date - (n * INTERVAL '1 day')` -> `date_sub(date, n)` rewrite as question 04.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 15: Join Cardinality With NULLs & Duplicates
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 15
DROP TABLE IF EXISTS customers15;
DROP TABLE IF EXISTS orders15;

CREATE TABLE customers15 (
    customer_id   INT,
    customer_name STRING
);
INSERT INTO customers15 VALUES
(101, 'Alpha Corp'),
(102, 'Beta Ltd'),
(102, 'Beta Ltd (dup record)'),
(103, 'Gamma Inc');

CREATE TABLE orders15 (
    order_id    INT,
    customer_id INT
);
INSERT INTO orders15 VALUES
(1, 101),
(2, 102),
(3, NULL),
(4, 105);
-- COMMAND ----------
-- 1. INNER JOIN (unchanged)
SELECT o.order_id, o.customer_id, c.customer_name
FROM orders15 o
JOIN customers15 c ON c.customer_id = o.customer_id
ORDER BY o.order_id;
-- COMMAND ----------
-- 2. LEFT JOIN (unchanged)
SELECT o.order_id, o.customer_id, c.customer_name
FROM orders15 o
LEFT JOIN customers15 c ON c.customer_id = o.customer_id
ORDER BY o.order_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 15:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL. (The prose's `DISTINCT ON (customer_id)` aside is explicitly framed as Postgres-only; the Databricks equivalent is `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY ...) = 1`.)
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 16: Customer Order Running Total & Tier Crossing
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 16
DROP TABLE IF EXISTS orders16;

CREATE TABLE orders16 (
    customer_id INT,
    order_date  DATE,
    amount      NUMERIC
);

INSERT INTO orders16 VALUES
(1, '2025-01-05', 2000),
(1, '2025-02-10', 2500),
(1, '2025-03-11', 1200),
(1, '2025-04-02', 4500),
(2, '2025-01-20', 6000),
(2, '2025-03-15', 3000),
(2, '2025-05-01', 2500);
-- COMMAND ----------
-- 1. Running total & tier (unchanged)
WITH running AS (
    SELECT
        customer_id,
        order_date,
        amount,
        SUM(amount) OVER (
            PARTITION BY customer_id ORDER BY order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_total
    FROM orders16
)
SELECT
    customer_id, order_date, amount, running_total,
    CASE
        WHEN running_total >= 10000 THEN 'Gold'
        WHEN running_total >= 5000  THEN 'Silver'
        ELSE 'Bronze'
    END AS tier_after_order
FROM running
ORDER BY customer_id, order_date;
-- COMMAND ----------
-- 2. Tier-crossing events (unchanged)
WITH running AS (
    SELECT
        customer_id, order_date, amount,
        SUM(amount) OVER (PARTITION BY customer_id ORDER BY order_date
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
    FROM orders16
),
with_prev AS (
    SELECT *,
           LAG(running_total) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_total
    FROM running
)
SELECT customer_id, order_date, running_total, 'Silver' AS tier_crossed
FROM with_prev
WHERE running_total >= 5000 AND COALESCE(prev_total, 0) < 5000
UNION ALL
SELECT customer_id, order_date, running_total, 'Gold'
FROM with_prev
WHERE running_total >= 10000 AND COALESCE(prev_total, 0) < 10000
ORDER BY customer_id, order_date;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 16:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 17: Payroll - Weekly Hours & Overtime Pay
-- MAGIC **Databricks changes:** ::DATE -> CAST(...AS DATE)
-- COMMAND ----------
-- Setup: dataset for Question 17
DROP TABLE IF EXISTS timesheets;

CREATE TABLE timesheets (
    employee_id  INT,
    work_date    DATE,
    hours_worked NUMERIC,
    hourly_rate  NUMERIC
);

INSERT INTO timesheets VALUES
(1, '2025-06-02', 9, 20), (1, '2025-06-03', 9, 20), (1, '2025-06-04', 9, 20),
(1, '2025-06-05', 9, 20), (1, '2025-06-06', 9, 20),
(1, '2025-06-09', 8, 20), (1, '2025-06-10', 8, 20), (1, '2025-06-11', 8, 20),
(1, '2025-06-12', 8, 20), (1, '2025-06-13', 8, 20),
(2, '2025-06-02', 6, 25), (2, '2025-06-03', 6, 25), (2, '2025-06-04', 6, 25),
(2, '2025-06-05', 6, 25), (2, '2025-06-06', 6, 25);
-- COMMAND ----------
-- Primary answer (rewritten: :: cast -> CAST)
WITH weekly AS (
    SELECT
        employee_id,
        CAST(DATE_TRUNC('week', work_date) AS DATE) AS week_start,
        SUM(hours_worked)                    AS total_hours,
        MAX(hourly_rate)                     AS hourly_rate
    FROM timesheets
    GROUP BY employee_id, DATE_TRUNC('week', work_date)
)
SELECT
    employee_id,
    week_start,
    total_hours,
    LEAST(total_hours, 40)        AS regular_hours,
    GREATEST(total_hours - 40, 0) AS overtime_hours,
    LEAST(total_hours, 40) * hourly_rate
      + GREATEST(total_hours - 40, 0) * hourly_rate * 1.5 AS weekly_pay
FROM weekly
ORDER BY employee_id, week_start;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 17:**
-- MAGIC - Postgres `::DATE` cast -> Spark `CAST(... AS DATE)`. `DATE_TRUNC('week', ...)`, `LEAST`, and `GREATEST` all exist natively in Spark SQL with the same signature; both engines default to a Monday-start week.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 18: Team Capacity - Subset Sum
-- MAGIC **Databricks changes:** WITH RECURSIVE (caveat), ARRAY[...]::TEXT[] -> array(), || -> concat()
-- COMMAND ----------
-- Setup: dataset for Question 18
DROP TABLE IF EXISTS team_members;

CREATE TABLE team_members (
    employee_id           INT,
    name                  STRING,
    weekly_capacity_hours INT
);

INSERT INTO team_members VALUES
(1, 'Aarav',  10),
(2, 'Bhavna', 15),
(3, 'Chetan', 20),
(4, 'Divya',   5),
(5, 'Esha',   25),
(6, 'Farhan', 30);
-- COMMAND ----------
-- Primary answer (rewritten)
WITH RECURSIVE combos AS (
    -- anchor: every single employee is a size-1 combination
    SELECT
        employee_id,
        weekly_capacity_hours AS total_hours,
        array(name) AS team
    FROM team_members

    UNION ALL

    -- recursive step: extend a combination with an employee later in employee_id order
    SELECT
        e.employee_id,
        c.total_hours + e.weekly_capacity_hours,
        concat(c.team, array(e.name)) AS team
    FROM combos c
    JOIN team_members e ON e.employee_id > c.employee_id
    WHERE c.total_hours + e.weekly_capacity_hours <= 40
)
SELECT team, total_hours
FROM combos
WHERE total_hours = 40
ORDER BY team;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 18:**
-- MAGIC - Postgres `ARRAY[name]::TEXT[]` -> Spark `array(name)` (Spark infers `ARRAY<STRING>` automatically). `arr || elem` -> `concat(arr, array(elem))`.
-- MAGIC - Same `WITH RECURSIVE` runtime-version caveat as question 03.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 19: Round Robin - Unique Pairs
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 19
DROP TABLE IF EXISTS players;

CREATE TABLE players (
    player_id   INT,
    player_name STRING
);

INSERT INTO players VALUES
(1, 'Arjun'), (2, 'Bina'), (3, 'Chirag'), (4, 'Deepa');
-- COMMAND ----------
-- Primary answer (unchanged)
SELECT
    p1.player_name AS player_a,
    p2.player_name AS player_b
FROM players p1
JOIN players p2 ON p1.player_id < p2.player_id
ORDER BY p1.player_id, p2.player_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 19:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 20: Fill Forward - Missing Category
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 20
DROP TABLE IF EXISTS product_prices;

CREATE TABLE product_prices (
    product_id INT,
    price_date DATE,
    category   STRING
);

INSERT INTO product_prices VALUES
(1, '2025-01-01', 'Electronics'),
(1, '2025-01-02', NULL),
(1, '2025-01-03', NULL),
(1, '2025-01-04', 'Appliances'),
(1, '2025-01-05', NULL),
(2, '2025-01-01', NULL),
(2, '2025-01-02', 'Furniture'),
(2, '2025-01-03', NULL);
-- COMMAND ----------
-- Primary answer (unchanged)
WITH grp AS (
    SELECT
        product_id,
        price_date,
        category,
        COUNT(category) OVER (
            PARTITION BY product_id ORDER BY price_date
        ) AS fill_group
    FROM product_prices
)
SELECT
    product_id,
    price_date,
    category AS original_category,
    MAX(category) OVER (PARTITION BY product_id, fill_group) AS filled_category
FROM grp
ORDER BY product_id, price_date;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 20:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 21: Recipe Page Imposition
-- MAGIC **Databricks changes:** WITH RECURSIVE (caveat)
-- COMMAND ----------
-- Setup: dataset for Question 21
DROP TABLE IF EXISTS recipes;

CREATE TABLE recipes (
    recipe_id   INT,
    recipe_name STRING,
    has_photo   BOOLEAN
);

INSERT INTO recipes VALUES
(1, 'Pasta',       FALSE),
(2, 'Salad',       FALSE),
(3, 'Bread',       FALSE),
(4, 'Photo Cake',  TRUE),
(5, 'Photo Soup',  TRUE),
(6, 'Rice',        FALSE),
(7, 'Photo Steak', TRUE),
(8, 'Photo Pie',   TRUE);
-- COMMAND ----------
-- Primary answer (unchanged besides types)
WITH RECURSIVE sized AS (
    SELECT recipe_id, recipe_name,
           CASE WHEN has_photo THEN 2 ELSE 1 END AS slots_needed
    FROM recipes
),
imposition AS (
    -- anchor: the very first recipe always starts page 1
    SELECT s.recipe_id, s.recipe_name, s.slots_needed,
           1 AS page_number, s.slots_needed AS slots_used_on_page
    FROM sized s
    WHERE s.recipe_id = (SELECT MIN(recipe_id) FROM sized)

    UNION ALL

    -- recursive step: does the next recipe fit in what's left on the current page?
    SELECT s.recipe_id, s.recipe_name, s.slots_needed,
           CASE WHEN i.slots_used_on_page + s.slots_needed <= 6
                THEN i.page_number ELSE i.page_number + 1 END,
           CASE WHEN i.slots_used_on_page + s.slots_needed <= 6
                THEN i.slots_used_on_page + s.slots_needed ELSE s.slots_needed END
    FROM imposition i
    JOIN sized s ON s.recipe_id = (SELECT MIN(recipe_id) FROM sized WHERE recipe_id > i.recipe_id)
)
SELECT recipe_id, recipe_name, slots_needed, page_number
FROM imposition
ORDER BY recipe_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 21:**
-- MAGIC - No array/JSON/cast syntax issues here -- the query already used only standard constructs. The correlated subqueries inside the recursive term each reference the recursive CTE alias (`i.recipe_id`) exactly once and only to correlate against the non-recursive `sized` CTE, which satisfies both Postgres's and Databricks's rule that the recursive self-reference must appear exactly once, directly in the FROM clause of the recursive term.
-- MAGIC - Same `WITH RECURSIVE` runtime-version caveat as question 03.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 22: Top Salesperson Per Region
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 22
DROP TABLE IF EXISTS sales;

CREATE TABLE sales (
    sale_id     INT,
    region      STRING,
    salesperson STRING,
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
-- COMMAND ----------
-- Primary answer (unchanged)
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
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 22:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 23: Server Uptime - Longest Streak
-- MAGIC **Databricks changes:** INTERVAL*int -> make_interval()
-- COMMAND ----------
-- Setup: dataset for Question 23
DROP TABLE IF EXISTS server_status;

CREATE TABLE server_status (
    server_id  INT,
    check_time TIMESTAMP,
    status     STRING
);

INSERT INTO server_status VALUES
(1, '2025-01-01 00:00', 'UP'),   (1, '2025-01-01 01:00', 'UP'),
(1, '2025-01-01 02:00', 'DOWN'), (1, '2025-01-01 03:00', 'UP'),
(1, '2025-01-01 04:00', 'UP'),   (1, '2025-01-01 05:00', 'UP'),
(1, '2025-01-01 06:00', 'UP'),   (1, '2025-01-01 07:00', 'DOWN'),
(2, '2025-01-01 00:00', 'UP'),   (2, '2025-01-01 01:00', 'DOWN'),
(2, '2025-01-01 02:00', 'UP'),   (2, '2025-01-01 03:00', 'DOWN');
-- COMMAND ----------
-- Primary answer (rewritten: hour-interval multiply -> make_interval)
WITH up_checks AS (
    SELECT
        server_id,
        check_time,
        ROW_NUMBER() OVER (PARTITION BY server_id ORDER BY check_time) AS rn
    FROM server_status
    WHERE status = 'UP'
),
islands AS (
    SELECT
        server_id,
        check_time - make_interval(0, 0, 0, 0, CAST(rn AS INT), 0, 0) AS island_group,
        MIN(check_time) AS streak_start,
        MAX(check_time) AS streak_end,
        COUNT(*)        AS streak_hours
    FROM up_checks
    GROUP BY server_id, check_time - make_interval(0, 0, 0, 0, CAST(rn AS INT), 0, 0)
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY server_id ORDER BY streak_hours DESC, streak_start) AS rnk
    FROM islands
)
SELECT server_id, streak_start, streak_end, streak_hours
FROM ranked
WHERE rnk = 1
ORDER BY server_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 23:**
-- MAGIC - Postgres `timestamp - (n * INTERVAL '1 hour')` -> Spark `make_interval(years, months, weeks, days, hours, mins, secs)`, called as `check_time - make_interval(0,0,0,0,n,0,0)` to build an `n`-hour interval from a column value (Spark's `INTERVAL 'n' HOUR` literal syntax only accepts constants, not column references, so `make_interval` is the dynamic equivalent).
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 24: Shopping Budget - Greedy Knapsack
-- MAGIC **Databricks changes:** WITH RECURSIVE (caveat)
-- COMMAND ----------
-- Setup: dataset for Question 24
DROP TABLE IF EXISTS shopping_items;

CREATE TABLE shopping_items (
    item_id   INT,
    item_name STRING,
    price     NUMERIC,
    priority  INT
);

INSERT INTO shopping_items VALUES
(1, 'Backpack',     1800, 1),
(2, 'Headphones',   2500, 2),
(3, 'Water Bottle',  400, 3),
(4, 'Notebook Set',  350, 4),
(5, 'Desk Lamp',    1200, 5),
(6, 'Umbrella',      600, 6);
-- COMMAND ----------
-- 1. WRONG naive attempt (unchanged, deliberately)
SELECT
    item_id, item_name, price, priority,
    SUM(price) OVER (ORDER BY priority
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_spend,
    CASE WHEN SUM(price) OVER (ORDER BY priority
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) <= 5000
         THEN 'Buy' ELSE 'Skip (over budget)' END AS decision
FROM shopping_items
ORDER BY priority;
-- COMMAND ----------
-- 2. Correct greedy recursive CTE (unchanged besides types)
WITH RECURSIVE greedy AS (
    SELECT
        item_id, item_name, price, priority,
        CASE WHEN price <= 5000 THEN price ELSE 0 END AS spent_so_far,
        CASE WHEN price <= 5000 THEN 'Buy' ELSE 'Skip (over budget)' END AS decision
    FROM shopping_items
    WHERE priority = (SELECT MIN(priority) FROM shopping_items)

    UNION ALL

    SELECT
        s.item_id, s.item_name, s.price, s.priority,
        CASE WHEN g.spent_so_far + s.price <= 5000 THEN g.spent_so_far + s.price ELSE g.spent_so_far END,
        CASE WHEN g.spent_so_far + s.price <= 5000 THEN 'Buy' ELSE 'Skip (over budget)' END
    FROM greedy g
    JOIN shopping_items s ON s.priority = (SELECT MIN(priority) FROM shopping_items WHERE priority > g.priority)
)
SELECT item_id, item_name, price, priority, spent_so_far, decision
FROM greedy
ORDER BY priority;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 24:**
-- MAGIC - No array/JSON/cast syntax issues; only type normalization needed.
-- MAGIC - Same `WITH RECURSIVE` runtime-version caveat as question 03.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 25: Employees With Duplicate Salaries
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 25
DROP TABLE IF EXISTS workers;

CREATE TABLE workers (
    worker_id   STRING,
    first_name  STRING,
    last_name   STRING,
    salary      NUMERIC,
    department  STRING
);

INSERT INTO workers VALUES
('001', 'Monika',   'Arora',    100000, 'HR'),
('002', 'Niharika', 'Verma',    300000, 'Admin'),
('003', 'Vishal',   'Singhal',  300000, 'HR'),
('004', 'Amitabh',  'Singh',    500000, 'Admin'),
('005', 'Vivek',    'Bhati',    500000, 'Admin');
-- COMMAND ----------
-- Primary answer (unchanged)
SELECT a.worker_id, a.first_name, a.last_name, a.salary, a.department
FROM workers a
JOIN workers b ON a.salary = b.salary AND a.worker_id <> b.worker_id
ORDER BY a.salary, a.worker_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 25:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 26: Orders Dispatched After Being Ordered
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 26
DROP TABLE IF EXISTS order_status;

CREATE TABLE order_status (
    order_id    INT,
    status_date DATE,
    status      STRING
);

INSERT INTO order_status VALUES
(1, '2025-01-01', 'Ordered'),
(1, '2025-01-02', 'Dispatched'),
(1, '2025-01-03', 'Dispatched'),
(1, '2025-01-04', 'Shipped'),
(1, '2025-01-06', 'Delivered'),
(2, '2025-01-01', 'Ordered'),
(2, '2025-01-02', 'Dispatched'),
(2, '2025-01-03', 'Shipped'),
(3, '2025-01-01', 'Dispatched');
-- COMMAND ----------
-- Primary answer (unchanged)
SELECT *
FROM order_status
WHERE status = 'Dispatched'
  AND order_id IN (SELECT order_id FROM order_status WHERE status = 'Ordered')
ORDER BY order_id, status_date;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 26:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 27: Sensor Reading Deltas
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 27
DROP TABLE IF EXISTS sensor_readings;

CREATE TABLE sensor_readings (
    sensor_id     INT,
    reading_ts    TIMESTAMP,
    reading_value NUMERIC
);

INSERT INTO sensor_readings VALUES
(1111, '2025-01-15 08:00', 10),
(1111, '2025-01-16 08:00', 15),
(1111, '2025-01-17 08:00', 30),
(1112, '2025-01-15 08:00', 10),
(1112, '2025-01-15 09:00', 20),
(1112, '2025-01-15 10:00', 30);
-- COMMAND ----------
-- Primary answer (unchanged)
WITH deltas AS (
    SELECT
        sensor_id, reading_ts, reading_value,
        LEAD(reading_value) OVER w - reading_value AS delta_to_next
    FROM sensor_readings
    WINDOW w AS (PARTITION BY sensor_id ORDER BY reading_ts)
)
SELECT sensor_id, reading_ts, reading_value, delta_to_next
FROM deltas
WHERE delta_to_next IS NOT NULL
ORDER BY sensor_id, reading_ts;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 27:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 28: Customer Addresses as a Set
-- MAGIC **Databricks changes:** ARRAY_AGG(DISTINCT...ORDER BY) -> sort_array(collect_set())
-- COMMAND ----------
-- Setup: dataset for Question 28
DROP TABLE IF EXISTS customer_addresses;

CREATE TABLE customer_addresses (
    cust_id   INT,
    cust_name STRING,
    address   STRING
);

INSERT INTO customer_addresses VALUES
(1, 'Mark Ray',    'AB'),
(2, 'Peter Smith', 'CD'),
(1, 'Mark Ray',    'EF'),
(2, 'Peter Smith', 'GH'),
(2, 'Peter Smith', 'CD'),
(3, 'Kate',        'IJ');
-- COMMAND ----------
-- Primary answer (rewritten)
SELECT
    cust_id,
    cust_name,
    sort_array(collect_set(address)) AS addresses
FROM customer_addresses
GROUP BY cust_id, cust_name
ORDER BY cust_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 28:**
-- MAGIC - `ARRAY_AGG(DISTINCT col ORDER BY col)` -> `sort_array(collect_set(col))`: `collect_set` dedupes (matches DISTINCT), `sort_array` sorts ascending (matches ORDER BY).
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 29: Top-Selling Product per Year
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 29
DROP TABLE IF EXISTS product_sales;

CREATE TABLE product_sales (
    sale_id    INT,
    product_id INT,
    sale_year  INT,
    quantity   INT,
    price      NUMERIC
);

INSERT INTO product_sales VALUES
(1, 100, 2020, 25, 5000),
(2, 100, 2021, 16, 5000),
(3, 100, 2022,  8, 5000),
(4, 200, 2020, 10, 9000),
(5, 200, 2021, 25, 9000),
(6, 200, 2022, 20, 7000),
(7, 300, 2020, 25, 7000),
(8, 300, 2021, 18, 7000),
(9, 300, 2022, 20, 7000);
-- COMMAND ----------
-- Primary answer (unchanged)
WITH ranked AS (
    SELECT *,
           DENSE_RANK() OVER (PARTITION BY sale_year ORDER BY quantity DESC) AS qty_rank
    FROM product_sales
)
SELECT sale_id, product_id, sale_year, quantity, price
FROM ranked
WHERE qty_rank = 1
ORDER BY sale_year, sale_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 29:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 30: Most Frequent Rank-1 Finisher
-- MAGIC **Databricks changes:** INT[] -> ARRAY<INT>, ARRAY[...] -> array(), UNNEST -> explode()
-- COMMAND ----------
-- Setup: dataset for Question 30
DROP TABLE IF EXISTS race_results;

CREATE TABLE race_results (
    driver_name STRING,
    finishes    ARRAY<INT>
);

INSERT INTO race_results VALUES
('a', array(1,1,1,3)),
('b', array(1,2,3,4)),
('c', array(1,1,1,1,4)),
('d', array(3));
-- COMMAND ----------
-- Primary answer (rewritten)
WITH exploded AS (
    SELECT driver_name, explode(finishes) AS finish_position
    FROM race_results
),
wins AS (
    SELECT driver_name, COUNT(*) AS win_count
    FROM exploded
    WHERE finish_position = 1
    GROUP BY driver_name
)
SELECT driver_name, win_count
FROM wins
ORDER BY win_count DESC
LIMIT 1;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 30:**
-- MAGIC - Postgres `INT[]` column type -> Spark `ARRAY<INT>`. Postgres `ARRAY[1,1,1,3]` literal -> Spark `array(1,1,1,3)` function call (used directly inside the INSERT VALUES list, which Spark supports). `UNNEST(col)` used as a SELECT-list generator alongside a regular column -> `explode(col)`, which Spark supports directly in the SELECT list the same way.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 31: Latest Commission via Join-to-Max
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 31
DROP TABLE IF EXISTS commissions;

CREATE TABLE commissions (
    emp_id         INT,
    commission_amt NUMERIC,
    month_end_date DATE
);

INSERT INTO commissions VALUES
(1, 300, '2021-01-31'),
(1, 400, '2021-02-28'),
(1, 200, '2021-03-31'),
(2, 1000, '2021-10-31'),
(2, 900, '2021-12-31');
-- COMMAND ----------
-- Primary answer (unchanged)
WITH latest_month AS (
    SELECT emp_id, MAX(month_end_date) AS max_date
    FROM commissions
    GROUP BY emp_id
)
SELECT c.emp_id, c.commission_amt, c.month_end_date
FROM commissions c
JOIN latest_month lm
  ON c.emp_id = lm.emp_id AND c.month_end_date = lm.max_date
ORDER BY c.emp_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 31:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 32: Mask PII - Email & Mobile
-- MAGIC **Databricks changes:** SUBSTRING FROM/FOR syntax -> comma-arg form
-- COMMAND ----------
-- Setup: dataset for Question 32
DROP TABLE IF EXISTS customer_contacts;

CREATE TABLE customer_contacts (
    email  STRING,
    mobile STRING
);

INSERT INTO customer_contacts VALUES
('renuka1992@gmail.com', '9856765434'),
('anbu.arasu@gmail.com', '9844567788');
-- COMMAND ----------
-- Primary answer (rewritten: SUBSTRING FROM/FOR -> comma-arg form)
SELECT
    email,
    SUBSTRING(email, 1, 1) || REPEAT('*', 10) || SUBSTRING(email, 9) AS masked_email,
    mobile,
    SUBSTRING(mobile, 1, 2) || REPEAT('*', 5) || SUBSTRING(mobile, LENGTH(mobile) - 2) AS masked_mobile
FROM customer_contacts;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 32:**
-- MAGIC - Postgres's SQL-standard `SUBSTRING(str FROM start FOR length)` phrase syntax is rewritten to the guaranteed-portable comma-argument form `SUBSTRING(str, start, length)` (and the 2-arg `SUBSTRING(str, start)` form for 'to the end of the string'). `REPEAT` and `||` concatenation are unchanged, both supported natively in Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 33: Deduplicate - Keep the Earliest Record
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 33
DROP TABLE IF EXISTS employee_records;

CREATE TABLE employee_records (
    id     INT,
    name   STRING,
    dept   STRING,
    salary NUMERIC
);

INSERT INTO employee_records VALUES
(1, 'John', 'Testing',     5000),
(2, 'Tim',  'Development', 6000),
(3, 'John', 'Development', 5500),
(4, 'Sky',  'Production',  8000);
-- COMMAND ----------
-- Primary answer (unchanged)
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY name ORDER BY id) AS rn
    FROM employee_records
)
SELECT id, name, dept, salary
FROM ranked
WHERE rn = 1
ORDER BY id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 33:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 34: Reverse Each Word in a Sentence
-- MAGIC **Databricks changes:** UNNEST(STRING_TO_ARRAY()) WITH ORDINALITY -> LATERAL VIEW POSEXPLODE(SPLIT()), STRING_AGG(...ORDER BY) -> struct+array_sort+transform
-- COMMAND ----------
-- Setup: dataset for Question 34
DROP TABLE IF EXISTS sentences;

CREATE TABLE sentences (
    sentence_id INT,
    sentence    STRING
);

INSERT INTO sentences VALUES
(1, 'The Social Dilemma'),
(2, 'Data Engineering Handbook');
-- COMMAND ----------
-- Primary answer (rewritten)
WITH tokens AS (
    SELECT
        sentence_id,
        pos AS ordinality,
        REVERSE(word) AS reversed_word
    FROM sentences
    LATERAL VIEW POSEXPLODE(SPLIT(sentence, ' ')) exploded_tbl AS pos, word
)
SELECT
    sentence_id,
    array_join(
        transform(
            array_sort(collect_list(struct(ordinality, reversed_word))),
            x -> x.reversed_word
        ),
        ' '
    ) AS reversed_sentence
FROM tokens
GROUP BY sentence_id
ORDER BY sentence_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 34:**
-- MAGIC - Postgres `UNNEST(STRING_TO_ARRAY(s, ' ')) WITH ORDINALITY AS t(word, ordinality)` -> Spark `LATERAL VIEW POSEXPLODE(SPLIT(s, ' ')) AS pos, word` (POSEXPLODE returns a 0-based position instead of Postgres's 1-based ordinality, but since the position is only used for relative ordering here, not as an output value, that offset doesn't change the result).
-- MAGIC - `STRING_AGG(word, ' ' ORDER BY ordinality)` has no direct Spark equivalent that guarantees order preservation across a shuffle, so it's rewritten as: collect each row into a `struct(ordinality, word)` (order-preservation-safe because sorting happens explicitly afterward, not implicitly during collection), `array_sort` the resulting array of structs (sorts by the struct's first field, `ordinality`), then `transform` (a higher-order array function) to pull out just the `reversed_word` field, and `array_join` to concatenate with spaces.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 35: Flatten Nested JSON
-- MAGIC **Databricks changes:** JSONB -> STRING + from_json/get schema, -> / ->> operators -> dot notation on parsed struct, JSONB_ARRAY_ELEMENTS -> LATERAL VIEW EXPLODE on parsed array, ::INT -> schema-typed at parse time
-- COMMAND ----------
-- Setup: dataset for Question 35
DROP TABLE IF EXISTS posts;

CREATE TABLE posts (
    post_id   INT,
    post_data STRING   -- JSON text; Databricks/Spark has no native JSONB type
);

INSERT INTO posts VALUES
(1, '{"userId":"u1","likeDislike":{"likes":120,"dislikes":5,"userAction":"like"},"multiMedia":[{"id":"m1","mediatype":"image","url":"img1.jpg","likeCount":10},{"id":"m2","mediatype":"video","url":"vid1.mp4","likeCount":20}]}'),
(2, '{"userId":"u2","likeDislike":{"likes":40,"dislikes":2,"userAction":"none"},"multiMedia":[{"id":"m3","mediatype":"image","url":"img2.jpg","likeCount":5}]}');
-- COMMAND ----------
-- Primary answer (full rewrite: from_json + LATERAL VIEW EXPLODE)
WITH parsed AS (
    SELECT
        post_id,
        from_json(
            post_data,
            'STRUCT<userId:STRING, likeDislike:STRUCT<likes:INT,dislikes:INT,userAction:STRING>, multiMedia:ARRAY<STRUCT<id:STRING,mediatype:STRING,url:STRING,likeCount:INT>>>'
        ) AS j
    FROM posts
)
SELECT
    p.post_id,
    p.j.userId                 AS user_id,
    p.j.likeDislike.likes      AS likes,
    p.j.likeDislike.dislikes   AS dislikes,
    p.j.likeDislike.userAction AS user_action,
    media.id                   AS media_id,
    media.mediatype             AS mediatype,
    media.url                   AS url,
    media.likeCount              AS media_like_count
FROM parsed p
LATERAL VIEW EXPLODE(p.j.multiMedia) exploded_tbl AS media
ORDER BY p.post_id, media_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 35:**
-- MAGIC - Databricks/Spark has no `JSONB` type -- the column is stored as plain `STRING` JSON text instead.
-- MAGIC - Rather than porting Postgres's `->`/`->>` path-navigation operators (which don't exist in Spark SQL) one expression at a time, the whole JSON document is parsed ONCE with `from_json(col, schema)` into a properly typed STRUCT (including the nested array), and every field after that is accessed with ordinary dot notation (`j.likeDislike.likes`) -- no repeated per-field JSON parsing, and the INT fields (`likes`, `dislikes`, `likeCount`) come out already typed as INT per the schema, so no `::INT` casts are needed at all.
-- MAGIC - `JSONB_ARRAY_ELEMENTS(post_data -> 'multiMedia')` (a lateral expansion of a JSON array in the FROM clause) -> `LATERAL VIEW EXPLODE(j.multiMedia)`, exploding the already-typed `ARRAY<STRUCT<...>>` field from the parsed struct.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 36: Round-Trip Distance Matching
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 36
DROP TABLE IF EXISTS flight_legs;

CREATE TABLE flight_legs (
    origin      STRING,
    destination STRING,
    distance    INT
);

INSERT INTO flight_legs VALUES
('SEA', 'SF',  300),
('CHI', 'SEA', 2000),
('SF',  'SEA', 300),
('SEA', 'CHI', 2000),
('SEA', 'LND', 500),
('LND', 'SEA', 500),
('LND', 'CHI', 1000),
('CHI', 'NDL', 180);
-- COMMAND ----------
-- Primary answer (unchanged)
SELECT r1.origin, r1.destination, r1.distance + r2.distance AS roundtrip_distance
FROM flight_legs r1
JOIN flight_legs r2
  ON r1.origin = r2.destination AND r1.destination = r2.origin
WHERE r1.origin < r1.destination
ORDER BY r1.origin, r1.destination;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 36:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 37: Customers Who Bought Specific Products
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 37
DROP TABLE IF EXISTS purchases;
DROP TABLE IF EXISTS target_products;

CREATE TABLE purchases (
    customer_id INT,
    product_key INT
);
INSERT INTO purchases VALUES
(1, 5), (2, 6), (3, 5), (3, 6), (1, 6), (4, 7);

CREATE TABLE target_products (
    product_key INT
);
INSERT INTO target_products VALUES (5), (6);
-- COMMAND ----------
-- Primary answer (unchanged)
SELECT DISTINCT customer_id
FROM purchases
WHERE product_key IN (SELECT product_key FROM target_products)
  AND customer_id <> 2
ORDER BY customer_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 37:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 38: Customer Journey Path
-- MAGIC **Databricks changes:** ARRAY_AGG(...ORDER BY) -> struct+array_sort+transform
-- COMMAND ----------
-- Setup: dataset for Question 38
DROP TABLE IF EXISTS page_visits;

CREATE TABLE page_visits (
    user_id     INT,
    visit_seq   INT,
    page        STRING
);

INSERT INTO page_visits VALUES
(1, 1, 'home'), (1, 2, 'products'), (1, 3, 'checkout'), (1, 4, 'confirmation'),
(2, 1, 'home'), (2, 2, 'products'), (2, 3, 'cart'), (2, 4, 'checkout'),
(2, 5, 'confirmation'), (2, 6, 'home'), (2, 7, 'products');
-- COMMAND ----------
-- Primary answer (rewritten)
SELECT
    user_id,
    transform(
        array_sort(collect_list(struct(visit_seq, page))),
        x -> x.page
    ) AS journey
FROM page_visits
GROUP BY user_id
ORDER BY user_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 38:**
-- MAGIC - `ARRAY_AGG(page ORDER BY visit_seq)` needs order-preservation (page names repeat within a journey, e.g. user 2 revisits 'home' and 'products', so a DISTINCT-based rewrite like question 28's would be wrong here) -> same struct+array_sort+transform pattern as question 34: collect `struct(visit_seq, page)`, sort the array of structs (sorts by `visit_seq` first), then pull out just `page`.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 39: Source vs Target Reconciliation
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 39
DROP TABLE IF EXISTS source_tab;
DROP TABLE IF EXISTS target_tab;

CREATE TABLE source_tab (id INT, name STRING);
INSERT INTO source_tab VALUES (1, 'A'), (2, 'B'), (3, 'C'), (4, 'D');

CREATE TABLE target_tab (id INT, name STRING);
INSERT INTO target_tab VALUES (1, 'A'), (2, 'B'), (4, 'X'), (5, 'F');
-- COMMAND ----------
-- Primary answer (unchanged)
SELECT
    COALESCE(s.id, t.id) AS id,
    CASE
        WHEN t.name IS NULL THEN 'new in source'
        WHEN s.name IS NULL THEN 'new in target'
        WHEN s.name <> t.name THEN 'mismatch'
    END AS comment
FROM source_tab s
FULL OUTER JOIN target_tab t ON s.id = t.id
WHERE s.name IS DISTINCT FROM t.name
ORDER BY id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 39:**
-- MAGIC - `IS DISTINCT FROM` / `IS NOT DISTINCT FROM` and `FULL OUTER JOIN` are both supported natively by Spark SQL with identical NULL-safe semantics to Postgres; no rewrite needed.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 40: Grandparent Lookup via Self-Join
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 40
DROP TABLE IF EXISTS family_tree;

CREATE TABLE family_tree (
    child  STRING,
    parent STRING
);

INSERT INTO family_tree VALUES
('A', 'AA'), ('B', 'BB'), ('C', 'CC'),
('AA', 'AAA'), ('BB', 'BBB'), ('CC', 'CCC');
-- COMMAND ----------
-- Primary answer (unchanged)
SELECT
    f1.child,
    f1.parent,
    f2.parent AS grandparent
FROM family_tree f1
JOIN family_tree f2 ON f1.parent = f2.child
ORDER BY f1.child;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 40:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 41: Second-Highest Salary per Department
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 41
DROP TABLE IF EXISTS emp_dept;
DROP TABLE IF EXISTS dept_lookup;

CREATE TABLE emp_dept (
    emp_id  INT,
    name    STRING,
    dept_id STRING,
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
    dept_id   STRING,
    dept_name STRING
);
INSERT INTO dept_lookup VALUES ('A', 'AZURE'), ('G', 'GCP'), ('W', 'AWS');
-- COMMAND ----------
-- Primary answer (unchanged)
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
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 41:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 42: Rating Stars Bar
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 42
DROP TABLE IF EXISTS food_items;
DROP TABLE IF EXISTS food_ratings;

CREATE TABLE food_items (food_id INT, food_item STRING);
INSERT INTO food_items VALUES
(1, 'Veg Biryani'), (2, 'Veg Fried Rice'), (3, 'Kaju Fried Rice'),
(4, 'Chicken Biryani'), (5, 'Chicken Dum Biryani'), (6, 'Prawns Biryani'), (7, 'Fish Biryani');

CREATE TABLE food_ratings (food_id INT, rating INT);
INSERT INTO food_ratings VALUES
(1,5), (2,3), (3,4), (4,4), (5,5), (6,4), (7,4);
-- COMMAND ----------
-- Primary answer (unchanged)
SELECT
    f.food_id,
    f.food_item,
    r.rating,
    REPEAT('*', r.rating) AS stars_out_of_5
FROM food_items f
JOIN food_ratings r ON f.food_id = r.food_id
ORDER BY f.food_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 42:**
-- MAGIC - No Postgres-specific syntax used; runs unchanged on Spark SQL.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 43: Family-Size Country Matching
-- MAGIC **Databricks changes:** none needed
-- COMMAND ----------
-- Setup: dataset for Question 43
DROP TABLE IF EXISTS families;
DROP TABLE IF EXISTS countries;

CREATE TABLE families (
    family_id   STRING,
    family_name STRING,
    family_size INT
);
INSERT INTO families VALUES
('F1', 'Alex Thomas',    9),
('F2', 'Chris Gray',     2),
('F3', 'Emily Johnson',  4),
('F4', 'Michael Brown',  6),
('F5', 'Jessica Wilson', 3);

CREATE TABLE countries (
    country_id   STRING,
    country_name STRING,
    min_size     INT,
    max_size     INT
);
INSERT INTO countries VALUES
('C1', 'Bolivia',      2, 4),
('C2', 'Cook Islands', 4, 8),
('C3', 'Brazil',       4, 7),
('C4', 'Australia',    5, 9),
('C5', 'Canada',       3, 5),
('C6', 'Japan',       10, 12);
-- COMMAND ----------
-- 1. Every qualifying match (unchanged)
SELECT f.family_name, f.family_size, c.country_name
FROM families f
JOIN countries c
  ON f.family_size BETWEEN c.min_size AND c.max_size
ORDER BY f.family_name, c.country_name;
-- COMMAND ----------
-- 2. Family qualifying for the most countries (unchanged)
WITH matches AS (
    SELECT f.family_name, f.family_size, c.country_name
    FROM families f
    JOIN countries c
      ON f.family_size BETWEEN c.min_size AND c.max_size
),
counts AS (
    SELECT family_name, COUNT(*) AS num_countries
    FROM matches
    GROUP BY family_name
)
SELECT family_name, num_countries
FROM counts
ORDER BY num_countries DESC, family_name
LIMIT 1;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 43:**
-- MAGIC - `BETWEEN` non-equi joins are supported identically in Spark SQL; no rewrite needed (though, as already noted in the README, non-equi joins can force a more expensive join strategy at scale in any engine, Databricks included).
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ## Question 44: Null Profiling & Mean Imputation
-- MAGIC **Databricks changes:** ::INT -> CAST(...AS INT), comma join -> CROSS JOIN
-- COMMAND ----------
-- Setup: dataset for Question 44
DROP TABLE IF EXISTS students;

CREATE TABLE students (
    id   INT,
    name STRING,
    age  INT
);
INSERT INTO students VALUES
(1, 'John',   17),
(2, 'Maria',  20),
(3, 'Raj',    NULL),
(4, 'Rachel', 18),
(5, 'Amit',   NULL);
-- COMMAND ----------
-- 1. Null count per column (rewritten: :: cast -> CAST)
SELECT
    SUM(CAST(id IS NULL AS INT))   AS id_nulls,
    SUM(CAST(name IS NULL AS INT)) AS name_nulls,
    SUM(CAST(age IS NULL AS INT))  AS age_nulls
FROM students;
-- COMMAND ----------
-- 2. Impute missing ages with the mean, then filter to 18+ (rewritten: comma join -> CROSS JOIN)
WITH mean_age AS (
    SELECT ROUND(AVG(age)) AS avg_age FROM students WHERE age IS NOT NULL
)
SELECT
    s.id, s.name,
    COALESCE(s.age, m.avg_age) AS age
FROM students s
CROSS JOIN mean_age m
WHERE COALESCE(s.age, m.avg_age) >= 18
ORDER BY s.id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC **Notes for Question 44:**
-- MAGIC - Postgres `(expr)::INT` cast -> Spark `CAST(expr AS INT)`.
-- MAGIC - Postgres implicit comma-cross-join (`FROM students s, mean_age m`) -> explicit `CROSS JOIN` (same join, clearer and unambiguous under Spark's join resolution).
-- COMMAND ----------
