defmodule CPSolver.Search.VariableSelector do
  @callback initialize(map(), any()) :: :ok
  @callback update(map(), Keyword.t()) :: :ok
  @callback select(map(), Keyword.t()) :: Variable.t() | nil
  @callback select([Variable.t()], map(), Keyword.t()) :: Variable.t() | nil

  alias CPSolver.Search.VariableSelector.{
    FirstFail,
    InputOrder,
    MostConstrained,
    MostCompleted,
    DomDeg,
    MaxRegret,
    AFC,
    Action,
    CHB
  }

  alias CPSolver.Variable.UnfixedTracker, as: Tracker

  defmacro __using__(_) do
    quote do
      alias CPSolver.Search.VariableSelector
      alias CPSolver.Variable.Interface
      alias CPSolver.DefaultDomain, as: Domain

      @behaviour VariableSelector
      def initialize(_data, _opts) do
        :ok
      end

      def update(_data, _opts) do
        :ok
      end

      def select(%{unfixed_variables_tracker: tracker, variables: variables} = data, opts) do
        tracker
        |> Tracker.iterate_unfixed(variables)
        |> then(fn
          [] -> VariableSelector.all_vars_fixed_exception()
          unfixed_vars -> select(unfixed_vars, data, opts)
        end)
      end

      defoverridable initialize: 2, update: 2, select: 2
    end
  end

  def initialize(selector, _space_data) do
    selector
  end

  def select_variable(data, variable_choice) when is_atom(variable_choice) do
    select_variable(data, strategy(variable_choice))
  end

  def select_variable(
        data,
        variable_choice
      )
      when is_function(variable_choice) do
        normalize_choice_fun(variable_choice).(data)
  end

  def all_vars_fixed_exception() do
    throw(:all_vars_fixed)
  end

  def failed_variables_in_search_exception() do
    :failed_variables_in_search
  end

  defp normalize_choice_fun(variable_choice)
       when is_function(variable_choice, 1) do
    fn data -> variable_choice.(data) end
  end

  defp normalize_choice_fun(variable_choice)
       when is_function(variable_choice, 2) do
    variable_choice
  end

  ######################################
  ## Variable choice (shortcuts)      ##
  ######################################
  defp strategy({afc_mode, decay})
       when afc_mode in [:afc_min, :afc_max, :afc_size_min, :afc_size_max] do
    afc({afc_mode, decay}, &Enum.random/1)
  end

  defp strategy({action_mode, decay})
       when action_mode in [:action_min, :action_max, :action_size_min, :action_size_max] do
    action({action_mode, decay}, &Enum.random/1)
  end

  defp strategy(chb_mode)
       when chb_mode in [:chb_min, :chb_max, :chb_size_min, :chb_size_max] do
    chb(chb_mode, &Enum.random/1)
  end

  defp strategy(:first_fail) do
    first_fail(&List.first/1)
  end

  defp strategy(:input_order) do
    input_order()
  end

  defp strategy(:most_constrained) do
    most_constrained(&Enum.random/1)
  end

  defp strategy(:most_completed) do
    most_completed(&Enum.random/1)
  end

  defp strategy(:dom_deg) do
    dom_deg(&Enum.random/1)
  end

  defp strategy(:max_regret) do
    max_regret(&Enum.random/1)
  end

  defp strategy(impl) when is_atom(impl) do
    if Code.ensure_loaded(impl) == {:module, impl} && function_exported?(impl, :select, 3) do
      impl
    else
      throw({:unknown_strategy, impl})
    end
  end

  ###################################
  ## Implementations (top-level)   ##
  ###################################

  def most_constrained(break_even_fun \\ &Enum.random/1)

  def most_constrained(break_even_fun) when is_function(break_even_fun) do
    variable_choice(MostConstrained, break_even_fun)
  end

  def most_completed(break_even_fun \\ &Enum.random/1)

  def most_completed(break_even_fun) do
    variable_choice(MostCompleted, extract_strategy(break_even_fun))
  end

  def max_regret(break_even_fun \\ &Enum.random/1)

  def max_regret(break_even_fun) when is_function(break_even_fun) do
    variable_choice(MaxRegret, break_even_fun)
  end

  def first_fail(break_even_fun \\ &Enum.random/1)

  def first_fail(break_even_fun) when is_function(break_even_fun) do
    variable_choice(FirstFail, break_even_fun)
  end

  def input_order() do
    variable_choice(InputOrder, nil)
  end

  def dom_deg(break_even_fun \\ &Enum.random/1)

  def dom_deg(break_even_fun) when is_function(break_even_fun) do
    variable_choice(DomDeg, break_even_fun)
  end

  def afc({afc_mode, decay}, break_even_fun \\ FirstFail)
      when afc_mode in [:afc_min, :afc_max, :afc_size_min, :afc_size_max] do
    variable_choice({AFC, mode: afc_mode, decay: decay}, break_even_fun)
  end

  def action({action_mode, decay}, break_even_fun \\ FirstFail)
      when action_mode in [:action_min, :action_max, :action_size_min, :action_size_max] do
    variable_choice({Action, mode: action_mode, decay: decay}, break_even_fun)
  end

  def chb(chb_mode, break_even_fun \\ FirstFail)

  def chb({chb_mode, q_score}, break_even_fun)
      when chb_mode in [:chb_min, :chb_max, :chb_size_min, :chb_size_max] do
    variable_choice(
      {CHB, mode: chb_mode, q_score: q_score},
      break_even_fun
    )
  end

  def chb(chb_mode, break_even_fun) do
    chb({chb_mode, CHB.default_q_score()}, break_even_fun)
  end

  defp extract_strategy(shortcut) when is_atom(shortcut) do
    strategy(shortcut)
  end

  defp extract_strategy(strategy) when is_function(strategy) do
    strategy
  end

  def mixed(strategies) do
    Enum.random(strategies)
    |> extract_strategy()
  end

  defp execute_break_even(selection, _data, nil) do
    selection
  end

  defp execute_break_even(selection, _data, break_even_fun) when is_function(break_even_fun, 1) do
    break_even_fun.(selection)
  end

  defp execute_break_even(selection, data, break_even_fun) when is_function(break_even_fun, 2) do
    break_even_fun.(selection, data)
  end

  defp variable_choice(strategy_fun, break_even_fun) when is_function(strategy_fun) do
    fn data ->
      data
      |> strategy_fun.()
      |> execute_break_even(data, break_even_fun)
    end
  end

  defp variable_choice({strategy_impl, args}, break_even_fun) when is_atom(strategy_impl) do
    impl = strategy(strategy_impl)

    initialize? = function_exported?(impl, :initialize, 2)

    strategy_fun = fn data ->
      args = args || []
      initialize? && impl.initialize(data, args)
      impl.select(data, args)
    end

    variable_choice(strategy_fun, break_even_fun)
  end

  defp variable_choice(strategy_impl, break_even_fun) when is_atom(strategy_impl) do
    variable_choice({strategy_impl, nil}, break_even_fun)
  end
end
