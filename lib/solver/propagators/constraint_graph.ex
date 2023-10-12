defmodule CPSolver.Propagator.ConstraintGraph do
  @moduledoc """
  The constraint graph connects propagators and their variables.
  The edge between a propagator and variable represents a notification
  the propagator receives upon varable's domain change.
  """
  alias CPSolver.Propagator
  alias CPSolver.Variable

  @spec create([Propagator.t()]) :: Graph.t()
  def create(propagators) do
    Enum.reduce(propagators, Graph.new(), fn {propagator_mod, args} = _propagator, acc ->
      propagator_id = make_ref()

      args
      |> propagator_mod.variables()
      |> Enum.reduce(acc, fn var, acc2 ->
        Graph.add_edge(acc2, var.id, {:propagator, propagator_id}, label: get_propagate_on(var))
      end)
    end)
  end

  ## TODO: compute notification from propagator definition
  defp get_propagate_on(%Variable{} = variable) do
    Map.get(variable, :propagate_on, :fixed)
  end
end