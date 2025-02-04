defmodule CPSolver.Model do
  alias CPSolver.Constraint
  alias CPSolver.Propagator
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.Objective

  defstruct [:name, :variables, :constraints, :propagators, :objective, :extra, :id]

  @type t :: %__MODULE__{
          id: reference(),
          name: term(),
          variables: [Variable.t()],
          constraints: [Constraint.t()],
          propagators: [Propagator.t()],
          objective: Objective.t(),
          extra: term()
        }

  def new(variables, constraints, opts \\ []) do
    constraints =
    normalize_constraints(constraints)
    # TODO:
    # consider posting constraints and/or building constraint graph/list of propagators here
    ## For instance:
    #

    {all_variables, objective} = init_model(variables, constraints, opts[:objective])

    %__MODULE__{
      variables: all_variables,
      constraints: constraints,
      propagators: Enum.flat_map(constraints, fn c -> Constraint.post(c) end),
      objective: objective,
      id: Keyword.get(opts, :id, make_ref()),
      name: opts[:name],
      extra: opts[:extra]
    }
  end

  def init_model(variables, constraints, objective) do
    safe_variables =
      Enum.map(variables, fn v ->
        (is_integer(v) && Variable.new(v)) || v
      end)

    variable_map =
      Map.new(safe_variables, fn v ->
        {Interface.id(v), Interface.variable(v)}
      end)

    ## Additional variables may come from constraint definitions
    ## (example: LessOrEqual constraint, where the second argument is a constant value).
    ##
    additional_variables =
      constraints
      |> extract_variables_from_constraints()
      |> Enum.reject(fn c_var -> Map.has_key?(variable_map, c_var.id) end)

    (safe_variables ++ additional_variables)
    |> Enum.with_index(1)
    |> Enum.map_reduce(objective, fn {var, idx}, obj_acc ->
      {
        Interface.update(var, :index, idx),
        if obj_acc && Interface.id(var) == Interface.id(obj_acc.variable) do
          obj_var = Interface.update(obj_acc.variable, :index, idx)
          Map.put(objective, :variable, obj_var)
        else
          obj_acc
        end
      }
    end)
  end

  defp extract_variables_from_constraints(constraints) do
    constraints
    |> Enum.map(&Constraint.extract_variables/1)
    |> List.flatten()
    |> Enum.uniq_by(fn var -> Map.get(var, :id) end)
  end

  ~S"""
    Transform list of constraints of different types
    into the list of plain constraints.
    For now just flatten (but maybe more in the future
    for factory-constructed constraints etc.)
  """

  defp normalize_constraints(constraints) do
    List.flatten(constraints)
  end
end
