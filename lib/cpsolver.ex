defmodule CPSolver do
  @moduledoc """
  Solver API.
  """

  use GenServer

  @doc """

  """
  @spec solve(module(), module(), Keyword.t()) :: any()
  def solve(model, search, opts \\ []) do
    solver = make_solver(opts)
    post_model(solver, model)
    do_solve(solver, search)
  end

  def make_solver(opts \\ []) do
    {:ok, solver} = GenServer.start_link(CPSolver, opts)
  end

  defp post_model(solver, model) do
    for constraint <- model.constraints do
      post(solver, constraint)
    end
  end

  defp do_solve(solver, search) do
    :todo
  end

  ## Constraint is a {ConstraintImpl, arg1, arg2, ...} tuple
  ## We run post() on the constraints and then store a propagator
  ## fn -> ConstraintImpl.propagate(arg1, arg2, ....) end
  ## Propagators will be called by fixpoint algorithm.
  ##
  def post(solver, constraint) do
    [impl_mod | args] = Tuple.to_list(constraint)
    apply(impl_mod, :post, args)
    propagator = fn -> apply(impl_mod, :propagate, args) end
    add_propagator(solver, propagator)
  end

  def add_propagator(solver, propagator) do
    GenServer.cast(solver, {:add_propagator, propagator})
  end

  def get_propagators(solver) do
    GenServer.call(solver, :get_propagators)
  end

  ## GenServer callbacks

  @impl true
  def init(solver_opts) do
    {:ok, %{propagators: [], variables: [], solver_opts: solver_opts}}
  end

  @impl true
  def handle_call(:get_propagators, _from, state) do
    {:reply, Map.get(state, :propagators), state}
  end

  @impl true
  def handle_cast({:add_propagator, propagator}, state) do
    {:noreply, Map.update(state, :propagators, [], fn plist -> [propagator | plist] end)}
  end
end
