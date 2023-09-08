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
      Enum.reduce_while(variables, initial_acc, fn var, {_v, v_size} = acc ->
        case Variable.size(var) do
          :fail -> {:halt, {:fail, nil}}
          ## Skip fixed vars
          1 -> {:cont, acc}
          s when s < v_size -> {:cont, {var, s}}
          _s -> {:cont, acc}
        end
      end)

    cond do
      choice == initial_acc ->
        {:error, Strategy.all_vars_fixed_exception()}

      min_var == :fail ->
        {:error, :fail}

      true ->
        {:ok, min_var}
    end
  end

  @impl true
  def partition(domain) do
    ## Choice of value doesn't matter for first_fail
    {:ok, DomainPartition.by_min(domain)}
  end
end
