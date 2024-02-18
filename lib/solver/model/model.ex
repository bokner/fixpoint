defmodule CPSolver.Model do
  alias CPSolver.Constraint
  alias CPSolver.Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.Objective

  defstruct [:name, :variables, :constraints, :objective, :extra, :id]

  @type t :: %__MODULE__{
          id: reference(),
          name: term(),
          variables: [Variable.t()],
          constraints: [Constraint.t()],
          objective: Objective.t(),
          extra: term()
        }

  def new(variables, constraints, opts \\ []) do
    %__MODULE__{
      variables: model_variables(variables, constraints),
      constraints: constraints,
      objective: opts[:objective],
      id: Keyword.get(opts, :id, make_ref()),
      name: opts[:name],
      extra: opts[:extra]
    }
  end

  def model_variables(variables, constraints) do
    variable_map = Map.new(variables, fn v -> {Interface.id(v), Interface.variable(v)} end)

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
