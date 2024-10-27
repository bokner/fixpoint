defmodule CPSolver.Search.VariableSelector.AFC do
  @moduledoc """
  Accumulated failure count varaible selector
  (https://www.gecode.org/doc-latest/MPG.pdf, p.8.5.2)
  """

  @doc """
  Compute AFC of variable based on the initial constraint graph
  """
  def afc(%Graph{} = constraint_graph, solver) do

  end

  @doc """
  Get current AFC of the propagator
  """
  def propagator_afc(propagator_id, solver) when is_reference(propagator_id) do

  end
end
