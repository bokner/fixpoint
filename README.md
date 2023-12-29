# Constraint Programming Solver

## The approach 
The implementation follows the ideas described in Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.

[An overview of CP implementation in Mozart/Oz.](http://mozart2.org/mozart-v1/doc-1.4.0/fdt/index.html)
## Status

Proof of concept. Not suitable for use in production. Significant API changes and core implementation rewrites are expected.

## Intro

[![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fbokner%2Ffixpoint%2Fblob%2Fmain%2Flivebooks%2Ffixpoint.livemd)


## Implemented constraints

- `not_equal`
- `less_or_equal`
- `all_different` (decomposition to `not_equal`)
- `sum`

## Features
- views (linear combinations of variables in constraints)  
- solving for satisfaction (CSP) and optimization (COP)
- distributed solving  

## Installation
The package can be installed by adding `fixpoint` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fixpoint, "~> 0.7.3"}
  ]
end
```

## Usage
  
### Getting started  

Let's solve the following *constraint satisfaction problem*:

***Given two sets of values***

 x = {1,2}, y = {0, 1}

***, find all solutions such that*** x != y

First step is to create a model that describes the problem we want to solve.
The model consists of *variables* and *constraints* over the variables.
In this example, we have 2 variables $x$ and $y$ and a single constraint $x$ $\neq$ $y$

```elixir
alias CPSolver.IntVariable
alias CPSolver.Constraint.NotEqual
alias CPSolver.Model
## Variable constructor takes a domain (i.e., set of values), and optional parameters, such as `name`
x = IntVariable.new([1, 2], name: "x")
y = IntVariable.new([0, 1], name: "y")
## Create NotEqual constraint
neq_constraint =  NotEqual.new(x, y)
```
Now create an instance of `CPSolver.Model`:
```elixir
model = Model.new([x, y], [neq_constraint])
```
Once we have a model, we pass it to `CPSolver.solve/1,2`.

We can either solve asynchronously:
```elixir
## Asynchronous solving doesn't block 
{:ok, solver} = CPSolver.solve(model)
Process.sleep(10)
## We can check for solutions and solver state and/or stats,
## for instance:
## There are 3 solutions: {x = 1, y = 0}, {x = 2,  y = 0}, {x = 2, y = 1} 
iex(46)> CPSolver.solutions(solver)
[[1, 0], [2, 0], [2, 1]]

## Solver reports it has found all solutions    
iex(47)> CPSolver.status(solver)
:all_solutions 

## Some stats
iex(48)> CPSolver.statistics(solver)
%{
  elapsed_time: 2472,
  solution_count: 3,
  active_node_count: 0,
  failure_count: 0,
  node_count: 5
}

```
, or use a blocking call:
```elixir
iex(49)> {:ok, results} = CPSolver.solve_sync(model)
{:ok,
 %{
   status: :all_solutions,
   statistics: %{
     elapsed_time: 3910,
     solution_count: 3,
     active_node_count: 0,
     failure_count: 0,
     node_count: 5
   },
   variables: ["x", "y"],
   objective: nil,
   solutions: [[2, 1], [1, 0], [2, 0]]
 }}
```




### API
```elixir
#################
# Solving       
#################
# 
# Asynchronous solving.
# Takes CPSolver.Model instance and solver options as a Keyword. 
# Creates a solver process which runs asynchronously
# and could be controlled and queried for produced solutions and/or status as it runs.
# The solver process is alive even after the solving is completed.
# It's a responsibility of a caller to shut it down
  
{:ok, solver} = CPSolver.solve(model, solver_opts)

# Synchronous solving.
# Starts the solver and gets the results (solutions and/or solver stats) once the solver finishes.
{:ok, solver_results} = CPSolver.solve_sync(model, solver_opts)
```

, where 
- ```model``` - [specification of the model](#model-specification);
- ```solver_opts (optional)``` - [solver options](#solver-options).

### Model specification

### Configuring solver

### Distributed solving

*Fixpoint* allows to solve an instance of CSP/COP problem using multiple cluster nodes.

Note: *Fixpoint* **will not configure the cluster nodes!** 
It's assumed that each node has the cluster membership and the `fixpoint` dependency is installed on it.
The solving starts on a 'leader' node, and then the work is distributed across participating nodes.
The 'leader' node coordinates the process of solving through shared solver state.

Let's collect all solutions for 8-Queens problem using distributed solving.

For demonstration purposes, we will spawn peer nodes like so:

```zsh
iex --name leader --cookie solver -S mix
```

```elixir
### Let's spawn 2 worker nodes...
worker_nodes = Enum.map(["node1", "node2"], fn node -> 
  {:ok, _pid, node_name} = :peer.start(%{name: node, longnames: true, args: ['-setcookie', 'solver']})
  :erpc.call(node_name, :code, :add_paths, [:code.get_path()])
  node_name
end)
```

Then we'll pass spawned worker nodes to the solver: 

```elixir
## To convince ourselves that the solving runs on worker nodes, we'll use a solution handler:
solution_handler = fn solution -> IO.puts("#{inspect Enum.map(solution, fn {_name, solution} -> solution end)} <- #{inspect Node.self()}") end 
{:ok, _solver} = CPSolver.solve(CPSolver.Examples.Queens.model(8), 
  distributed: worker_nodes, 
  solution_handler: solution_handler)
``` 


### Search

## [Examples](lib/examples)

#### [Reindeer Ordering](lib/examples/reindeers.ex)

Shows how to put together a model that solves a simple riddle.

#### [N-Queens](lib/examples/queens.ex)

Classical N-Queens problem

#### [Sudoku](lib/examples/sudoku.ex)

No explanation needed :-)

#### [SEND+MORE=MONEY](lib/examples/send_more_money.ex)

Cryptoarithmetics problem - a riddle that involves arithmetics.

#### [Knapsack](lib/examples/knapsack.ex)

Constraint Optimization Problem - packing items so they fit the knapsack ***and*** maximize the total value. Think Indiana Jones trying to fill his backpack with treasures in the best way possible :-)

