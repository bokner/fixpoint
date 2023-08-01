defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias __MODULE__, as: Space
  alias CPSolver.ConstraintStore, as: Store
  alias CPSolver.Propagator, as: Propagator
  require Logger

  @behaviour :gen_statem

  defstruct variables: [],
            propagators: [],
            propagator_threads: [],
            constraint_store: nil

  def create(variables, propagators, space_opts, search \\ nil, gen_statem_opts \\ []) do
    {:ok, _space} =
      :gen_statem.start_link(
        __MODULE__,
        [variables: variables, propagators: propagators, search: search, space_opts: space_opts],
        gen_statem_opts
      )
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

    store_backend =
      Keyword.get(args, :space_opts)
      |> Keyword.get(:store_backend, CPSolver.ConstraintStore.default_backend())

    space_data = %Space{
      variables: variables,
      propagators: propagators,
      constraint_store: Store.create(variables, store_backend)
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
    start_propagation(data)
    {:next_state, :propagating, data}
  end

  def propagating(:enter, :start_propagation, data) do
    Logger.debug("Propagating")
    :keep_state_and_data
  end

  def propagating(:info, :fail, data) do
    Logger.debug("Constraint store inconsistent")
    {:next_state, :failed, data}
  end

  def propagating(:info, :solved, data) do
    Logger.debug("The space is solved")
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

    Enum.each(propagators, fn p ->
      Propagator.create_thread(space, p)
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
