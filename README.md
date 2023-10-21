# Constraint Programming Solver

## The approach 
The implementation follows the ideas described in Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.

[An overview of CP implementation in Mozart/Oz.](http://mozart2.org/mozart-v1/doc-1.4.0/fdt/index.html)
## Status

WIP. Not suitable for use in production. Significant API changes and core implementation rewrites are expected.

### Implemented constraints

- `not_equal`
- `all_different` (decomposition to `not_equal`)


### Examples
- Sudoku
- Graph Coloring
- N-Queens
