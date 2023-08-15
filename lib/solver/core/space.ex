defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias __MODULE__, as: Space
  alias CPSolver.ConstraintStore, as: Store
  alias CPSolver.Propagator, as: Propagator
  import CPSolver.Utils

  require Logger

  @behaviour :gen_statem

  defstruct variables: [],
            propagators: [],
            propagator_threads: [],
            store: nil,
            space: nil

  def create(variables, propagators, space_opts \\ [], search \\ nil, gen_statem_opts \\ []) do
    {:ok, _space} =
      :gen_statem.start_link(
        __MODULE__,
        [variables: variables, propagators: propagators, search: search, space_opts: space_opts],
        gen_statem_opts
      )
  end

  def get_state_and_data(space) do
    {_state, _data} = :sys.get_state(space)
  end

  def propagate() do
  end

  def status() do
  end

  def search() do
  end

  def solutions() do
  end

  def stats() do
  end

  @impl true
  def init(args) do
    variables = Keyword.get(args, :variables)
    propagators = Keyword.get(args, :propagators)

    space = self()

    store_impl =
      Keyword.get(args, :space_opts)
      |> Keyword.get(:store, Store.default_store())

    {:ok, space_variables} = store_impl.create(space, variables)

    space_data = %Space{
      variables: space_variables,
      propagators: propagators,
      store: store_impl,
      space: space
    }

    {:ok, :start_propagation, space_data, [{:next_event, :internal, :propagate}]}
  end

  @impl true
  def callback_mode() do
    [:state_functions, :state_enter]
  end

  ## Callbacks
  def start_propagation(:enter, :start_propagation, data) do
    {:keep_state, data}
  end

  def start_propagation(:internal, :propagate, data) do
    propagator_threads = start_propagation(data)
    {:next_state, :propagating, Map.put(data, :propagator_threads, propagator_threads)}
  end

  def propagating(:enter, :start_propagation, data) do
    Logger.debug("Propagation in progress")
    :keep_state_and_data
  end

  def propagating(:info, {:stable, propagator_thread}, data) do
    updated_data = set_propagator_status(data, propagator_thread, :stable)

    if stable?(updated_data) do
      {:next_state, :stable, updated_data}
    else
      {:keep_state, updated_data}
    end
  end

  def propagating(:info, {:running, propagator_thread}, data) do
    {:keep_state, set_propagator_status(data, propagator_thread, :running)}
  end

  def propagating(:info, :fail, data) do
    Logger.debug("The space has failed")
    {:next_state, :failed, data}
  end

  def propagating(:info, :solved, data) do
    Logger.debug("The space has been solved")
    {:next_state, :solved, data}
  end

  def propagating(:info, {propagator_event, propagator}, data)
      when propagator_event in [:stable, :awake] do
    {next_state, new_data} = update_active_propagators({propagator_event, propagator}, data)
    {:next_state, next_state, new_data}
  end

  def propagating(:info, {variable, :fixed}, data) do
    {next_state, new_data} = remove_variable(variable, data)
    {:next_state, next_state, new_data}
  end

  def failed(:enter, :propagating, data) do
    handle_failure(data)
    :keep_state_and_data
  end

  def solved(:enter, :propagating, data) do
    handle_solved(data)
    :keep_state_and_data
  end

  def stable(:enter, :propagating, data) do
    handle_stable(data)
    :keep_state_and_data
  end

  defp start_propagation(%{propagators: propagators, space: space} = _space_state) do
    Logger.debug("Start propagation")

    Enum.reduce(propagators, MapSet.new(), fn p, acc ->
      {:ok, thread} = Propagator.create_thread(space, p)
      subscribe(space, thread)
      MapSet.put(acc, thread)
    end)
  end

  defp update_active_propagators({:stable, propagator}, data) do
    new_data = remove_from_active_list(propagator, data)

    next_state =
      if active_propagators_count(new_data) > 0 do
        :propagating
      else
        :stable
      end

    {next_state, new_data}
  end

  defp update_active_propagators({:awake, propagator}, data) do
    data = add_to_active_list(propagator, data)
    {:propagating, data}
  end

  defp stable?(%{propagator_threads: threads} = _data) do
    MapSet.size(threads) == 0
  end

  defp set_propagator_status(%{propagator_threads: threads} = data, propagator_thread, :stable) do
    %{data | propagator_threads: MapSet.delete(threads, propagator_thread)}
  end

  defp set_propagator_status(%{propagator_threads: threads} = data, propagator_thread, :running) do
    %{data | propagator_threads: MapSet.put(threads, propagator_thread)}
  end

  defp active_propagators_count(data) do
    length(data.propagators)
  end

  defp add_to_active_list(propagator, data) do
    :todo
    data
  end

  defp remove_from_active_list(propagator, data) do
    :todo
    data
  end

  defp remove_variable(variable, data) do
    new_data = remove_variable_impl(variable, data)

    next_state =
      if variable_count(new_data) == 0 do
        :solved
      else
        :propagating
      end

    {next_state, new_data}
  end

  defp remove_variable_impl(variable, data) do
    :todo
    data
  end

  defp variable_count(data) do
    length(data.variables)
  end

  defp handle_failure(data) do
    :todo
  end

  defp handle_solved(data) do
    :todo
  end

  defp handle_stable(data) do
    :todo
  end
end
