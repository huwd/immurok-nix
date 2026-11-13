# Decision records

Significant decisions about this package and module, one per file, with the context and the options that lost.

Records here are about the package and module as other people would consume them.
How any one person configures their own machine belongs in that person's own configuration.

## When to write one

Write a record when a decision:

- is costly or awkward to reverse, such as the shape of the module's options
- chooses between real alternatives, and the losing options are worth remembering
- would leave a future reader asking "why is it like this?"

Routine changes don't need one.

## How to write one

1. Copy [`template.md`](template.md) to `NNNN-short-slug.md`, using the next free number.
2. Fill in every section, and list the options that lost.
3. Add the record to the index below.

Avoid first-person pronouns in records.
Don't rewrite an accepted record when a decision changes.
Write a new record and mark the old one "Superseded by".

## Index

| Number | Decision | Status |
| ------ | -------- | ------ |
| [0001](0001-standalone-flake-with-layered-module.md) | Package as a standalone flake, with a module that installs infrastructure and leaves authentication policy to the user | Accepted |
