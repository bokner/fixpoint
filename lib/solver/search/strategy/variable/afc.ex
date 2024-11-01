defmodule CPSolver.Search.VariableSelector.AFC do
  @moduledoc """
  Accumulated failure count varaible selector
  (https://www.gecode.org/doc-latest/MPG.pdf, p.8.5.2)
  """
  alias CPSolver.Space
  alias CPSolver.Shared
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Variable.Interface

  @doc """
  Initialize AFC
  """
  def initialize(space_data, decay) do
    propagators = space_data.propagators

    afc_table =
      :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: false])
      |> tap(fn afc_table ->
        Enum.each(propagators, fn p ->
          :ets.insert(afc_table, {p.id, afc_record(1, 0)})
        end)
      end)

    space_data
    |> Space.get_shared()
    |> Shared.put_auxillary(:afc, %{propagator_afcs: afc_table, decay: decay})
  end

  @doc """
  Compute AFC of variable based on the initial constraint graph.
  """
  def variable_afc(variable_id, shared) when is_reference(variable_id) do
    shared
    |> Shared.get_auxillary(:initial_constraint_graph)
    |> ConstraintGraph.get_propagator_ids(variable_id)
    |> afc_sum(shared)
  end

  def variable_afc(variable, shared) do
    variable_afc(Interface.id(variable), shared)
  end

  defp afc_sum(propagator_ids, shared) do
    %{propagator_afcs: afc_table, decay: decay} = Shared.get_auxillary(shared, :afc)
    global_failure_count = Shared.get_failure_count(shared)

    :ets.select(afc_table, for(p_id <- propagator_ids, do: {{p_id, :_}, [], [:"$_"]}))
    |> Enum.reduce(0, fn {_p_id, afc_record}, sum_acc ->
      sum_acc +
        (propagator_afc(afc_record, decay, global_failure_count) |> elem(0))
    end)
  end

  @doc """
  Compute AFC based on last AFC value, decay and current global failure count.
  This is (to be) used:
  - for computing variable AFC;
  - for updating AFC of a failed propagator;
  - for updating AFCs of all propagators in case decay value has been dynamically changed.
  """
  def propagator_afc(
        {afc_value, last_update_at} = _afc_record,
        decay,
        global_failure_count,
        failure? \\ false
      )
      when decay > 0 and decay < 1 do
    ## Catch up on decaying (we do not update non-failing propagators on failure event!)
    ## We also assume that total failure count includes the last failure across the search nodes.
    decay_steps =
      max(
        0,
        if failure? do
          global_failure_count - last_update_at - 1
        else
          global_failure_count - last_update_at
        end
      )

    ## It's impractical to consider a lot of decaying steps.
    ## Considering afc <- afc * decay formula, the AFC values will be very
    ## close to 0 for a small number of decays even if global failure count is high.
    # We land on 100 as max for decay steps.
    max_decay_steps = 100
    ## Add 1 to decayed AFC of failing propagator
    new_afc_value =
      afc_value * :math.pow(decay, min(max_decay_steps, decay_steps)) + ((failure? && 1) || 0)

    {new_afc_value, global_failure_count}
  end

  def propagator_afc(propagator_id, shared) do
    %{propagator_afcs: afc_table, decay: decay} = Shared.get_auxillary(shared, :afc)

    propagator_afc(
      get_afc_record(afc_table, propagator_id),
      decay,
      Shared.get_failure_count(shared)
    )
  end

  defp afc_record(afc_value, last_failure_at) do
    {afc_value, last_failure_at}
  end

  ## Get AFC propagator record
  def get_afc_record(table, propagator_id)
      when is_reference(table) and is_reference(propagator_id) do
    table
    |> :ets.lookup(propagator_id)
    |> then(fn rec -> (!Enum.empty?(rec) && elem(hd(rec), 1)) || nil end)
  end

  def get_afc_record(propagator_id, shared) do
    shared
    |> get_afc_table()
    |> get_afc_record(propagator_id)
  end

  def get_afc_table(shared) do
    Shared.get_auxillary(shared, :afc)
    |> Map.get(:propagator_afcs)
  end

  def get_decay(shared) do
    Shared.get_auxillary(shared, :afc)
    |> Map.get(:decay)
  end

  ## Update AFC in 'shared'
  def update_afc(propagator_id, shared, failure?) do
    %{propagator_afcs: afc_table, decay: decay} = Shared.get_auxillary(shared, :afc)

    case get_afc_record(afc_table, propagator_id) do
      nil ->
        nil

      afc_record ->
        updated_record =
          propagator_afc(afc_record, decay, Shared.get_failure_count(shared), failure?)

        :ets.insert(afc_table, {propagator_id, updated_record})
    end
  end
end
