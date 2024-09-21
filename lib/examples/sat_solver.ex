defmodule CPSolver.Examples.SatSolver do
  alias CPSolver.Constraint.Or
  alias CPSolver.Model
  alias CPSolver.BooleanVariable
  alias CPSolver.Variable.Interface
  import CPSolver.Variable.View.Factory

  @moduledoc """
  This module solves SAT problems represented in CNF form.
  It's a list of lists of integers, where a positive integer `i` represents a boolean variable mapped to `i`,
  and a negative integer `j` represents negation of a boolean variable mapped to `j`.
  Examples of CNF representation:

  ```elixir
  # x1 AND (NOT x1)
  [[1], [-1]]

  # x1 AND (x1 OR x2 OR x3)
  [[1], [1, 2, 3]]

  # x1 AND x2 AND x3
  [[1], [2], [3]]
  ```
  """
  def solve(clauses) do
    model = model(clauses)

    {:ok, res} =
      CPSolver.solve_sync(model,
        search: {:first_fail, :indomain_max},
        stop_on: {:max_solutions, 1}
      )

    res.status != :unsatisfiable && hd(res.solutions) |> sort_by_variables(res.variables)

  end

  def model(clauses) do
    {vars, constraints} =
      Enum.reduce(clauses, {Map.new(), []}, fn clause, {vars_acc, constraints_acc} ->
        {clause_vars, new_vars_acc} = build_clause(clause, vars_acc)
        {new_vars_acc, [Or.new(clause_vars) | constraints_acc]}
      end)

    final_vars =
      Enum.flat_map(vars, fn {literal_id, var} -> (literal_id > 0 && [var]) || [] end)
      |> Enum.sort_by(fn var -> Interface.variable(var).name end)

    Model.new(final_vars, constraints)
  end

  def check_solution(solution, clauses) do
    ## Transform the solution into the form compatible with clause representation.
    cnf_solution = to_cnf(solution)

    Enum.all?(clauses, fn clause ->
      Enum.any?(clause, fn literal -> literal in cnf_solution end)
    end)
  end

  def to_cnf(solution) do
    Enum.reduce(Enum.with_index(solution, 1), MapSet.new(),
    fn {bool, idx}, acc ->
      set_val = (bool == 0 && -idx || idx)
      MapSet.put(acc, set_val)
    end)
  end

  defp build_clause(clause, literal_map) do
    Enum.reduce(clause, {[], literal_map}, fn literal, {clause_acc, literal_map_acc} ->
      ## Get or create literal variable
      ## Has literal variable been already registered?
      {literal_var, updated_literal_map} =
        case Map.get(literal_map_acc, literal) do
          nil ->
            ## New literal variable, create it and update the literal map
            new_literal_variable = create_variable(literal, Map.get(literal_map_acc, -literal))
            {new_literal_variable, Map.put(literal_map_acc, literal, new_literal_variable)}

          existing_literal_variable ->
            {existing_literal_variable, literal_map_acc}
        end

      {[literal_var | clause_acc], updated_literal_map}
    end)
  end

  ## Creates a literal variable
  defp create_variable(var_id, nil) when is_integer(var_id) do
    ## No literal variable of opposite sign
    var = BooleanVariable.new(name: "#{abs(var_id)}")
    (var_id > 0 && var) || negation(var)
  end

  defp create_variable(var_id, negation) when var_id > 0 do
    Interface.variable(negation)
  end

  defp create_variable(var_id, positive_literal_variable) when var_id < 0 do
    negation(positive_literal_variable)
  end

  defp sort_by_variables(solution, variables) do
    Enum.zip(solution, variables)
    |> Enum.sort_by(fn {_val, var_name} -> var_name end)
    |> Enum.map(fn {val, _var_name} -> val end)
  end
end
