# Databricks SQL Compatibility Report
I don't have live Databricks (or any Spark) access in the sandbox this session runs in — installing PySpark/DuckDB/the Databricks SQL connector via pip all failed (the package mirror here doesn't carry them), and direct outbound network access is allow-listed to a handful of hosts that doesn't include Databricks workspace URLs, so I couldn't execute anything live even with credentials. What follows instead is a full manual audit: every query across all 44 questions, checked line-by-line against documented Spark SQL / Databricks SQL syntax and rewritten wherever it relied on Postgres-only behavior. The companion notebook, `databricks_verification_notebook.sql`, contains the result — import it into your workspace to get real, live-verified output.
## How to verify
1. Import `databricks_verification_notebook.sql` into your Databricks workspace (Workspace → Import → File, source format "SQL").
2. Run the first cell (`CREATE SCHEMA IF NOT EXISTS de_handbook_verify; USE de_handbook_verify;`).
3. Run any question's cells top to bottom — each question drops and recreates its own tables first, so cells are safe to re-run and questions don't need to run in order.
4. Compare each result grid to the "Expected output" table in that question's README. They should match exactly except for the two cosmetic caveats below.
## Two known cosmetic differences (not correctness bugs)
- **Decimal display.** All `NUMERIC` columns are left as bare `NUMERIC` (Databricks treats this as a synonym for `DECIMAL(10,0)`). Every value currently inserted across all 44 datasets is a whole number, so this displays identically to Postgres's arbitrary-precision `NUMERIC` (e.g. `2000000`, no trailing zeros) — I deliberately did *not* upgrade these to `DECIMAL(12,2)`, because that would add trailing `.00` to every value and break the exact match against the already-verified "Expected output" tables. The tradeoff: if this schema is ever extended with fractional values, `DECIMAL(10,0)` would silently round them to whole numbers on insert. If you plan to add non-integer data to any of these tables, widen the column to `DECIMAL(12,2)` first.
- **Word-position internals in Q34.** Postgres's `WITH ORDINALITY` is 1-based; Spark's `POSEXPLODE` is 0-based. The rewritten query only uses the position for internal sort order (not as an output column), so this has no effect on the final `reversed_sentence` output.
## Recursive CTEs (questions 03, 09, 18, 21, 24)
`WITH RECURSIVE` is a relatively recent Databricks-specific SQL extension — it is **not** part of open-source Apache Spark as of Spark 3.5, and I can't independently confirm from here exactly which Databricks Runtime / SQL warehouse version first shipped it. If these five cells throw a parser error on `RECURSIVE` while everything else in the notebook runs fine, that's the reason: your workspace predates the feature, and the traversal (flight path-finding, org-chart walking, subset-sum, page imposition, greedy knapsack) would need to be reimplemented procedurally in PySpark rather than pure SQL. I reviewed each of the five recursive queries against the structural restrictions both Postgres and Databricks impose on the recursive term (exactly one self-reference, directly in the FROM clause, no aggregates/window functions/ORDER BY/LIMIT inside the recursive branch) and all five satisfy them, so if your runtime supports `WITH RECURSIVE` at all, these should run as-is (with the array-syntax fixes noted below for 03 and 18).
## Per-question changes
| # | Question | Databricks-specific changes |
|---|---|---|
| 01 | Banking Customer Category | FILTER(WHERE) -> CASE WHEN |
| 02 | Running Sum, Next Value, Previous Value | none needed |
| 03 | Connecting Flights - Minimum Hops Path | WITH RECURSIVE (caveat), ARRAY[...] -> array(), || -> concat(), ANY() -> array_contains(), UNNEST -> explode() (restructured) |
| 04 | Consecutive Logins With Dates | INTERVAL*int -> date_sub() |
| 05 | Consecutive Free Desks - Best Fit | ARRAY_AGG(...ORDER BY) -> sort_array(collect_list()), UNNEST -> explode() (restructured) |
| 06 | Customer & Orders Analytics (Multi-Part) | comma join -> CROSS JOIN, INTERVAL 'N months' -> INTERVAL N MONTH, row-tuple compare -> boolean expr, STRING_AGG(DISTINCT...ORDER BY) -> array_join(sort_array(collect_set())), FILTER(WHERE) -> CASE WHEN |
| 07 | SCD Type 2 - Merge Adjacent Duplicate Rows | none needed (WINDOW clause supported) |
| 08 | Employee Referral - Running Total & Latest Referral | none needed |
| 09 | Employee Hierarchy - Recursive Reporting Chain | WITH RECURSIVE (caveat), ::TEXT -> CAST(...AS STRING) |
| 10 | Employee Salary by Department | none needed |
| 11 | Salary History - Previous Value & Review Gaps | date - date -> datediff() |
| 12 | Event Analysis - Sessionization & Signups | INTERVAL literal format, BOOL_OR -> MAX(CASE...)=1 |
| 13 | Explode & Aggregate Skills | UNNEST(STRING_TO_ARRAY()) -> LATERAL VIEW EXPLODE(SPLIT()) |
| 14 | Gaps & Islands - Zero Balance Periods | INTERVAL*int -> date_sub() |
| 15 | Join Cardinality With NULLs & Duplicates | none needed |
| 16 | Customer Order Running Total & Tier Crossing | none needed |
| 17 | Payroll - Weekly Hours & Overtime Pay | ::DATE -> CAST(...AS DATE) |
| 18 | Team Capacity - Subset Sum | WITH RECURSIVE (caveat), ARRAY[...]::TEXT[] -> array(), || -> concat() |
| 19 | Round Robin - Unique Pairs | none needed |
| 20 | Fill Forward - Missing Category | none needed |
| 21 | Recipe Page Imposition | WITH RECURSIVE (caveat) |
| 22 | Top Salesperson Per Region | none needed |
| 23 | Server Uptime - Longest Streak | INTERVAL*int -> make_interval() |
| 24 | Shopping Budget - Greedy Knapsack | WITH RECURSIVE (caveat) |
| 25 | Employees With Duplicate Salaries | none needed |
| 26 | Orders Dispatched After Being Ordered | none needed |
| 27 | Sensor Reading Deltas | none needed |
| 28 | Customer Addresses as a Set | ARRAY_AGG(DISTINCT...ORDER BY) -> sort_array(collect_set()) |
| 29 | Top-Selling Product per Year | none needed |
| 30 | Most Frequent Rank-1 Finisher | INT[] -> ARRAY<INT>, ARRAY[...] -> array(), UNNEST -> explode() |
| 31 | Latest Commission via Join-to-Max | none needed |
| 32 | Mask PII - Email & Mobile | SUBSTRING FROM/FOR syntax -> comma-arg form |
| 33 | Deduplicate - Keep the Earliest Record | none needed |
| 34 | Reverse Each Word in a Sentence | UNNEST(STRING_TO_ARRAY()) WITH ORDINALITY -> LATERAL VIEW POSEXPLODE(SPLIT()), STRING_AGG(...ORDER BY) -> struct+array_sort+transform |
| 35 | Flatten Nested JSON | JSONB -> STRING + from_json/get schema, -> / ->> operators -> dot notation on parsed struct, JSONB_ARRAY_ELEMENTS -> LATERAL VIEW EXPLODE on parsed array, ::INT -> schema-typed at parse time |
| 36 | Round-Trip Distance Matching | none needed |
| 37 | Customers Who Bought Specific Products | none needed |
| 38 | Customer Journey Path | ARRAY_AGG(...ORDER BY) -> struct+array_sort+transform |
| 39 | Source vs Target Reconciliation | none needed |
| 40 | Grandparent Lookup via Self-Join | none needed |
| 41 | Second-Highest Salary per Department | none needed |
| 42 | Rating Stars Bar | none needed |
| 43 | Family-Size Country Matching | none needed |
| 44 | Null Profiling & Mean Imputation | ::INT -> CAST(...AS INT), comma join -> CROSS JOIN |

