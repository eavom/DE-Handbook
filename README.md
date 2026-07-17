# Data Engineering Handbook

A structured knowledge base for data engineers — concept notes, deep dives, code snippets, and career-growth material collected in one place. These are the notes you build once and revisit every time you need to refresh a topic, design a system, or grow into an architect role.

## What goes in this repo

- **Concept notes** — clear, self-contained explanations of core topics (partitioning, SCDs, shuffle internals, indexing, etc.) written to be re-readable months later
- **Deep dives** — how things work under the hood: Spark execution, warehouse storage formats, query optimizers
- **Code snippets & patterns** — reusable, tested examples in Python, PySpark, SQL, Go, and shell
- **Design references** — architecture diagrams, trade-off discussions, and decision checklists for system and solution design
- **Career material** — non-technical skills and the paths from data engineer to data/solution architect

## Repository structure

```
DE-Handbook/
├── SQL/                 # SQL fundamentals to advanced: window functions, CTEs,
│                        #   query optimization, indexing, execution plans
├── Python/              # Core Python for DE work: data structures, OOP, typing,
│                        #   testing, packaging, gotchas and idioms
├── PySpark/             # PySpark API notes and reusable snippets: DataFrame ops,
│                        #   UDFs, joins, incremental loads
├── Spark/               # Spark internals: architecture, jobs/stages/tasks, memory
│                        #   management, tuning, skew handling, Structured Streaming
├── Datawarehouse/       # Modeling & warehousing: star/snowflake schemas, SCDs, CDC,
│                        #   data vault, lakehouse concepts, governance, data quality
├── System Design/       # Designing data platforms: batch vs streaming pipelines,
│                        #   storage/compute choices, scalability, reliability, cost
├── Design Pattern/      # Software & pipeline design patterns: factory, strategy,
│                        #   metadata-driven frameworks, idempotency, retry patterns
├── DSA/                 # Data structures & algorithms notes and practice
├── Shell Scripting/     # Bash/PowerShell essentials for automation and ops
├── Go/                  # Go language notes for building fast data tooling
├── AI/                  # Generative AI for data engineering: LLMs, RAG,
│                        #   prompt engineering, AI-assisted pipelines
├── ML/                  # ML fundamentals a DE should know: feature pipelines,
│                        #   model lifecycle, MLOps touchpoints
├── Data Architect/      # Growing into data architecture: platform strategy,
│                        #   governance, metadata management, reference architectures
├── Solution Architect/  # Solution architecture: requirements to design, cloud
│                        #   service selection, integration patterns, cost/security
└── Non Tech/            # Soft skills: communication, stakeholder management,
│                        #   estimation, mentoring, interviews from the other side
```

## How to use it

1. **Learning a topic?** Start with the folder's concept notes, then move to the deep dives.
2. **Preparing for an interview?** Use the concept notes to refresh fundamentals, then practice explaining each topic out loud in your own words.
3. **Designing something at work?** Jump straight to `System Design/`, `Design Pattern/`, or the architect folders for checklists and reference material.

## Conventions

- One topic per markdown file, named descriptively (e.g., `scd-type-2.md`, `spark-memory-management.md`)
- Start each note with a short "why this matters" line, then the explanation, then examples
- Code snippets should be runnable as-is wherever possible
- Diagrams live next to the note that uses them (Mermaid preferred, images welcome)

## Status

The folder structure is in place; content is being added incrementally. Contributions and suggestions are welcome — open an issue or PR with new notes following the conventions above.

## License

See [LICENSE](LICENSE).
