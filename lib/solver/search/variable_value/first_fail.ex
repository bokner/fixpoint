defmodule CPSolver.Search.VariableSelector.FirstFail do
  @behaviour CPSolver.Search.VariableSelector
  alias CPSolver.Variable.Interface

  @impl true
  def select_variable(variables, break_even_fun \\ &List.first/1) do
    get_minimals(variables)
    |> break_even_fun.()
  end

  def candidates(variables, _data) do
    get_minimals(variables)
  end

  def get_minimals(variables) do
    List.foldr(variables, {[], nil}, fn var, {vars, current_min} = acc ->
      domain_size = Interface.size(var)
      cond do
        is_nil(current_min) || domain_size < current_min -> {[var], domain_size}
        domain_size > current_min -> acc
        domain_size == current_min -> {[var | vars], domain_size}
      end
    end)
    |> elem(0)
  end



end
