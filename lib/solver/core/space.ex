defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias __MODULE__, as: Space
  alias CPSolver.ConstraintStore, as: Store
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
      propagator_threads: create_propagator_threads(propagators),
      constraint_store: Store.create(variables, store_backend)
    }

    {:ok, :start_propagation, space_data, [{:next_event, :internal, :propagate}]}
  end

  @impl true
  def callback_mode() do
    [:state_functions, :state_enter]
  end

  defp create_propagator_threads(propagators) do
    :todo
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

  defp start_propagation(propagator_threads) do
    Logger.debug("Start propagation")

    Enum.each(propagator_threads, fn thread ->
      nil
    end)
  end
end