## Detailed notes

### Question 01 — Banking Customer Category
- Postgres `FILTER (WHERE ...)` has no Spark SQL equivalent -> rewritten to `CASE WHEN ... THEN x END` inside the aggregate (NULL for non-matching rows, which SUM ignores, same as FILTER).

### Question 03 — Connecting Flights - Minimum Hops Path
- Recursive CTEs (`WITH RECURSIVE`) require a Databricks Runtime / SQL warehouse recent enough to support them (this is a fairly recent Databricks-specific extension, not part of open-source Apache Spark as of Spark 3.5). If your workspace errors on `WITH RECURSIVE` with a parser error, the runtime predates this feature and the traversal must be done procedurally in PySpark instead of pure SQL.
- Postgres `ARRAY[x]` literal -> Spark `array(x)` function call.
- Postgres `arr || elem` (array append) -> Spark `concat(arr, array(elem))`.
- Postgres `elem = ANY(arr)` -> Spark `array_contains(arr, elem)`.
- Restructured so `ORDER BY hop_count LIMIT 1` picks the winning row BEFORE `explode()` runs, instead of mixing a set-returning function with ORDER BY/LIMIT in one query (ambiguous/unsupported in Spark).

### Question 04 — Consecutive Logins With Dates
- Postgres `date - (n * INTERVAL '1 day')` -> Spark `date_sub(date, n)`, which takes a plain integer day-count directly and sidesteps any ambiguity around multiplying an INTERVAL by a column value.

