defmodule CPSolver.Model do
  alias CPSolver.Constraint
  alias CPSolver.Propagator
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Variable.Interface
  alias CPSolver.Objective

  alias CPSolver.Utils.Vector

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

  defp init_model(variables, constraints, objective) do
    safe_variables =
      Enum.reduce(variables, Vector.new([]), fn v, acc ->
        Vector.append(
          acc,
          (is_integer(v) && Variable.new(v)) || v
        )
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

    all_variables =
      Enum.reduce(additional_variables, safe_variables, fn var, acc ->
        Vector.append(acc, var)
      end)

    indexed_objective =
      all_variables
      |> Enum.with_index(1)
      |> Enum.reduce_while(objective, fn {var, idx}, obj_acc ->
        if obj_acc && Interface.id(var) == Interface.id(obj_acc.variable) do
          obj_var = Interface.update(obj_acc.variable, :index, idx)
          {:halt, Map.put(objective, :variable, obj_var)}
        else
          {:cont, obj_acc}
        end
      end)

    {all_variables, indexed_objective}
  end

  defp extract_variables_from_constraints(constraints) do
    constraints
    |> Enum.map(&Constraint.extract_variables/1)
    |> List.flatten()
    |> Enum.uniq_by(fn var -> Map.get(var, :id) end)
  end

  defp normalize_constraints(constraints) do
    List.flatten(constraints)
  end
end
