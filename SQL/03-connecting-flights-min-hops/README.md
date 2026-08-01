# Connecting Flights — Minimum Hops Path

## Problem Statement

Given a table of one-way flights (`source -> destination`), find a route from
**Bangalore** to **Ahmedabad** using the **minimum number of flights** (direct or
connecting). Return the flight numbers in travel order.

## Problem Dataset

```sql
CREATE TABLE flights (
    flight      VARCHAR(10),
    source      VARCHAR(20),
    destination VARCHAR(20)
);

INSERT INTO flights VALUES
('AIR 0087', 'Pune',      'Rajasthan'),
('AIR 0187', 'Delhi',     'Ahmedabad'),
('AIR 0767', 'Rajasthan', 'Delhi'),
('AIR 1678', 'Kolkata',   'Ahmedabad'),
('AIR 0369', 'Bangalore', 'Pune'),
('AIR 0029', 'Rajasthan', 'Ahmedabad'),
('AIR 8878', 'Delhi',     'Hyderabad');
```

Expected output (Bangalore -> Pune -> Rajasthan -> Ahmedabad, 3 hops):

| flight   |
|----------|
| AIR 0369 |
| AIR 0087 |
| AIR 0029 |

## Problem Explanation

There's no direct Bangalore -> Ahmedabad flight and no 2-hop route either, so this
needs actual **graph traversal**, not a fixed number of self-joins. A `recursive CTE`
is the standard SQL tool for path-finding: each recursion step extends a path by one
more flight, tracks the cities already visited (to avoid cycles), and stops the moment
a path reaches the destination. Taking the *shortest* path (not just *a* path) means
ranking all completed paths by hop count and keeping only the best one.

## Problem Answer & Explanation

```sql
WITH RECURSIVE route AS (
    -- anchor: start at Bangalore
    SELECT
        flight,
        source,
        destination,
        1 AS hop_count,
        ARRAY[flight]     AS flight_path,
        ARRAY[source, destination] AS visited_cities
    FROM flights
    WHERE source = 'Bangalore'

    UNION ALL

    -- recursive step: extend the path by one more flight
    SELECT
        f.flight,
        f.source,
        f.destination,
        r.hop_count + 1,
        r.flight_path || f.flight,
        r.visited_cities || f.destination
    FROM route r
    JOIN flights f
      ON f.source = r.destination
    WHERE r.destination <> 'Ahmedabad'          -- stop extending once we've arrived
      AND NOT (f.destination = ANY (r.visited_cities))  -- no revisiting a city
)
SELECT unnest(flight_path) AS flight
FROM route
WHERE destination = 'Ahmedabad'
ORDER BY hop_count
LIMIT 1;
```

**Why it works**

1. The **anchor member** seeds the recursion with every flight departing Bangalore.
2. The **recursive member** joins the paths built so far to flights departing from
   wherever each path currently ends, appending the new flight and city. The
   `visited_cities` array is the cycle guard — without it a graph with a loop would
   recurse forever.
3. `WHERE r.destination <> 'Ahmedabad'` stops a path from growing further once it has
   already arrived, so shorter paths don't keep getting needlessly extended.
4. Because every recursion step is one hop, `ORDER BY hop_count LIMIT 1` on the
   completed paths (`destination = 'Ahmedabad'`) picks the shortest one — this is
   effectively breadth-first search expressed as a recursive CTE.
5. `unnest(flight_path)` expands the winning path's flight array back into rows, in
   travel order.

**Interview follow-up:** if the graph could have thousands of nodes, mention that
recursive CTEs are fine for path-finding at moderate scale but a dedicated graph
engine (or precomputed shortest-path table) is the real answer for production-scale
routing — SQL recursion isn't optimized for large BFS/Dijkstra workloads.
