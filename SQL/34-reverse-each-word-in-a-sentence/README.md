# Reverse Each Word in a Sentence

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Intermediate](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![Array Functions](https://img.shields.io/badge/-Array%20Functions-7F8C8D?style=flat-square) ![String Aggregation](https://img.shields.io/badge/-String%20Aggregation-F39C12?style=flat-square)

> Adapted from `Scenerio18.scala` in `interview-scenerios-spark-sql`, which used a
> Scala UDF (`sentence.split(" ").map(_.reverse).mkString(" ")`) — translated here
> into plain SQL.

## Problem Statement

Given a table of sentences, reverse the letters **within each word**, but keep the
words themselves in their original order. `"The Social Dilemma"` becomes
`"ehT laicoS ammeliD"` — not `"Dilemma Social The"`.

## Problem Dataset

```sql
CREATE TABLE sentences (
    sentence_id INT,
    sentence    TEXT
);

INSERT INTO sentences VALUES
(1, 'The Social Dilemma'),
(2, 'Data Engineering Handbook');
```

Expected output:

| sentence_id | reversed_sentence            |
|--------------|---------------------------------|
| 1            | ehT laicoS ammeliD              |
| 2            | ataD gnireenignE koobdnaH       |

## Problem Explanation

This needs three steps chained together: split the sentence into words, reverse each
word individually, then rejoin them **in their original order**. The tricky part is
that last requirement — once a sentence is exploded into one row per word (via the
same `STRING_TO_ARRAY` + `UNNEST` pattern used in
[Explode & Aggregate Skills](../13-explode-and-aggregate-skills/README.md)), the rows
have no inherent order unless something explicitly preserves it. `WITH ORDINALITY` is
the fix: it attaches each exploded element's original array position as an extra
column, which can then drive the `ORDER BY` when reassembling the sentence.

## Problem Answer & Explanation

```sql
WITH tokens AS (
    SELECT
        sentence_id,
        ordinality,
        REVERSE(word) AS reversed_word
    FROM sentences,
         UNNEST(STRING_TO_ARRAY(sentence, ' ')) WITH ORDINALITY AS t(word, ordinality)
)
SELECT
    sentence_id,
    STRING_AGG(reversed_word, ' ' ORDER BY ordinality) AS reversed_sentence
FROM tokens
GROUP BY sentence_id
ORDER BY sentence_id;
```

**Why it works**

1. `STRING_TO_ARRAY(sentence, ' ')` splits each sentence into an array of words.
2. `UNNEST(...) WITH ORDINALITY AS t(word, ordinality)` explodes that array into rows
   *and* emits a second column (`ordinality`) holding each word's 1-based position in
   the original array — without `WITH ORDINALITY`, that positional information would
   be lost the moment the array becomes a set of unordered rows.
3. `REVERSE(word)` reverses the individual word's characters — this happens per row,
   independent of every other word.
4. `STRING_AGG(reversed_word, ' ' ORDER BY ordinality)` reassembles the reversed words
   back into a single string, and the `ORDER BY ordinality` inside the aggregate is
   what guarantees the words come back in their original order rather than some
   arbitrary (or accidentally alphabetical) order.

**Interview follow-up:** ask what changes if the requirement flips — reverse the
**word order** but keep each word's letters intact (`"The Social Dilemma"` →
`"Dilemma Social The"`) — that's actually simpler: skip the `REVERSE(word)` step
entirely and instead order the final `STRING_AGG` by `ordinality DESC`, since the
letters within each word never need touching.
