defmodule CPSolver.Search.VariableSelector.AFC do
  @moduledoc """
  Accumulated failure count variable selector
  (https://www.gecode.org/doc-latest/MPG.pdf, p.8.5.2)
  """
  use CPSolver.Search.VariableSelector
  alias CPSolver.Space
  alias CPSolver.Shared
  alias CPSolver.Propagator.ConstraintGraph
  alias CPSolver.Variable.Interface
  alias CPSolver.Utils

  @impl true
  def select(variables, data) do
    select(variables, data, mode: :afc_size_min)
  end

  def select(variables, data, opts) do
    #IO.inspect(opts[:mode], label: :afc_mode)
    select_impl(variables, data, opts[:mode])
    |> Enum.map(fn {var, _afc} -> var end)
  end

  defp select_impl(variables, data, :afc_min) do
    Utils.minimals(
      variable_afcs(variables, Space.get_shared(data)),
      fn {_var, afc} -> afc end
    )
  end

  defp select_impl(variables, data, :afc_max) do
    Utils.maximals(
      variable_afcs(variables, Space.get_shared(data)),
      fn {_var, afc} -> afc end
    )
  end

  defp select_impl(variables, data, :afc_size_min) do
    Utils.minimals(
      variable_afcs(variables, Space.get_shared(data)),
      fn {var, afc} -> afc / Interface.size(var) end
    )
  end

  defp select_impl(variables, data, :afc_size_max) do
    Utils.maximals(
      variable_afcs(variables, Space.get_shared(data)),
      fn {var, afc} ->
        afc / Interface.size(var)
      end
    )
  end

  @doc """
  Initialize AFC
  """
  @impl true
  def initialize(space_data, opts) do
    shared = Space.get_shared(space_data)
    decay = opts[:decay]
    Shared.get_auxillary(shared, :afc) ||
      (
        afc_table = Shared.create_shared_ets_table(shared)
        Shared.put_auxillary(shared, :afc, %{propagator_afcs: afc_table, decay: decay})
        Shared.add_handler(shared, :on_failure,
          fn solver, {:fail, propagator_id} = _failure, failure_count ->
            update_afc(propagator_id, solver, true, failure_count)
          end
        )
      )
  end

  @doc """
  Compute AFCs of variables in one pass
  """
  def variable_afcs(variables, shared) do
    graph = Shared.get_auxillary(shared, :initial_constraint_graph)
    afc_data = Shared.get_auxillary(shared, :afc)
    global_failure_count = Shared.get_failure_count(shared)

    if graph && afc_data && global_failure_count do
      %{propagator_afcs: afc_table, decay: decay} = afc_data

      {propagator_ids, propagators_by_variable} =
        Enum.reduce(variables, {MapSet.new(), Map.new()}, fn var, {propagator_ids_acc, map_acc} ->
          p_ids = ConstraintGraph.get_propagator_ids(graph, Interface.id(var))

          {
            MapSet.union(propagator_ids_acc, MapSet.new(p_ids)),
            Map.put(map_acc, var, p_ids)
          }
        end)

      ## Get p_id => afc_record map from ETS table

      afc_records =
        :ets.select(afc_table, for(p_id <- propagator_ids, do: {{p_id, :_}, [], [:"$_"]}))
        |> Map.new()

      ## Collect variable AFCs
      Enum.map(propagators_by_variable, fn {var, var_propagator_ids} ->
        {var,
         Enum.reduce(var_propagator_ids, 0, fn p_id, sum_acc ->
           sum_acc +
             (afc_records
              |> Map.get(p_id, afc_record(1, 0))
              |> propagator_afc(decay, global_failure_count)
              |> elem(0))
         end)}
      end)
    else
      Enum.map(variables, fn var -> {var, 1} end)
    end
  end

  @doc """
  Compute AFC of variable based on the initial constraint graph.
  """
  def variable_afc(variable_id, shared) when is_reference(variable_id) do
    shared
    |> Shared.get_auxillary(:initial_constraint_graph)
    |> then(fn graph ->
      (graph &&
         ConstraintGraph.get_propagator_ids(graph, variable_id)) || []
    end)
    |> afc_sum(shared)
  end

  def variable_afc(variable, shared) do
    variable_afc(Interface.id(variable), shared)
  end

  defp afc_sum(propagator_ids, shared) do
    case Shared.get_auxillary(shared, :afc) do
      %{propagator_afcs: afc_table, decay: decay} ->
        global_failure_count = Shared.get_failure_count(shared)

        propagator_records =
          :ets.select(afc_table, for(p_id <- propagator_ids, do: {{p_id, :_}, [], [:"$_"]}))

        ## We add the count for not recorded  propagators (the ones that did not have failures yet)
        not_recorded_count = length(propagator_ids) - length(propagator_records)

        not_recorded_decay =
          (propagator_afc(afc_record(1, 0), decay, global_failure_count) |> elem(0)) *
            not_recorded_count

        Enum.reduce(propagator_records, not_recorded_decay, fn {_p_id, afc_record}, sum_acc ->
          sum_acc +
            (propagator_afc(afc_record, decay, global_failure_count) |> elem(0))
        end)

      _ ->
        0
    end
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
      when decay > 0 and decay <= 1 do
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
    |> then(fn rec ->
      (!Enum.empty?(rec) && elem(hd(rec), 1)) ||
        afc_record(1, 0) |> tap(fn rec -> :ets.insert(table, {propagator_id, rec}) end)
    end)
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
  def update_afc(propagator_id, shared, failure?, global_failure_count \\ nil) do
    %{propagator_afcs: afc_table, decay: decay} = Shared.get_auxillary(shared, :afc)

    failure_count = global_failure_count || Shared.get_failure_count(shared)

    updated_record =
      case get_afc_record(afc_table, propagator_id) do
        nil ->
          propagator_afc(afc_record(1, 0), decay, failure_count, failure?)

        afc_record ->
          propagator_afc(afc_record, decay, failure_count, failure?)
      end

    :ets.insert(afc_table, {propagator_id, updated_record})
  end
end
