defmodule CPSolver.Space do
  @moduledoc """
  Computation space.
  The concept is taken from Chapter 12, "Concepts, Techniques, and Models
  of Computer Programming" by Peter Van Roy and Seif Haridi.
  """

  alias __MODULE__, as: Space
  require Logger

  @behaviour :gen_statem

  defstruct variables: [],
            propagators: [],
            propagator_threads: [],
            constraint_store: nil

  def create(variables, propagators, space_opts, gen_statem_opts \\ []) do
    {:ok, _space} =
      :gen_statem.start_link(
        __MODULE__,
        [variables: variables, propagators: propagators, space_opts: space_opts],
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
  def init(space_args) do
    variables = Keyword.get(space_args, :variables)
    propagators = Keyword.get(space_args, :propagators)

    space_data = %Space{
      variables: variables,
      propagators: propagators,
      propagator_threads: create_propagator_threads(propagators),
      constraint_store: create_constraint_store(variables)
    }

    {:ok, :start_propagation, space_data, [{:next_event, :internal, :propagate}]}
  end

  @impl true
  def callback_mode() do
    [:state_functions, :state_enter]
  end

  defp create_constraint_store(variables) do
    :todo
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

  defp start_propagation(space_data) do
    Logger.debug("Start propagation")
  end
end
