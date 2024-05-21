# Details

Date : 2023-10-20 20:09:17

Directory /Users/bokner/projects/cpsolver

Total : 51 files,  2692 codes, 152 comments, 691 blanks, all 3535 lines

[Summary](results.md) / Details / [Diff Summary](diff.md) / [Diff Details](diff-details.md)

## Files
| filename | language | code | comment | blank | total |
| :--- | :--- | ---: | ---: | ---: | ---: |
| [.formatter.exs](/.formatter.exs) | Elixir | 3 | 1 | 1 | 5 |
| [README.md](/README.md) | Markdown | 8 | 0 | 3 | 11 |
| [TODO.md](/TODO.md) | Markdown | 18 | 0 | 3 | 21 |
| [config/config.exs](/config/config.exs) | Elixir | 2 | 0 | 2 | 4 |
| [lib/application.ex](/lib/application.ex) | Elixir | 5 | 0 | 1 | 6 |
| [lib/examples/graph_coloring.ex](/lib/examples/graph_coloring.ex) | Elixir | 35 | 0 | 11 | 46 |
| [lib/examples/queens.ex](/lib/examples/queens.ex) | Elixir | 78 | 8 | 14 | 100 |
| [lib/examples/sudoku.ex](/lib/examples/sudoku.ex) | Elixir | 137 | 35 | 35 | 207 |
| [lib/examples/utils.ex](/lib/examples/utils.ex) | Elixir | 47 | 0 | 10 | 57 |
| [lib/solver/common/common.ex](/lib/solver/common/common.ex) | Elixir | 8 | 0 | 2 | 10 |
| [lib/solver/constraints/all_different.ex](/lib/solver/constraints/all_different.ex) | Elixir | 13 | 0 | 2 | 15 |
| [lib/solver/constraints/constraint.ex](/lib/solver/constraints/constraint.ex) | Elixir | 29 | 0 | 7 | 36 |
| [lib/solver/constraints/not_equal.ex](/lib/solver/constraints/not_equal.ex) | Elixir | 8 | 0 | 2 | 10 |
| [lib/solver/core/solution.ex](/lib/solver/core/solution.ex) | Elixir | 39 | 1 | 7 | 47 |
| [lib/solver/core/solver.ex](/lib/solver/core/solver.ex) | Elixir | 130 | 5 | 32 | 167 |
| [lib/solver/core/space.ex](/lib/solver/core/space.ex) | Elixir | 335 | 5 | 68 | 408 |
| [lib/solver/domain/default_domain.ex](/lib/solver/domain/default_domain.ex) | Elixir | 77 | 0 | 17 | 94 |
| [lib/solver/model/model.ex](/lib/solver/model/model.ex) | Elixir | 4 | 0 | 1 | 5 |
| [lib/solver/propagators/constraint_graph.ex](/lib/solver/propagators/constraint_graph.ex) | Elixir | 70 | 1 | 12 | 83 |
| [lib/solver/propagators/not_equal.ex](/lib/solver/propagators/not_equal.ex) | Elixir | 26 | 0 | 7 | 33 |
| [lib/solver/propagators/propagator.ex](/lib/solver/propagators/propagator.ex) | Elixir | 80 | 3 | 21 | 104 |
| [lib/solver/propagators/propagator_thread.ex](/lib/solver/propagators/propagator_thread.ex) | Elixir | 145 | 4 | 37 | 186 |
| [lib/solver/propagators/propagator_variable.ex](/lib/solver/propagators/propagator_variable.ex) | Elixir | 63 | 0 | 18 | 81 |
| [lib/solver/search/first_fail.ex](/lib/solver/search/first_fail.ex) | Elixir | 29 | 2 | 6 | 37 |
| [lib/solver/search/partition.ex](/lib/solver/search/partition.ex) | Elixir | 10 | 0 | 3 | 13 |
| [lib/solver/search/strategy.ex](/lib/solver/search/strategy.ex) | Elixir | 14 | 0 | 4 | 18 |
| [lib/solver/store/ets_store.ex](/lib/solver/store/ets_store.ex) | Elixir | 117 | 0 | 28 | 145 |
| [lib/solver/store/store.ex](/lib/solver/store/store.ex) | Elixir | 154 | 6 | 42 | 202 |
| [lib/solver/variables/int_variable.ex](/lib/solver/variables/int_variable.ex) | Elixir | 14 | 0 | 3 | 17 |
| [lib/solver/variables/variable.ex](/lib/solver/variables/variable.ex) | Elixir | 79 | 0 | 25 | 104 |
| [lib/utils/utils.ex](/lib/utils/utils.ex) | Elixir | 21 | 3 | 2 | 26 |
| [mix.exs](/mix.exs) | Elixir | 41 | 4 | 6 | 51 |
| [mix.lock](/mix.lock) | Elixir | 14 | 0 | 1 | 15 |
| [scripts/2_2_2_script.exs](/scripts/2_2_2_script.exs) | Elixir | 14 | 0 | 3 | 17 |
| [scripts/2_vars_1_propagator.exs](/scripts/2_vars_1_propagator.exs) | Elixir | 9 | 0 | 4 | 13 |
| [scripts/gc_debug_script.exs](/scripts/gc_debug_script.exs) | Elixir | 23 | 4 | 7 | 34 |
| [scripts/gc_script.exs](/scripts/gc_script.exs) | Elixir | 15 | 0 | 6 | 21 |
| [scripts/queens_debug_script.exs](/scripts/queens_debug_script.exs) | Elixir | 35 | 8 | 14 | 57 |
| [test/constraints/all_different_test.exs](/test/constraints/all_different_test.exs) | Elixir | 36 | 0 | 9 | 45 |
| [test/domain/domain_test.exs](/test/domain/domain_test.exs) | Elixir | 60 | 1 | 21 | 82 |
| [test/examples/graph_coloring_test.exs](/test/examples/graph_coloring_test.exs) | Elixir | 52 | 0 | 18 | 70 |
| [test/examples/queens_test.exs](/test/examples/queens_test.exs) | Elixir | 42 | 1 | 15 | 58 |
| [test/examples/sudoku_test.exs](/test/examples/sudoku_test.exs) | Elixir | 32 | 0 | 9 | 41 |
| [test/propagators/constraint_graph_test.exs](/test/propagators/constraint_graph_test.exs) | Elixir | 35 | 4 | 7 | 46 |
| [test/propagators/not_equal_test.exs](/test/propagators/not_equal_test.exs) | Elixir | 81 | 11 | 18 | 110 |
| [test/propagators/propagator_thread_test.exs](/test/propagators/propagator_thread_test.exs) | Elixir | 113 | 15 | 38 | 166 |
| [test/search/first_fail_test.exs](/test/search/first_fail_test.exs) | Elixir | 40 | 1 | 9 | 50 |
| [test/solver/cpsolver_test.exs](/test/solver/cpsolver_test.exs) | Elixir | 31 | 7 | 10 | 48 |
| [test/space/space_test.exs](/test/space/space_test.exs) | Elixir | 113 | 8 | 36 | 157 |
| [test/store/store_test.exs](/test/store/store_test.exs) | Elixir | 101 | 14 | 32 | 147 |
| [test/test_helper.exs](/test/test_helper.exs) | Elixir | 7 | 0 | 2 | 9 |

[Summary](results.md) / Details / [Diff Summary](diff.md) / [Diff Details](diff-details.md)