defmodule CPSolver.Utils do
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain
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
            copy = [Map.put(v, :domain, Domain.copy(d)) | new_vars]
            {:cont, {copy, (Domain.fixed?(d) && fixed?) || false}}
        end
      end
    )
    |> then(fn {vars, res} -> {Enum.reverse(vars), res} end)
  end

  def on_primary_node?(arg) when is_reference(arg) or is_pid(arg) or is_port(arg) do
    Node.self() == node(arg)
  end
end
