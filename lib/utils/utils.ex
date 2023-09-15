defmodule CPSolver.Utils do
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain

  def publish(topic, message) do
    :ebus.pub(topic, message)
    :ok
  end

  def subscribe(pid, topic) when is_pid(pid) do
    :ebus.sub(pid, topic)
    :ok
  end

  def unsubscribe(pid, topic) when is_pid(pid) do
    :ebus.unsub(pid, topic)
    :ok
  end

  def subscribers(topic) do
    :ebus.subscribers(topic)
  end

  ## Reads and caches domains of variables.
  ## Returns tuple {cached_vars, :fail} if any of variables fails
  ## or {cached_vars, all_fixed?}
  @spec localize_variables([Variable.t()]) :: {[Variable.t()], :fail | boolean()}
  def localize_variables(variables) do
    Enum.reduce_while(
      variables,
      {[], true},
      fn v, {new_vars, fixed?} ->
        case Variable.domain(v) do
          :fail ->
            {:halt, {new_vars, :fail}}

          d ->
            copy = [Map.put(v, :domain, d) | new_vars]
            {:cont, {copy, (Domain.fixed?(d) && fixed?) || false}}
        end
      end
    )
    |> then(fn {vars, res} -> {Enum.reverse(vars), res} end)
  end
end
