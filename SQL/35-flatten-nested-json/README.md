# Flatten Nested JSON

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Advanced](https://img.shields.io/badge/Difficulty-Advanced-red?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![JSON](https://img.shields.io/badge/-JSON-2471A3?style=flat-square)

> Adapted from `Scenerio19.scala` in `interview-scenerios-spark-sql`, which read a
> nested multi-line JSON file in Spark. This version uses Postgres `JSONB` to model
> the same nested shape and flatten it with plain SQL.

## Problem Statement

Each row of a `posts` table stores a post as a single nested JSON document: a
`likeDislike` object (one per post) and a `multiMedia` array (one or more media items
per post). Flatten this into one row **per media item**, with the post-level
`likeDislike` fields repeated onto every media row.

## Problem Dataset

```sql
CREATE TABLE posts (
    post_id   INT,
    post_data JSONB
);

INSERT INTO posts VALUES
(1, '{
    "userId": "u1",
    "likeDislike": {"likes": 120, "dislikes": 5, "userAction": "like"},
    "multiMedia": [
        {"id": "m1", "mediatype": "image", "url": "img1.jpg", "likeCount": 10},
        {"id": "m2", "mediatype": "video", "url": "vid1.mp4", "likeCount": 20}
    ]
}'::JSONB),
(2, '{
    "userId": "u2",
    "likeDislike": {"likes": 40, "dislikes": 2, "userAction": "none"},
    "multiMedia": [
        {"id": "m3", "mediatype": "image", "url": "img2.jpg", "likeCount": 5}
    ]
}'::JSONB);
```

Expected output:

| post_id | user_id | likes | dislikes | user_action | media_id | mediatype | url      | media_like_count |
|---------|----------|--------|------------|---------------|-------------|--------------|------------|---------------------|
| 1       | u1       | 120    | 5          | like          | m1          | image        | img1.jpg   | 10                   |
| 1       | u1       | 120    | 5          | like          | m2          | video        | vid1.mp4   | 20                   |
| 2       | u2       | 40     | 2          | none          | m3          | image        | img2.jpg   | 5                    |

## Problem Explanation

Semi-structured JSON columns need two different operations depending on nesting type:
a nested **object** (`likeDislike`) is pulled apart with `->`/`->>` field access, one
field at a time — no fan-out, since there's exactly one object per post. A nested
**array** (`multiMedia`) needs the same explode/fan-out treatment as an SQL array
(see [Explode & Aggregate Skills](../13-explode-and-aggregate-skills/README.md)),
just with a JSON-specific unnest function
(`JSONB_ARRAY_ELEMENTS`) instead of the plain `UNNEST()` used for native array types.

## Problem Answer & Explanation

```sql
SELECT
    p.post_id,
    p.post_data ->> 'userId'                          AS user_id,
    (p.post_data -> 'likeDislike' ->> 'likes')::INT    AS likes,
    (p.post_data -> 'likeDislike' ->> 'dislikes')::INT AS dislikes,
    p.post_data -> 'likeDislike' ->> 'userAction'      AS user_action,
    media ->> 'id'                                     AS media_id,
    media ->> 'mediatype'                              AS mediatype,
    media ->> 'url'                                    AS url,
    (media ->> 'likeCount')::INT                       AS media_like_count
FROM posts p,
     JSONB_ARRAY_ELEMENTS(p.post_data -> 'multiMedia') AS media
ORDER BY p.post_id, media_id;
```

**Why it works**

1. `->` navigates to a nested JSON value and keeps it as `JSONB` (so it can be
   navigated further); `->>` navigates to a value and returns it as `TEXT` directly —
   the rule of thumb is `->` when you're not done drilling down yet, `->>` on the very
   last step.
2. `p.post_data -> 'likeDislike' ->> 'likes'` chains both: `->` steps into the
   `likeDislike` object, `->>` pulls out `likes` as text — which then needs an
   explicit `::INT` cast, since every value extracted from JSON with `->>` comes back
   as text regardless of its original JSON type.
3. `JSONB_ARRAY_ELEMENTS(p.post_data -> 'multiMedia')` in the `FROM` clause is a
   **lateral** expansion (implicit in Postgres, same mechanism as the plain `UNNEST()`
   used elsewhere): it turns the `multiMedia` array into one row per element,
   automatically repeating every other selected column (`post_id`, `user_id`,
   `likes`, ...) onto each of those rows — which is exactly the "post-level fields
   repeated onto every media row" the problem asks for.
4. Each exploded `media` element is itself a small JSON object, so it needs its own
   `->>` extractions (`media ->> 'id'`, etc.) — nesting doesn't stop just because the
   array has been exploded.

**Interview follow-up:** ask how you'd instead go the other direction — build a single
nested JSON document back up from these flattened rows (grouping media items back
into an array per post) — that needs `JSONB_AGG` combined with `JSONB_BUILD_OBJECT`,
the aggregate counterpart to the `->`/`->>` navigation used here, and the reverse of
this problem's operation.
