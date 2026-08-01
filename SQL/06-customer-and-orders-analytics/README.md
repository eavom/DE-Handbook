# Customer & Orders Analytics (Multi-Part)

## Problem Statement

A common interview format: one `customers` + `orders` schema, and a rapid-fire list of
independent analytics questions against it. This set covers order aggregation,
outer-join "who's missing" questions, window-function ranking, pivoting, and
date-relative filtering — the questions most DE/analytics interviews reuse this
schema for.

## Problem Dataset

```sql
CREATE TABLE customers (
    customer_id   INT,
    customer_name VARCHAR(50),
    city          VARCHAR(50),
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
    payment_mode VARCHAR(20),
    status       VARCHAR(20)
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
```

`orders.customer_id` 101, 105, 107, 108, 110 map back correctly; 103, 104, 106, 109
also map back correctly — every order's `customer_id` exists in `customers`, so no
orphan rows to worry about here.

## Problem Explanation

Nine distinct questions, each testing a different SQL building block:

1. Total orders & amount spent per customer, richest first
2. Customers who have **never** ordered
3. Orders & revenue in the trailing 3 months (relative to the latest order date in the data)
4. Rank each customer's own orders by amount
5. Order count by status
6. Most popular payment mode
7. Orders per customer split before/after their signup-anniversary date this year
8. Per-city rollup: customers, orders, avg order amount
9. Customers with orders but **zero** cancellations
10. Customers with more than 2 orders **and** avg order amount > 1000
11. Top 3 customers by total spend
12. Distinct payment modes used per customer, as a single comma-separated value
13. Order-count pivot per customer by status (Delivered/Cancelled/Returned/Shipped as columns)

## Problem Answer & Explanation

**1. Total orders & amount spent per customer, ordered by amount desc**

```sql
SELECT c.customer_name,
       COUNT(o.order_id)      AS total_orders,
       COALESCE(SUM(o.amount), 0) AS total_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_amount DESC;
```

**2. Customers who never placed an order**

```sql
SELECT c.customer_id, c.customer_name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;
```
A `LEFT JOIN` + `IS NULL` on the right side's key is the standard "find what's
missing" pattern — it keeps every customer row and only orders that matched, so any
customer with no matching order shows a `NULL` order_id.

**3. Orders & revenue in the last 3 months relative to the latest order date**

```sql
WITH bounds AS (
    SELECT MAX(order_date) AS latest_date FROM orders
)
SELECT COUNT(*) AS order_count, SUM(o.amount) AS revenue
FROM orders o, bounds b
WHERE o.order_date > b.latest_date - INTERVAL '3 months';
```
The window is anchored to the data's own max date, not `CURRENT_DATE` — a common
mistake, since interview datasets are rarely refreshed to "today".

**4. Rank each customer's orders by amount (descending)**

```sql
SELECT c.customer_name, o.order_id, o.order_date, o.amount,
       RANK() OVER (PARTITION BY o.customer_id ORDER BY o.amount DESC) AS amount_rank
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
ORDER BY c.customer_name, amount_rank;
```
`RANK()` (not `ROW_NUMBER()`) so tied amounts share the same rank.

**5. Order count by status**

```sql
SELECT status, COUNT(*) AS order_count
FROM orders
GROUP BY status
ORDER BY order_count DESC;
```

**6. Most popular payment mode**

```sql
SELECT payment_mode, COUNT(*) AS uses
FROM orders
GROUP BY payment_mode
ORDER BY uses DESC
LIMIT 1;
```

**7. Orders per customer before/after signup anniversary in the order's own year**

```sql
SELECT
    c.customer_id, c.customer_name,
    SUM(CASE WHEN (EXTRACT(MONTH FROM o.order_date), EXTRACT(DAY FROM o.order_date))
              <  (EXTRACT(MONTH FROM c.signup_date), EXTRACT(DAY FROM c.signup_date))
        THEN 1 ELSE 0 END) AS orders_before_anniversary,
    SUM(CASE WHEN (EXTRACT(MONTH FROM o.order_date), EXTRACT(DAY FROM o.order_date))
              >= (EXTRACT(MONTH FROM c.signup_date), EXTRACT(DAY FROM c.signup_date))
        THEN 1 ELSE 0 END) AS orders_on_or_after_anniversary
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name;
```
Comparing `(month, day)` tuples (rather than full dates) is what makes this an
"anniversary" comparison instead of a plain date comparison — it ignores the year on
both sides.

**8. Per-city rollup**

```sql
SELECT
    c.city,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(o.order_id)             AS total_orders,
    AVG(o.amount)                 AS avg_order_amount
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.city;
```
`LEFT JOIN` (not `JOIN`) so cities with zero orders still appear with
`total_orders = 0` instead of disappearing from the result.

**9. Customers with orders but zero cancellations**

```sql
SELECT c.customer_id, c.customer_name
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING SUM(CASE WHEN o.status = 'Cancelled' THEN 1 ELSE 0 END) = 0;
```

**10. More than 2 orders and avg order amount > 1000**

```sql
SELECT c.customer_id, c.customer_name,
       COUNT(*) AS order_count, AVG(o.amount) AS avg_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(*) > 2 AND AVG(o.amount) > 1000;
```

**11. Top 3 customers by total spend**

```sql
SELECT c.customer_name, SUM(o.amount) AS total_spent
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_spent DESC
LIMIT 3;
```

**12. Distinct payment modes used per customer as a CSV string**

```sql
SELECT c.customer_id, c.customer_name,
       STRING_AGG(DISTINCT o.payment_mode, ', ' ORDER BY o.payment_mode) AS payment_modes
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name;
```
(`STRING_AGG` is Postgres/SQL Server syntax; use `LISTAGG` on Snowflake/Oracle or
`GROUP_CONCAT` on MySQL.)

**13. Pivot: order count per customer by status**

```sql
SELECT
    c.customer_id, c.customer_name,
    COUNT(*) FILTER (WHERE o.status = 'Delivered') AS delivered,
    COUNT(*) FILTER (WHERE o.status = 'Cancelled') AS cancelled,
    COUNT(*) FILTER (WHERE o.status = 'Returned')  AS returned,
    COUNT(*) FILTER (WHERE o.status = 'Shipped')   AS shipped
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name;
```
`FILTER (WHERE ...)` (or `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` on engines without
`FILTER`) is the standard way to pivot a status column into fixed output columns
without a dynamic `PIVOT` clause.

**Interview follow-up:** this schema is deliberately reused across the whole
interview — once you can write #1, #2, and #4 fluently, the rest are recombinations
of the same three primitives (`GROUP BY`, outer join, window function).
