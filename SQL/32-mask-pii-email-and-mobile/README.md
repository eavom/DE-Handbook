# Mask PII — Email & Mobile

[⬅ Back to Master Index](../MASTER.md)

![Difficulty: Basic](https://img.shields.io/badge/Difficulty-Basic-brightgreen?style=flat-square) ![Query Type: DQL](https://img.shields.io/badge/Query%20Type-DQL-2980B9?style=flat-square) ![String Masking](https://img.shields.io/badge/-String%20Masking-F39C12?style=flat-square)

> Adapted from `Scenerio12.scala` in `interview-scenerios-spark-sql`, which used a
> Scala UDF for the masking logic — translated here into plain SQL string functions.

## Problem Statement

Given a table of customer emails and mobile numbers, mask them for display in a
support dashboard: keep the email's first character and domain visible, replace
everything between with `**********` (10 asterisks); keep the mobile number's first 2
and last 3 digits visible, replace the middle with `*****` (5 asterisks).

## Problem Dataset

```sql
CREATE TABLE customer_contacts (
    email  VARCHAR(50),
    mobile VARCHAR(15)
);

INSERT INTO customer_contacts VALUES
('renuka1992@gmail.com', '9856765434'),
('anbu.arasu@gmail.com', '9844567788');
```

Expected output:

| email                  | masked_email             | mobile      | masked_mobile |
|-------------------------|----------------------------|--------------|-----------------|
| renuka1992@gmail.com    | r**********92@gmail.com    | 9856765434   | 98*****434      |
| anbu.arasu@gmail.com    | a**********su@gmail.com    | 9844567788   | 98*****788      |

## Problem Explanation

Masking is just string surgery: take a fixed prefix, a fixed number of masking
characters, and a fixed suffix, and concatenate them. `SUBSTRING(text FROM start FOR
length)` (or the shorthand `SUBSTRING(text FROM start)` for "to the end") pulls out
the visible pieces, `REPEAT('*', n)` generates the masked middle, and `||`
concatenates them back together. The only fiddly part is getting the character
positions right — SQL substrings are 1-indexed, unlike many programming languages'
0-indexed strings.

## Problem Answer & Explanation

```sql
SELECT
    email,
    SUBSTRING(email FROM 1 FOR 1) || REPEAT('*', 10) || SUBSTRING(email FROM 9) AS masked_email,
    mobile,
    SUBSTRING(mobile FROM 1 FOR 2) || REPEAT('*', 5) || SUBSTRING(mobile FROM LENGTH(mobile) - 2) AS masked_mobile
FROM customer_contacts;
```

**Why it works**

1. `SUBSTRING(email FROM 1 FOR 1)` takes just the first character (index 1 in SQL's
   1-based indexing — the equivalent of `email[0]` in a 0-indexed language).
2. `SUBSTRING(email FROM 9)` (no `FOR` length) takes everything from position 9
   onward — for `renuka1992@gmail.com`, that's `92@gmail.com`. Note the mask is a
   **fixed** 10-character block (`REPEAT('*', 10)`) regardless of how many real
   characters it's standing in for — positions 2-8 (7 characters) are dropped
   entirely, and the 10 stars are purely a visual placeholder, not a 1-to-1
   substitution. That fixed "always start revealing at position 9" rule only makes
   sense for emails with a long enough local part (see the follow-up for what breaks).
3. `SUBSTRING(mobile FROM LENGTH(mobile) - 2)` computes the starting position
   dynamically as "3 characters from the end," so it correctly reveals the last 3
   digits regardless of the mobile number's exact length — a more robust pattern than
   the email mask's hardcoded position.

**Interview follow-up:** ask what happens to this email mask on a short address like
`a@gmail.com` (position 9 would land inside `gmail.com`, cutting off part of the
domain) — this is exactly why hardcoded positions are fragile. A more robust version
would locate the `@` dynamically with `POSITION('@' IN email)` and mask a *relative*
number of characters before it, rather than assuming every email's local part is at
least 8 characters long.
