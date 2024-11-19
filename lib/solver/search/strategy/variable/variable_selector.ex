defmodule CPSolver.Search.VariableSelector do
  @callback initialize(map()) :: :ok
  @callback update(map(), Keyword.t()) :: :ok
  @callback select_variable([Variable.t()]) :: Variable.t() | nil
  @callback select_variable([Variable.t()], any()) :: Variable.t() | nil
  @optional_callbacks select_variable: 1, select_variable: 2

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

  def initialize(variable_choice, space_data) do
    strategy(variable_choice).(space_data)
  end

  def select_variable(variables, variable_choice, data) do
    strategy(variable_choice).(variables, data)
  end

  
end
