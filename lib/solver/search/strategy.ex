defmodule CPSolver.Search.Strategy do
  alias CPSolver.Variable.Interface

  alias CPSolver.Search.VariableSelector.{
    FirstFail,
    MostConstrained,
    MostCompleted,
    DomDeg,
    MaxRegret
  }

  alias CPSolver.DefaultDomain, as: Domain

  alias CPSolver.Search.ValueSelector.{Min, Max, Random}

  require Logger

  def default_strategy() do
    {
      :first_fail,
      :indomain_min
    }
  end

  def shortcut(:first_fail) do
    &FirstFail.select_variable/1
  end

  def shortcut(:input_order) do
    fn variables ->
      Enum.sort_by(variables, fn %{index: idx} -> idx end)
      |> List.first()
    end
  end

  def shortcut(:most_constrained) do
    &MostConstrained.select_variable/2
  end

  def shortcut(:most_completed) do
    &MostCompleted.select_variable/2
  end

  def shortcut(:dom_deg) do
    &DomDeg.select_variable/2
  end

  def shortcut(:indomain_min) do
    Min
  end

  def shortcut(:indomain_max) do
    Max
  end

  def shortcut(:indomain_random) do
    Random
  end

  def shortcut(:max_regret) do
    &MaxRegret.select_variable/2
  end

  def break_even(strategy_impl, break_even_fun) when is_function(break_even_fun, 1) do
    break_even(strategy_impl, fn vars, _data -> break_even_fun.(vars) end)
  end

  def break_even(strategy_impl, break_even_fun) when is_function(break_even_fun, 2) do
    fn vars, data ->
      vars
      |> strategy_impl.candidates(data)
      |> break_even_fun.(data)
    end
  end

  defp strategy_fun(strategy) when is_atom(strategy) do
    shortcut(strategy)
  end

  defp strategy_fun(strategy) when is_function(strategy) do
    strategy
  end

  def mixed(strategies) do
    Enum.random(strategies)
    |> strategy_fun()
  end

  def most_constrained(break_even_fun \\ &Enum.random/1)

  def most_constrained(break_even_fun) when is_function(break_even_fun) do
    break_even(MostConstrained, break_even_fun)
  end

  def most_constrained(shortcut) when is_atom(shortcut) do
    most_constrained(shortcut(shortcut))
  end

  def most_completed(break_even_fun \\ &Enum.random/1)

  def most_completed(break_even_fun) when is_function(break_even_fun) do
    break_even(MostCompleted, break_even_fun)
  end

  def most_completed(shortcut) when is_atom(shortcut) do
    most_completed(shortcut(shortcut))
  end

  def max_regret(break_even_fun \\ &Enum.random/1)

  def max_regret(break_even_fun) when is_function(break_even_fun) do
    break_even(MaxRegret, break_even_fun)
  end

  def max_regret(shortcut) when is_atom(shortcut) do
    max_regret(shortcut(shortcut))
  end

  def first_fail(break_even_fun \\ &Enum.random/1)

  def first_fail(break_even_fun) when is_function(break_even_fun) do
    break_even(FirstFail, break_even_fun)
  end

  def first_fail(shortcut) when is_atom(shortcut) do
    first_fail(shortcut(shortcut))
  end

  def dom_deg(break_even_fun \\ &Enum.random/1)

  def dom_deg(break_even_fun) when is_function(break_even_fun) do
    break_even(DomDeg, break_even_fun)
  end

  def dom_deg(shortcut) when is_atom(shortcut) do
    dom_deg(shortcut(shortcut))
  end

  def select_variable(variables, variable_choice) when is_atom(variable_choice) do
    select_variable(variables, shortcut(variable_choice))
  end

  def select_variable(variables, variable_choice) when is_function(variable_choice) do
    variables
    |> Enum.reject(fn v -> Interface.fixed?(v) end)
    |> then(fn
      [] -> throw(all_vars_fixed_exception())
      unfixed_vars -> variable_choice.(unfixed_vars)
    end)
  end

  defp partition_impl(variable, value_choice) when is_atom(value_choice) do
    shortcut(value_choice).select_value(variable)
  end

  defp partition_impl(variable, value_choice) when is_function(value_choice) do
    value_choice.(variable)
  end

  def branch(variables, {variable_choice, partition_strategy}) do
    branch(variables, variable_choice, partition_strategy, %{})
  end

  def branch(variables, {variable_choice, partition_strategy}, data) do
    branch(variables, variable_choice, partition_strategy, data)
  end

  def branch(variables, variable_choice, partition_strategy, data \\ %{})

  def branch(variables, variable_choice, partition_strategy, data)
      when is_atom(variable_choice) do
    branch(variables, shortcut(variable_choice), partition_strategy, data)
  end

  def branch(variables, variable_choice, partition_strategy, data)
      when is_function(variable_choice, 2) do
    variable_choice_arity1 = fn variables -> variable_choice.(variables, data) end
    branch(variables, variable_choice_arity1, partition_strategy, data)
  end

  def branch(variables, variable_choice, partition_strategy, _data)
      when is_function(variable_choice, 1) do
    case select_variable(variables, variable_choice) do
      nil ->
        []

      selected_variable ->
        {:ok, domain_partitions} =
          partition(selected_variable, partition_strategy)

        variable_partitions(selected_variable, domain_partitions, variables)
    end
  end

  def partition(variable, value_choice) do
    variable
    |> partition_impl(value_choice)
    |> split_domain_by(variable)
  end

  def all_vars_fixed_exception() do
    :all_vars_fixed
  end

  def failed_variables_in_search_exception() do
    :failed_variables_in_search
  end

  defp set_domain(variable, domain) do
    Map.put(variable, :domain, domain)
  end

  defp variable_partitions(selected_variable, domain_partitions, variables) do
    Enum.map(domain_partitions, fn {domain, constraint} ->
      {Enum.map(variables, fn var ->
         domain_copy =
           ((var.id == selected_variable.id && domain) || var.domain)
           # var.domain
           |> Domain.copy()

         set_domain(var, domain_copy)
       end), constraint}
    end)
  end

  defp split_domain_by(value, variable) do
    domain = Interface.domain(variable)

    try do
      {remove_changes, _domain} = Domain.remove(domain, value)

      {:ok,
       [
         {
           Domain.new(value),
           %{variable.id => :fixed}
           # Equal.new(variable, value)
         },
         {
           domain,
           %{variable.id => remove_changes}
           # NotEqual.new(variable, value)
         }
       ]}
    rescue
      :fail ->
        Logger.error(
          "Failure on partitioning with value #{inspect(value)}, domain: #{inspect(CPSolver.BitVectorDomain.raw(domain))}"
        )

        throw(:fail)
    end
  end
end
