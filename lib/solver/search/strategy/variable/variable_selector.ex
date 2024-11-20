defmodule CPSolver.Search.VariableSelector do
  @callback initialize(map()) :: :ok
  @callback update(map(), Keyword.t()) :: :ok
  @callback select_variable([Variable.t()]) :: Variable.t() | nil
  @callback select_variable([Variable.t()], any()) :: Variable.t() | nil
  @optional_callbacks select_variable: 1, select_variable: 2

  alias CPSolver.Variable.Interface

  alias CPSolver.Search.VariableSelector.{
    FirstFail,
    MostConstrained,
    MostCompleted,
    DomDeg,
    MaxRegret,
    AFC,
    Action,
    CHB
  }

  defmacro __using__(_) do
    quote do
      alias CPSolver.Search.VariableSelector
      alias CPSolver.Variable.Interface
      alias CPSolver.DefaultDomain, as: Domain

      @behaviour VariableSelector
      def initialize(_data) do
        :ok
      end

      def update(_data, _opts) do
        :ok
      end

      defoverridable initialize: 1, update: 2
    end
  end

  def initialize(%{selector: selector, init: init_fun}, space_data)
      when is_function(init_fun, 1) do
    init_fun.(space_data)
    selector
  end

  def initialize(selector, _space_data) do
    selector
  end

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

  def all_vars_fixed_exception() do
    :all_vars_fixed
  end

  def failed_variables_in_search_exception() do
    :failed_variables_in_search
  end

  defp execute_variable_choice(variable_choice, unfixed_vars, _data)
       when is_function(variable_choice, 1) do
    variable_choice.(unfixed_vars)
  end

  defp execute_variable_choice(variable_choice, unfixed_vars, data)
       when is_function(variable_choice, 2) do
    variable_choice.(unfixed_vars, data)
  end

  ######################################
  ## Variable choice (shortcuts)      ##
  ######################################
  def strategy({afc_mode, decay})
      when afc_mode in [:afc_min, :afc_max, :afc_size_min, :afc_size_max] do
    afc({afc_mode, decay}, &Enum.random/1)
  end

  def strategy({action_mode, decay})
      when action_mode in [:action_min, :action_max, :action_size_min, :action_size_max] do
    action({action_mode, decay}, &Enum.random/1)
  end

  def strategy(chb_mode)
      when chb_mode in [:chb_min, :chb_max, :chb_size_min, :chb_size_max] do
    chb(chb_mode, &Enum.random/1)
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

  ###################################
  ## Implementations (top-level)   ##
  ###################################

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
    make_strategy_object(
      variable_choice(
        fn vars, data ->
          AFC.select(vars, data, afc_mode)
        end,
        break_even_fun
      ),
      fn data -> AFC.initialize(data, decay) end
    )
  end

  def action({action_mode, decay}, break_even_fun \\ FirstFail)
      when action_mode in [:action_min, :action_max, :action_size_min, :action_size_max] do
    make_strategy_object(
      variable_choice(
        fn vars, data ->
          Action.select(vars, data, action_mode)
        end,
        break_even_fun
      ),
      fn data -> Action.initialize(data, decay) end
    )
  end

  def chb(chb_mode, break_even_fun \\ FirstFail)
      when chb_mode in [:chb_min, :chb_max, :chb_size_min, :chb_size_max] do
    make_strategy_object(
      variable_choice(
        fn vars, data ->
          CHB.select(vars, data, chb_mode)
        end,
        break_even_fun
      ),
      fn data -> CHB.initialize(data) end
    )
  end

  defp strategy_normalized(strategy) when is_atom(strategy) do
    strategy(strategy)
  end

  defp strategy_normalized(strategy) when is_function(strategy) do
    strategy
  end

  defp strategy_normalized(%{selector: selection}) do
    selection
  end

  def mixed(strategies) do
    Enum.random(strategies)
    |> strategy_normalized()
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

  defp make_strategy_object(selector, initialization) do
    %{selector: selector, init: initialization}
  end
end
