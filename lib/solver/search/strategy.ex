defmodule CPSolver.Search.Strategy do
  alias CPSolver.Variable.Interface

  alias CPSolver.Search.VariableSelector.{
    FirstFail,
    MostConstrained,
    MostCompleted,
    DomDeg,
    MaxRegret,
    AFC
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

  def initialize({variable_choice, value_choice} = _search, space_data) do
    {
      initialize_choice(variable_choice, space_data),
      initialize_choice(value_choice, space_data)
    }
  end

  defp initialize_choice(%{selector: selector, init: init_fun}, space_data) when is_function(init_fun, 1) do
    init_fun.(space_data)
    selector
  end

  defp initialize_choice(selector, _space_data) do
    selector
  end

  ###########################
  ## Variable choice       ##
  ###########################
  def strategy({afc_mode, decay}) when afc_mode in [:afc_min, :afc_max, :afc_size_min, :afc_size_max] do
    afc({afc_mode, decay}, &Enum.random/1)
  end

  def strategy(:first_fail) do
    first_fail(&List.first/1)
  end

  def strategy(:input_order) do
    fn variables ->
      Enum.sort_by(variables, fn %{index: idx} -> idx end)
      |> List.first()
    end
  end

  def strategy(:most_constrained) do
    most_constrained(&Enum.random/1)
  end

  def strategy(:most_completed) do
    most_completed(&Enum.random/1)
  end

  def strategy(:dom_deg) do
    dom_deg(&Enum.random/1)
  end

  def strategy(:max_regret) do
    max_regret(&Enum.random/1)
  end

  ###########################
  ## Value choice          ##
  ###########################
  def strategy(:indomain_min) do
    Min
  end

  def strategy(:indomain_max) do
    Max
  end

  def strategy(:indomain_random) do
    Random
  end

  defp execute_break_even(selection, _data, break_even_fun) when is_function(break_even_fun, 1) do
    break_even_fun.(selection)
  end

  defp execute_break_even(selection, data, break_even_fun) when is_function(break_even_fun, 2) do
    break_even_fun.(selection, data)
  end

  def variable_choice(strategy_impl, break_even_fun) when is_atom(strategy_impl) do
    strategy_fun = fn vars, data -> strategy_impl.select(vars, data) end
    variable_choice(strategy_fun, break_even_fun)
  end

  def variable_choice(strategy_fun, break_even_fun) when is_function(strategy_fun) do
    fn vars, data ->
      vars
      |> strategy_fun.(data)
      |> execute_break_even(data, break_even_fun)
    end
  end

  defp strategy_fun(strategy) when is_atom(strategy) do
    strategy(strategy)
  end

  defp strategy_fun(strategy) when is_function(strategy) do
    strategy
  end

  defp strategy_fun(%{selector: selection}) do
    selection
  end

  def mixed(strategies) do
    Enum.random(strategies)
    |> strategy_fun()
  end

  def most_constrained(break_even_fun \\ &Enum.random/1)

  def most_constrained(break_even_fun) when is_function(break_even_fun) do
    variable_choice(MostConstrained, break_even_fun)
  end

  def most_constrained(shortcut) when is_atom(shortcut) do
    strategy(shortcut)
  end

  def most_completed(break_even_fun \\ &Enum.random/1)

  def most_completed(break_even_fun) when is_function(break_even_fun) do
    variable_choice(MostCompleted, break_even_fun)
  end

  def most_completed(shortcut) when is_atom(shortcut) do
    strategy(shortcut)
  end

  def max_regret(break_even_fun \\ &Enum.random/1)

  def max_regret(break_even_fun) when is_function(break_even_fun) do
    variable_choice(MaxRegret, break_even_fun)
  end

  def max_regret(shortcut) when is_atom(shortcut) do
    strategy(shortcut)
  end

  def first_fail(break_even_fun \\ &Enum.random/1)

  def first_fail(break_even_fun) when is_function(break_even_fun) do
    variable_choice(FirstFail, break_even_fun)
  end

  def first_fail(shortcut) when is_atom(shortcut) do
    strategy(shortcut)
  end

  def dom_deg(break_even_fun \\ &Enum.random/1)

  def dom_deg(break_even_fun) when is_function(break_even_fun) do
    variable_choice(DomDeg, break_even_fun)
  end

  def dom_deg(shortcut) when is_atom(shortcut) do
    strategy(shortcut)
  end

  def afc({afc_mode, decay}, break_even_fun \\ FirstFail)
      when afc_mode in [:afc_min, :afc_max, :afc_size_min, :afc_size_max] do
    make_strategy_object(variable_choice(fn vars, data ->
      AFC.select(vars, data, afc_mode) end, break_even_fun),
      fn data -> AFC.initialize(data, decay) end)
    end
  ### Helpers
  def select_variable(variables, data, variable_choice) when is_atom(variable_choice) do
    select_variable(variables, data, strategy(variable_choice))
  end

  def select_variable(variables, data, variable_choice) when is_function(variable_choice) do
    variables
    |> Enum.reject(fn v -> Interface.fixed?(v) end)
    |> then(fn
      [] -> throw(all_vars_fixed_exception())
      unfixed_vars -> execute_variable_choice(variable_choice, unfixed_vars, data)
    end)
  end

  defp execute_variable_choice(variable_choice, unfixed_vars, _data)
       when is_function(variable_choice, 1) do
    variable_choice.(unfixed_vars)
  end

  defp execute_variable_choice(variable_choice, unfixed_vars, data)
       when is_function(variable_choice, 2) do
    variable_choice.(unfixed_vars, data)
  end

  defp partition_impl(variable, value_choice) when is_atom(value_choice) do
    strategy(value_choice).select_value(variable)
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
    branch(variables, strategy(variable_choice), partition_strategy, data)
  end

  def branch(variables, variable_choice, partition_strategy, data)
      when is_function(variable_choice, 2) do
    variable_choice_arity1 = fn variables -> variable_choice.(variables, data) end
    branch(variables, variable_choice_arity1, partition_strategy, data)
  end

  def branch(variables, variable_choice, partition_strategy, data)
      when is_function(variable_choice, 1) do
    case select_variable(variables, data, variable_choice) do
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

  defp make_strategy_object(selector, initialization) do
    %{selector: selector, init: initialization}
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
