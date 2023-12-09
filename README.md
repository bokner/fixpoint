# Constraint Programming Solver

## The approach 
The implementation follows the ideas described in Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.

[An overview of CP implementation in Mozart/Oz.](http://mozart2.org/mozart-v1/doc-1.4.0/fdt/index.html)
## Status

WIP. Not suitable for use in production. Significant API changes and core implementation rewrites are expected.

### Intro

[![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fbokner%2Ffixpoint%2Fblob%2Fmain%2Flivebooks%2Ffixpoint.livemd)


### Implemented constraints

- `not_equal`
- `less_or_equal`
- `all_different` (decomposition to `not_equal`)
- `sum`

### Features
- views (linear combinations of variables in constraints)  


### Examples
- Sudoku
- Graph Coloring
- N-Queens
- Reindeers
- SEND + MORE = MONEY
