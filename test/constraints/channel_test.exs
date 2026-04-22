defmodule CPSolverTest.Constraint.Channel do
  use ExUnit.Case, async: false

  alias CPSolver.BooleanVariable
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Channel

  describe "Channel constraint" do
    test "`channel` functionality" do
      num_bool_vars = 100
      {x_var, bool_vars} = make_variables(num_bool_vars)

      channel_constraint = Channel.new(x_var, bool_vars)

      model = Model.new([x_var | bool_vars], [channel_constraint])

      {:ok, result} = CPSolver.solve(model)
      assert Enum.all?(result.solutions, &check_solution/1)
      assert num_bool_vars == length(result.solutions)

      ## Fix x_var
      {x_var, bool_vars} = make_variables(num_bool_vars, [1])
      channel_constraint = Channel.new(x_var, bool_vars)

      model = Model.new([x_var | bool_vars], [channel_constraint])

      {:ok, result} = CPSolver.solve(model)
      assert Enum.all?(result.solutions, &check_solution/1)
      assert 1 = length(result.solutions)

      ## Only a single boolean variable is fixed to 1
      {x_var, bool_vars} = make_variables(num_bool_vars)
      b_var = Enum.random(bool_vars)

      Variable.fix(b_var, 1)

      channel_constraint = Channel.new(x_var, bool_vars)

      model = Model.new([x_var | bool_vars], [channel_constraint])

      {:ok, result} = CPSolver.solve(model)

      assert check_solution(hd(result.solutions))
      ## fixed boolean varibale implies a single solution
      assert 1 = length(result.solutions)

    end

    test "inconsistency and edge cases" do
      num_bool_vars = 10
      ##bool_vars = Enum.map(1..num_bool_vars, fn i -> BooleanVariable.new(name: "b#{i}") end)
      ## index variable (`x`) has the domain with no indices into bool_vars
      invalid_domain = [-1, 0, num_bool_vars + 1]
      ##x_var = Variable.new(invalid_domain, name: "x")
      {x_var, bool_vars} = make_variables(num_bool_vars, invalid_domain)
      channel_constraint = Channel.new(x_var, bool_vars)
      assert catch_throw({:fail, _} =  Model.new([x_var | bool_vars], [channel_constraint]))

      ## Some of the domain values are valid index values
      partial_domain  = [-1, 0, 1, 2, num_bool_vars + 1]
      {x_var, bool_vars} = make_variables(num_bool_vars, partial_domain)
      channel_constraint = Channel.new(x_var, bool_vars)
      model =  Model.new([x_var | bool_vars], [channel_constraint])
      {:ok, result} = CPSolver.solve(model)
      assert Enum.all?(result.solutions, &check_solution/1)
      ## there are 2 valid values (1 and 2) in the domain of x
      assert length(result.solutions) == 2

      ## There is more than one boolean variable fixed to 'true'
      ##
      {x_var, bool_vars} = make_variables(num_bool_vars)
      Enum.take_random(bool_vars, 2) |> Enum.each(fn b_var -> Variable.fix(b_var, 1) end)
      channel_constraint = Channel.new(x_var, bool_vars)
      assert catch_throw({:fail, _} =  Model.new([x_var | bool_vars], [channel_constraint]))
    end

    defp make_variables(num_bool_vars, x_domain \\ nil) do
      x_domain = x_domain || (1..num_bool_vars)
      bool_vars = Enum.map(1..num_bool_vars, fn i -> BooleanVariable.new(name: "b#{i}") end)
      x_var = Variable.new(x_domain, name: "x")
      {x_var, bool_vars}
    end

    defp check_solution([x | boolean_array] = _solution) do
      Enum.all?(1..length(boolean_array), fn idx ->
        b_val = Enum.at(boolean_array, idx - 1)
        if idx == x do
          b_val == 1
        else
          b_val == 0
        end
      end)
    end
  end
end
