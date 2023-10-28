defmodule CPSolverTest.Space do
  use ExUnit.Case

  describe "Computation space" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Space, as: Space
    alias CPSolver.Propagator.NotEqual
    alias CPSolver.Shared

    test "create space" do
      x_values = 1..10
      y_values = -5..5
      z_values = 0..2
      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [NotEqual.new(x, y), NotEqual.new(y, z)]

      {:ok, space} = Space.create(variables, propagators)
      # Process.sleep(1)

      {state, %{variables: space_variables, propagator_threads: threads} = _data} =
        Space.get_state_and_data(space)

      assert state == :propagating

      assert length(propagators) == map_size(threads)
      assert length(variables) == length(space_variables)

      thread_pids =
        Enum.map(threads, fn {_id, thread} -> thread.thread end)

      assert Enum.all?(thread_pids, fn pid -> is_pid(pid) end)
    end

    test "stable space" do
      %{space: space} = create_stable_space(solution_handler: test_solution_handler())

      Process.sleep(100)

      refute Process.alive?(space)

      solutions =
        Enum.map(1..2, fn _ ->
          receive do
            {:solution, sol} -> sol
          end
        end)

      # For all solutions, constraints (x != y and y != z) are satisfied.
      assert Enum.all?(solutions, fn variables ->
               [x, y, z] = Enum.map(variables, fn {_id, value} -> value end)
               x != y && y != z
             end)
    end

    test "solved space" do
      %{space: space} = create_solved_space()
      Process.sleep(10)
      {state, %{variables: space_variables} = _data} = Space.get_state_and_data(space)
      assert state == :solved
      ## Check if all space variables are fixed
      assert Enum.all?(space_variables, fn var -> Variable.fixed?(var) end)
    end

    test "failing space" do
      x_values = 1..1
      y_values = 1..2
      z_values = 2..2

      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [NotEqual.new(x, y), NotEqual.new(y, z)]

      Process.flag(:trap_exit, true)
      {:ok, space} = Space.create(variables, propagators)
      Process.sleep(50)
      refute Process.alive?(space)
    end

    test "solution handler as function" do
      solution_handler = test_solution_handler()
      ## Create a space with the solution handler as a function
      %{variables: space_variables} =
        create_solved_space(solution_handler: solution_handler)

      Process.sleep(10)
      ## Check the solution against the store
      store_vars =
        Map.new(space_variables, fn v -> {v.id, Variable.min(v)} end)

      # |> Enum.sort_by(fn {var, _value} -> var end)

      assert_receive {:solution, ^store_vars}, 10
    end

    test "solution handler as a module" do
      solution_handler = test_solution_handler()

      ## Create a space with the solution handler as a function
      %{variables: space_variables} =
        create_solved_space(solution_handler: solution_handler)

      Process.sleep(10)
      ## Check the solution against the store
      store_vars =
        Enum.map(space_variables, fn v -> {v.id, Variable.min(v)} end)
        |> Map.new()

      assert_receive {:solution, ^store_vars}, 10
    end

    defp create_solved_space(space_opts \\ []) do
      x_values = 1..2
      y_values = 1..1
      z_values = 1..2

      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [NotEqual.new(x, y), NotEqual.new(y, z)]

      {:ok, space} =
        Space.create(
          variables,
          propagators,
          space_opts
          |> Keyword.put(:solver_data, Shared.init_shared_data())
          |> Keyword.put(:keep_alive, true)
        )

      {_, space_data} = :sys.get_state(space)
      %{space: space, propagators: propagators, variables: space_data.variables}
    end

    defp create_stable_space(space_opts \\ []) do
      x_values = 1..2
      y_values = 1..2
      z_values = 1..2
      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [NotEqual.new(x, y), NotEqual.new(y, z)]

      {:ok, space} =
        Space.create(
          variables,
          propagators,
          space_opts
          |> Keyword.put(:solver_data, Shared.init_shared_data(self()))
        )

      {_, space_data} = :sys.get_state(space)

      %{space: space, propagators: propagators, variables: space_data.variables, domains: values}
    end

    defp test_solution_handler() do
      target_pid = self()

      ## The solution will be send to the current process
      fn solution ->
        send(target_pid, {:solution, solution})
      end
    end
  end
end
