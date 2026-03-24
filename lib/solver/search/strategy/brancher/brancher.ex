defmodule CPSolver.Search.Brancher do
  @callback branch(Variable.t(), any()) :: [any()]
  @callback initialize(map()) :: :ok

  defmacro __using__(_) do
    quote do
      alias CPSolver.Search
      alias CPSolver.Search.Brancher

      @behaviour Brancher
      def initialize(data) do
        :ok
      end

      def branch(variables, data) do
          Search.variable_value_choice(variables, :first_fail, :indomain_min, data)
      end

      defoverridable initialize: 1, branch: 2
    end
  end

end

defmodule CPSolver.Search.DefaultBrancher do
  use CPSolver.Search.Brancher
end
