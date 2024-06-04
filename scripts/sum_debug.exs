defmodule SumDebug do
  alias CPSolver.ConstraintStore
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Propagator
  alias CPSolver.Propagator.Sum
  alias CPSolver.Constraint.Sum, as: SumConstraint
  alias CPSolver.Model

  def debug(y_domain, x_domains) do
    y = Variable.new(y_domain, name: "Y")

    xs =
      Enum.map(x_domains |> Enum.with_index(1), fn {d, idx} ->
        Variable.new(d, name: "x.#{idx}")
      end)

    {:ok, [y_var | x_vars] = bound_vars, store} = ConstraintStore.create_store([y | xs])

    # Enum.each(bound_vars, fn v -> IO.inspect("#{v.name} => #{inspect v.id}, #{min(v)}..#{max(v)}") end)
    # assert :stable ==
    sum_propagator = Sum.new(y_var, x_vars)
    IO.inspect(sum_propagator.args)

    Propagator.filter(sum_propagator, store: store)
  end

  def debug_constraint(y_domain, x_domains) do
    y = Variable.new(y_domain, name: "Y")

    xs =
      Enum.map(x_domains |> Enum.with_index(1), fn {d, idx} ->
        Variable.new(d, name: "x.#{idx}")
      end)

    sum_constraint = SumConstraint.new(y, xs)

    model =
      Model.new(
        [y | xs],
        [sum_constraint]
      )

    {:ok, _res} = CPSolver.solve_sync(model)
  end
end

SumDebug.debug_constraint(1..55, [1..10, 1..50])
