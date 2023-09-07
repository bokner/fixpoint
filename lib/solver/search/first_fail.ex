defmodule CPSolver.Search.Strategy.FirstFail do
  alias CPSolver.Search.Strategy
  @behaviour Strategy
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Search.DomainPartition

  @impl true
  def select_variable(variables) do
    initial_acc = {nil, :infinity}

    {min_var, _size} =
      choice =
      Enum.reduce(variables, initial_acc, fn var, {_v, v_size} = acc ->
        case Variable.size(var) do
          :fail -> throw(Strategy.failed_variables_in_search_exception())
          ## Skip fixed vars
          1 -> acc
          s when s < v_size -> {var, s}
          _s -> acc
        end
      end)

    if choice == initial_acc do
      {:error, Strategy.all_vars_fixed_exception()}
    else
      {:ok, min_var}
    end
  end

  @impl true
  def partition(domain) do
    ## Choice of value doesn't matter for first_fail
    {:ok, DomainPartition.by_min(domain)}
  end
end
