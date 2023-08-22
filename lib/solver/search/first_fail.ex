defmodule CPSolver.Search.Strategy.FirstFail do
  alias CPSolver.Search.Strategy
  @behaviour Strategy
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.DefaultDomain, as: Domain

  @impl true
  @spec select_variable(any) :: any
  def select_variable(variables) do
    {min_domain_var, _size} =
      Enum.reduce(variables, {nil, :infinity}, fn var, {_v, v_size} = acc ->
        case Variable.size(var) do
          :fail -> throw(Strategy.failed_variables_in_search_exception())
          ## Skip fixed vars
          1 -> acc
          s when s < v_size -> {var, s}
          _s -> acc
        end
      end)

    (min_domain_var && min_domain_var) || throw(Strategy.no_variable_choice_exception())
  end

  @impl true
  def partition(domain) do
    ## Choice of value doesn't matter for first_fail
    min_val = Domain.min(domain)
    rest = Domain.remove(domain, min_val)
    [min_val, rest]
  end
end
