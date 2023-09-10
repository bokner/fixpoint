1. Add passing functions and/or a list of operations to the store
 (such as [:fixed?, :min] - return fixed value if fixed, otherwise false)
2. If failure, notify the space directly.
3. If var is fixed, ~~notify the space (directly or through propagators?) and update the list of fixed vars,
    possibly along with the values, so the solution would be part of space by the time it's solved.~~
   
    EDIT: maybe we don't want it; it would be a good idea to check if all vars are good (fixed) at the point of space being solved. This will guard against possible bugs (failed/unfixed vars).
5. ~~Search (fork new spaces, implement first_fail as default).~~ done. 
6. Dispose of failed/solved spaces. Edit: done, but need a test for it. Need to dispose of store vars as well.
7. Optimization - cache fixed/failed vars that are part of the propagator state to avoid unnecessary roundtrips.
8. ~~Search: limit the number of solutions~~ done.
9. Control the solver (async ops: stop, get stats etc.).
10. More granular propagation (domain vs. bound consistency) 

11. Do not rely on vars' ref() order to match with their solutions

12. Write models for ~~Queens~~(done) and Sudoku puzzles.
13. Wrap 'select_variable' and 'partition' funcs into 'branching' interface.
14. Rewrite propagator thread to gen_statem.
15. Rewrite Space to use graph store.
