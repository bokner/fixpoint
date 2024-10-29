defmodule CPSolver.Search.VariableSelector.AFC do
  @moduledoc """
  Accumulated failure count varaible selector
  (https://www.gecode.org/doc-latest/MPG.pdf, p.8.5.2)
  """
  alias CPSolver.Space

  @doc """
  Initialize AFC
  """
  def initialize_afc(space_data) do
    propagators = space_data.propagators
    afc_table =  :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])
    |> tap(fn afc_table ->
      Enum.each(propagators, fn p ->
      :ets.insert(afc_table, {p.id, 1}) end)
    end)

    Space.put_shared(space_data, :afc, afc_table)
  end
  @doc """
  Compute AFC of variable based on the initial constraint graph
  """
  def variable_afc(variable, space_data) do

  end

  @doc """
  Get current AFC of the propagator
  """
  def propagator_afc(propagator_id, space_data) when is_reference(propagator_id) do

  end

  def update_afc(failed_propagator_id, space_data) do

  end
end