### Question 05 — Consecutive Free Desks - Best Fit
- `ARRAY_AGG(col ORDER BY col)` -> `sort_array(collect_list(col))` (ascending sort of the collected array; no duplicates exist in this dataset so `collect_list` vs `collect_set` doesn't matter here).
- Same ORDER BY/LIMIT-before-explode restructuring as question 03.

### Question 06 — Customer & Orders Analytics (Multi-Part)
- Sub-question 3: Postgres implicit comma-cross-join (`FROM orders o, bounds b`) rewritten to explicit `CROSS JOIN`; `INTERVAL '3 months'` (quoted) rewritten to Spark's `INTERVAL 3 MONTH` (unquoted number + unit).
- Sub-question 7: Postgres row-value comparison `(a,b) < (c,d)` is not reliably supported in Spark SQL, so it's expanded into an explicit lexicographic boolean expression with the same meaning.
- Sub-question 12: `STRING_AGG(DISTINCT x, ', ' ORDER BY x)` has no direct Spark equivalent with guaranteed DISTINCT+ORDER BY support; rewritten as `array_join(sort_array(collect_set(x)), ', ')`, which dedupes (collect_set) and sorts ascending (sort_array) identically.
- Sub-question 13: `COUNT(*) FILTER (WHERE ...)` rewritten to `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` (Spark SQL has no FILTER clause on aggregates).

### Question 09 — Employee Hierarchy - Recursive Reporting Chain
- Postgres `::TEXT` cast -> Spark `CAST(... AS STRING)`; `||` string concatenation is supported natively in Spark SQL, unchanged.
- Same `WITH RECURSIVE` runtime-version caveat as question 03.

### Question 11 — Salary History - Previous Value & Review Gaps
- Postgres `date1 - date2` returns a plain integer day-count; Spark `date1 - date2` returns an INTERVAL type instead, which can't be compared to a bare integer like `365` directly -> rewritten to `datediff(date1, date2)`, which returns the integer day-count directly in both engines.

### Question 12 — Event Analysis - Sessionization & Signups
- Interval literal reformatted from Postgres's `INTERVAL '30 minutes'` to Spark's `INTERVAL 30 MINUTES` (unquoted). `timestamp - timestamp` yields an INTERVAL in both engines here, so the comparison itself needs no other change.
- `BOOL_OR(cond)` rewritten to `MAX(CASE WHEN cond THEN 1 ELSE 0 END) = 1` for guaranteed portability across Spark/Databricks versions (BOOL_OR may not exist on older runtimes).

### Question 13 — Explode & Aggregate Skills
- Postgres `FROM t, UNNEST(STRING_TO_ARRAY(col, ','))` -> Spark `FROM t LATERAL VIEW EXPLODE(SPLIT(col, ','))`. `STRING_TO_ARRAY(s, sep)` -> `SPLIT(s, sep)`; `UNNEST(arr)` in a FROM-clause cross join -> `LATERAL VIEW EXPLODE(arr)`.

### Question 14 — Gaps & Islands - Zero Balance Periods
- Same `date - (n * INTERVAL '1 day')` -> `date_sub(date, n)` rewrite as question 04.

### Question 17 — Payroll - Weekly Hours & Overtime Pay
- Postgres `::DATE` cast -> Spark `CAST(... AS DATE)`. `DATE_TRUNC('week', ...)`, `LEAST`, and `GREATEST` all exist natively in Spark SQL with the same signature; both engines default to a Monday-start week.

### Question 18 — Team Capacity - Subset Sum
- Postgres `ARRAY[name]::TEXT[]` -> Spark `array(name)` (Spark infers `ARRAY<STRING>` automatically). `arr || elem` -> `concat(arr, array(elem))`.
- Same `WITH RECURSIVE` runtime-version caveat as question 03.

### Question 21 — Recipe Page Imposition
- No array/JSON/cast syntax issues here -- the query already used only standard constructs. The correlated subqueries inside the recursive term each reference the recursive CTE alias (`i.recipe_id`) exactly once and only to correlate against the non-recursive `sized` CTE, which satisfies both Postgres's and Databricks's rule that the recursive self-reference must appear exactly once, directly in the FROM clause of the recursive term.
- Same `WITH RECURSIVE` runtime-version caveat as question 03.

### Question 23 — Server Uptime - Longest Streak
- Postgres `timestamp - (n * INTERVAL '1 hour')` -> Spark `make_interval(years, months, weeks, days, hours, mins, secs)`, called as `check_time - make_interval(0,0,0,0,n,0,0)` to build an `n`-hour interval from a column value (Spark's `INTERVAL 'n' HOUR` literal syntax only accepts constants, not column references, so `make_interval` is the dynamic equivalent).

### Question 24 — Shopping Budget - Greedy Knapsack
- No array/JSON/cast syntax issues; only type normalization needed.
- Same `WITH RECURSIVE` runtime-version caveat as question 03.

### Question 28 — Customer Addresses as a Set
- `ARRAY_AGG(DISTINCT col ORDER BY col)` -> `sort_array(collect_set(col))`: `collect_set` dedupes (matches DISTINCT), `sort_array` sorts ascending (matches ORDER BY).

### Question 30 — Most Frequent Rank-1 Finisher
- Postgres `INT[]` column type -> Spark `ARRAY<INT>`. Postgres `ARRAY[1,1,1,3]` literal -> Spark `array(1,1,1,3)` function call (used directly inside the INSERT VALUES list, which Spark supports). `UNNEST(col)` used as a SELECT-list generator alongside a regular column -> `explode(col)`, which Spark supports directly in the SELECT list the same way.

### Question 32 — Mask PII - Email & Mobile
- Postgres's SQL-standard `SUBSTRING(str FROM start FOR length)` phrase syntax is rewritten to the guaranteed-portable comma-argument form `SUBSTRING(str, start, length)` (and the 2-arg `SUBSTRING(str, start)` form for 'to the end of the string'). `REPEAT` and `||` concatenation are unchanged, both supported natively in Spark SQL.

### Question 34 — Reverse Each Word in a Sentence
- Postgres `UNNEST(STRING_TO_ARRAY(s, ' ')) WITH ORDINALITY AS t(word, ordinality)` -> Spark `LATERAL VIEW POSEXPLODE(SPLIT(s, ' ')) AS pos, word` (POSEXPLODE returns a 0-based position instead of Postgres's 1-based ordinality, but since the position is only used for relative ordering here, not as an output value, that offset doesn't change the result).
- `STRING_AGG(word, ' ' ORDER BY ordinality)` has no direct Spark equivalent that guarantees order preservation across a shuffle, so it's rewritten as: collect each row into a `struct(ordinality, word)` (order-preservation-safe because sorting happens explicitly afterward, not implicitly during collection), `array_sort` the resulting array of structs (sorts by the struct's first field, `ordinality`), then `transform` (a higher-order array function) to pull out just the `reversed_word` field, and `array_join` to concatenate with spaces.

### Question 35 — Flatten Nested JSON
- Databricks/Spark has no `JSONB` type -- the column is stored as plain `STRING` JSON text instead.
- Rather than porting Postgres's `->`/`->>` path-navigation operators (which don't exist in Spark SQL) one expression at a time, the whole JSON document is parsed ONCE with `from_json(col, schema)` into a properly typed STRUCT (including the nested array), and every field after that is accessed with ordinary dot notation (`j.likeDislike.likes`) -- no repeated per-field JSON parsing, and the INT fields (`likes`, `dislikes`, `likeCount`) come out already typed as INT per the schema, so no `::INT` casts are needed at all.
- `JSONB_ARRAY_ELEMENTS(post_data -> 'multiMedia')` (a lateral expansion of a JSON array in the FROM clause) -> `LATERAL VIEW EXPLODE(j.multiMedia)`, exploding the already-typed `ARRAY<STRUCT<...>>` field from the parsed struct.

