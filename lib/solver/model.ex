defmodule CPSolver.Model do
  alias CPSolver.Constraint

  def new(model) do
    Map.put(model, :variables, model_variables(model))
  end

  def model_variables(%{variables: variables, constraints: constraints} = _model) do
    variable_map = Map.new(variables, fn v -> {v.id, v} end)

    ## Additional variables may come from constraint definitions
    ## (example: LessOrEqual constraint, where the second argument is a constant value).
    ##
    additional_variables =
      constraints
      |> extract_variables_from_constraints()
      |> Enum.reject(fn c_var -> Map.has_key?(variable_map, c_var.id) end)

    variables ++ additional_variables
  end

  defp extract_variables_from_constraints(constraints) do
    constraints
    |> Enum.map(&Constraint.extract_variables/1)
    |> List.flatten()
    |> Map.new(fn var -> {var.id, var} end)
    |> Map.values()
  end
end
