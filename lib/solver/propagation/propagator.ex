defmodule CPSolver.Propagator do
  alias CPSolver.Store.Registry, as: Store
  alias CPSolver.Variable
  alias CPSolver.Common

  require Logger

  @callback filter(variables :: list()) :: map() | :stable | :failure
  @callback variables(args :: list()) :: list()

  @domain_changes Common.domain_changes()

  defmacro __using__(_) do
    quote do
      @behaviour CPSolver.Propagator
      def variables(args) do
        args
      end

      defoverridable variables: 1
    end
  end

  @behaviour GenServer

  ## Create a propagator thread; 'propagator' is a tuple {propagator_mod, args} where propagator_mod
  ## is an implementation of CPSolver.Propagator
  ##
  ## Propagator thread is a process that handles life cycle of a propagator.
  ## TODO: details to follow.
  def create_thread(space, {propagator_mod, propagator_args} = _propagator, opts \\ [])
      when is_atom(propagator_mod) do
    {:ok, _thread} =
      GenServer.start_link(__MODULE__, [space, propagator_mod, propagator_args, opts])
  end

  ## Subscribe propagator thread to variables' events
  defp subscribe_to_variables(thread, variables) do
    Enum.each(variables, fn var -> subscribe_to_var(thread, var) end)
  end

  defp subscribe_to_var(thread, variable) do
    :ebus.sub(thread, Variable.topic(variable))
  end

  ## GenServer callbacks
  @impl true
  def init([space, propagator_mod, args, opts]) do
    bound_vars = Variable.bind_variables(space, propagator_mod.variables(args))
    subscribe_to_variables(self(), bound_vars)

    {:ok,
     %{
       space: space,
       propagator_impl: propagator_mod,
       args: args,
       unfixed_variables:
         Enum.reduce(bound_vars, MapSet.new(), fn var, acc ->
           (Store.get(space, var, :fixed?) && acc) || MapSet.put(acc, var.id)
         end),
       propagator_opts: opts,
       filter_fun: fn -> propagator_mod.filter(args) end
     }
     |> tap(fn data -> filter(data) end)}
  end

  @impl true

  def handle_info({:no_change, var}, data) do
    Logger.debug("Propagator: no change for #{inspect(var)}")
    {:noreply, maybe_stable(var, data)}
  end

  def handle_info({domain_change, var}, data) when domain_change in @domain_changes do
    Logger.debug("Propagator: #{inspect(domain_change)} for #{inspect(var)}")
    filter(data)
    {:noreply, maybe_entail(domain_change, var, data)}
  end

  ### end of GenServer callbacks

  defp filter(%{filter_fun: filter_fun} = _data) do
    filter_fun.()
  end

  defp maybe_entail(:fixed, var, %{unfixed_variables: unfixed} = data) do
    unfixed
    |> MapSet.delete(var)
    |> then(fn new_unfixed ->
      if MapSet.size(new_unfixed) == 0 do
        Logger.debug("Propagator is entailed")
      end

      %{data | unfixed_variables: new_unfixed}
    end)
  end

  defp maybe_entail(_domain_change, _var, data) do
    data
  end

  defp maybe_stable(var, data) do
    :todo
    data
  end
end
