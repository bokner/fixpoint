# Constraint Programming Solver

### The approach 
The implementation follows the ideas described in Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.

[An overview of CP implementation in Mozart/Oz.](http://mozart2.org/mozart-v1/doc-1.4.0/fdt/index.html)
### Status

Proof of concept. Not suitable for use in production. Significant API changes and core implementation rewrites are expected.

### Intro

[![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fbokner%2Ffixpoint%2Fblob%2Fmain%2Flivebooks%2Ffixpoint.livemd)


### Implemented constraints

- `not_equal`
- `less_or_equal`
- `all_different` (decomposition to `not_equal`)
- `sum`

### Features
- views (linear combinations of variables in constraints)  
- solving for satisfaction (CSP) and optimization (COP)
- distributed solving  

### Installation
The package can be installed by adding `fixpoint` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fixpoint, "~> 0.7.3"}
  ]
end
```

### Usage
- [Basic examples](#basic-examples)
- [API](#api)
- [Model specification](#model-specification)
- [Configuring the solver](#solver-options)
    
- [Examples](#examples)
    - [Reindeer Ordering](#reindeer-ordering)
    - [SEND+MORE=MONEY](#send_more_money)
    - [N-Queens](#n-queens)
    - [Sudoku](#sudoku)
    - [Graph Coloring](#graph-coloring)
    - [Knapsack](#knapsack)


  
#### Basic examples  

***Given two sets of values:***

 $x$ $\in$ {1,2}, $y$ $\in$ {0, 1}

***, find all solutions such that*** $x$ $\neq$ $y$

First step is to create a model that describes the problem we want to solve.
The model consists of *variables* and *constraints* over the variables.
In this example, we have 2 variables $x$ and $y$ and a single constraint $x$ $\neq$ $y$

```elixir
alias CPSolver.IntVariable
alias CPSolver.Constraint.NotEqual
## Variable constructor takes a domain (i.e., set of values), and optional parameters, such as `name`
x = IntVariable.new([1, 2], name: "x")
y = IntVariable.new([0, 1], name: "y")
## Create NotEqual constraint
neq_constraint =  NotEqual.new(x, y)
```
Now create a `Model` instance:
```elixir
model = Model.new([x, y], [neq_constraint])
```
Once we have a model, we pass it to the solver.
We can either solve asynchronously:
```elixir
## Asynchronous solving doesn't block 
{:ok, solver} = CPSolver.solve(model)
Process.sleep(10)
## We can check for solutions and solver state and/or stats,
## for instance:
CPSolver.solutions(solver) 
```




#### API
```elixir
#################
# Solving       
#################
#
# Asynchronous solving.
# Creates a solver process
{:ok, solver_pid} = CPSolver.solve(model, solver_opts)

# Synchronous solving.
# Starts the solver and gets the results (solutions and/or solver stats) once the solver finishes.
solver_results = MinizincSolver.solve_sync(model, data, solver_opts, server_opts)
```

, where 
- ```model``` - [specification of the model](#model-specification);
- ```solver_opts (optional)``` - [solver options](#solver-options).

```elixir


