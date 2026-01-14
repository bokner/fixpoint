# Fixpoint and CTM

This document contains a brief description of how Fixpoint uses the ideas of Chapter 12 of "Concepts, Techniques, and Models
  of Computer Programming".

### How does Fixpoint match Chapter 12 suggestions for the implementation of Constraint Programming solver.

The upshot of Chapter 12 is that: 
- we create "top" computational space, which is the collection of variables and constraints;
- run the solver on that space, which may result in a reduction of variable domains and/or constraints in that space;
- branch on the space using some branching strategy (search).

  The branching process is roughly as follows:
  - choose some variable(s) to branch on;
  - for each branch, make "child" copies of the original space;
  - Split parts of the variable domains between branches (for instance, by fixing the value of the variable domain);
  - run the propagation on every "child" space with the set of constraints that have not been reduced.
    Propagation consists of applying the active constraints to the domains of variables until the solver determines that no more domain
    reductions are possible in the current space. This is usually called a "fixpoint" state.
    
- Once a fixpoint is reached, recursively run the solver on child spaces until either all variables are fixed and/or all constraints are *entailed*.
  Entailment of the constraint means that running it on any subset of variable domains will not further reduce the domains.

Corresponding parts of code:

https://github.com/bokner/fixpoint/blob/main/lib/solver/space/space.ex
https://github.com/bokner/fixpoint/blob/main/lib/solver/space/propagation.ex
