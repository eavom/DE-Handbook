# Round-Trip Distance Matching

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Self-Join](https://img.shields.io/badge/-Self--Join-16A085?style=flat-square)

> Adapted from `Scenerio21.scala` in `interview-scenerios-spark-sql`.

## Problem Statement

Given a table of one-way flight legs (`origin -> destination`, with a distance), find
every pair of cities that have flights in **both** directions, and report the combined
round-trip distance. Each city pair should appear only once (not once per direction).

## Problem Dataset

```sql
CREATE TABLE flight_legs (
    origin      VARCHAR(5),
    destination VARCHAR(5),
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
```

Expected output:

| origin | destination | roundtrip_distance |
|--------|--------------|------------------------|
| CHI    | SEA          | 4000                   |
| LND    | SEA          | 1000                   |
| SEA    | SF           | 600                     |

`CHI -> NDL` has no return leg (`NDL -> CHI` doesn't exist), so it's correctly
excluded — there's no round trip to report a distance for.

## Problem Explanation

This combines two ideas already seen separately in this repo: a **self-join that
matches a row to its reverse** (same mechanic as
[Consecutive Free Desks](../05-consecutive-free-desks-best-fit/README.md)'s SCD
comparisons, just matching `(origin, destination)` to `(destination, origin)` instead
of comparing a row to its neighbor), plus the same `<` trick from
[Round Robin Unique Pairs](../19-round-robin-unique-pairs/README.md) to keep each
matched pair only once instead of twice (once as `SEA -> SF` and once as `SF -> SEA`).

## Problem Answer & Explanation

```sql
SELECT r1.origin, r1.destination, r1.distance + r2.distance AS roundtrip_distance
FROM flight_legs r1
JOIN flight_legs r2
  ON r1.origin = r2.destination AND r1.destination = r2.origin
WHERE r1.origin < r1.destination
ORDER BY r1.origin, r1.destination;
```

**Why it works**

1. The join condition `r1.origin = r2.destination AND r1.destination = r2.origin`
   finds, for every leg `r1`, the leg `r2` that goes the exact opposite direction — a
   leg only matches if a genuine return flight exists.
2. Legs with no return flight (`CHI -> NDL`) simply produce no match on `r2` and drop
   out of the `JOIN` entirely — this is an inner join, so "no reverse leg" means "not
   in the output," which is the desired behavior (no need for an explicit `NOT NULL`
   filter).
3. `WHERE r1.origin < r1.destination` keeps only one direction of each matched pair —
   without it, `SEA -> SF` and `SF -> SEA` would both appear as separate output rows
   with the identical `roundtrip_distance`, which is redundant since it's the same
   round trip counted twice.
4. `r1.distance + r2.distance` sums the outbound and return leg distances into a
   single round-trip figure.

**Interview follow-up:** ask what happens if a route has **multiple** legs between the
same two cities (e.g. two different flight numbers both flying `SEA -> SF` at
different prices) — the join condition as written would produce a cross-product of
every outbound leg matched with every return leg between the same two cities, which
may or may not be the intended behavior; if only the *cheapest* round trip combination
is wanted, this query would need an additional `MIN()` aggregation layered on top.
