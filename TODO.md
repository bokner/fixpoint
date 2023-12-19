1. ~~Stateful propagators (needed for 'sum')~~ done
2. ~~Handle propagators that do not have a chance to be fired (like 'less_or_equal' in case bounds of vars do not intersect)~~ done
3. Support solver final status (:satisfied, :all_solutions, :optimal, :unsatisfiable)
4. Add stats for propagators
5. (Maybe) add timestamps and/or elapsed time for solutions
6. (Maybe) add objective values to solutions or give an API to derive them from solution + shared objective
7. Level of parallelism for space creations as a solver option.
8. More search strategies
9. AllDifferent with graphs
10. 'element', 'circuit'
11. Reification   
