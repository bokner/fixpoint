defmodule CPSolver.Search.VariableSelector.AFC do
  @moduledoc """
  Accumulated failure count varaible selector
  (https://www.gecode.org/doc-latest/MPG.pdf, p.8.5.2)
  """
  alias CPSolver.Space
  alias CPSolver.Shared

  @doc """
  Initialize AFC
  """
  def initialize(space_data) do
    propagators = space_data.propagators
    afc_table =  :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])
    |> tap(fn afc_table ->
      Enum.each(propagators, fn p ->
      :ets.insert(afc_table, {p.id, afc_record(1, 0)}) end)
    end)

    space_data
    |> Space.get_shared()
    |> Shared.put_auxillary(:afc, afc_table)
  end

  @doc """
  Compute AFC of variable based on the initial constraint graph
  """
  def variable_afc(variable, shared) do

  end

  @doc """
  Recompute AFC based on last AFC value, decay and current global failure count.
  This is (to be) used:
  - for computing variable AFC;
  - for updating AFC of a failed propagator;
  - for updating AFCs of all propagators in case decay value has been dynamically changed.
  """
  def propagator_afc({afc_value, last_update_at} = afc, decay, global_failure_count, failure? \\ false) when decay > 0 and decay < 1 do
    ## Catch up on decaying (we do not update non-failing propagators on failure event!)
    ## We also assume that total failure count includes the last failure across the search nodes.
    decay_steps = max(0, if failure? do
      global_failure_count - last_update_at - 1
    else
      global_failure_count - last_update_at
    end)

    ## It's impractical to consider more than 100 (probably less) decaying steps - the AFC values will be very
    ## close to 0 even for big global failure counts.
    #
    ## Add 1 to decayed AFC of failing propagator
    new_afc_value = afc_value * :math.pow(decay, min(100, decay_steps)) + (failure? && 1 || 0)

    {new_afc_value, global_failure_count}


  end

  defp afc_record(afc_value, last_failure_at) do
    {afc_value, last_failure_at}
  end

  ## Get AFC propagator record
  def get_afc_record(table, propagator_id) when is_reference(table) do
    table
    |> :ets.lookup(propagator_id)
    |> then(fn rec -> !Enum.empty?(rec) && elem(hd(rec), 1) || nil end)
  end

  def get_afc_record(space_data, propagator_id) do
    space_data
    |> get_afc_table()
    |> get_afc_record(propagator_id)
  end

  def get_afc_table(space_data) do
    space_data
    |> Space.get_shared()
    |> Shared.get_auxillary(:afc)
  end
end