### Question 38 — Customer Journey Path
- `ARRAY_AGG(page ORDER BY visit_seq)` needs order-preservation (page names repeat within a journey, e.g. user 2 revisits 'home' and 'products', so a DISTINCT-based rewrite like question 28's would be wrong here) -> same struct+array_sort+transform pattern as question 34: collect `struct(visit_seq, page)`, sort the array of structs (sorts by `visit_seq` first), then pull out just `page`.

### Question 44 — Null Profiling & Mean Imputation
- Postgres `(expr)::INT` cast -> Spark `CAST(expr AS INT)`.
- Postgres implicit comma-cross-join (`FROM students s, mean_age m`) -> explicit `CROSS JOIN` (same join, clearer and unambiguous under Spark's join resolution).

## Summary
- **22 of 44** questions needed no changes at all — they use only standard ANSI SQL (joins, GROUP BY/HAVING, CTEs, RANK/DENSE_RANK/ROW_NUMBER/LAG/LEAD window functions) that Spark SQL implements identically to Postgres.
- **22 of 44** questions needed at least one rewrite, most commonly: Postgres's `::` cast syntax, `UNNEST`/`STRING_TO_ARRAY` array-explosion idioms, `STRING_AGG`/`ARRAY_AGG` with `DISTINCT`/`ORDER BY`, `FILTER (WHERE ...)` on aggregates, and INTERVAL-arithmetic on dates/timestamps — none of which exist in Spark SQL in the same form.
- **1 question (35)** needed a structural rewrite: Postgres's `JSONB` type and `->`/`->>` path operators don't exist in Spark at all, so the JSON is instead parsed once with `from_json()` into a typed struct and navigated with plain dot notation.
- **5 questions (03, 09, 18, 21, 24)** use `WITH RECURSIVE`, which is a newer Databricks-only extension not present in open-source Spark — see the caveat above.
