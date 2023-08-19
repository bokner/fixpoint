1. Add passing functions and/or list of operations to the store
 (such as [:fixed?, :min] - return fixed value if fixed, otherwise false)
2. If failure, notify the space directly.
3. If var is fixed, notify the space (directly or through propagators?) and update list of fixed vars,
    possibly along with the values, so solution would be part of space by the time it's solved.
    EDIT: maybe we don't want it; it would be a good idea to check if all vars are good (fixed) at the point of space being solved. This will guard against possible bugs (failed/unfixed vars).
4. Search (fork new spaces, implement first_fail as default). 
5. Dispose of failed/solved spaces.
6. Optimization - cache fixed/failed vars that are part of propagator state to avoid unnecessary round trips. 
