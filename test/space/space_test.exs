defmodule CPSolverTest.Space do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import CPSolver.Test.Helpers

  describe "Computation space" do
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Space, as: Space
    alias CPSolver.Propagator.NotEqual
    alias CPSolver.Solution

    alias CPSolver.Utils

    test "create space" do
      x_values = 1..10
      y_values = -5..5
      z_values = 0..2
      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

      {:ok, space} = Space.create(variables, propagators)
      # Process.sleep(1)

      {state,
       %{variables: space_variables, propagator_threads: threads} =
         _data} = Space.get_state_and_data(space)

      assert state == :propagating

      assert length(propagators) == map_size(threads)
      assert length(variables) == length(space_variables)

      thread_pids =
        [x_y_propagator_pid, y_z_propagator_pid] =
        Enum.map(threads, fn {_id, thread} -> thread.thread end)

      assert Enum.all?(thread_pids, fn pid -> is_pid(pid) end)
      # Check subscriptions

      ## propagators -> variables
      [x_space, y_space, z_space] = space_variables
      assert x_y_propagator_pid in CPSolver.Variable.subscribers(x_space)
      assert x_y_propagator_pid in CPSolver.Variable.subscribers(y_space)
      assert y_z_propagator_pid in CPSolver.Variable.subscribers(y_space)
      assert y_z_propagator_pid in CPSolver.Variable.subscribers(z_space)
      ## space -> propagators
      assert Enum.all?(threads, fn {thread_id, _thread} ->
               space in Utils.subscribers(thread_id)
             end)
    end

    test "stable space" do
      target_pid = self()

      solution_handler = fn solution ->
        send(target_pid, Enum.sort_by(solution, fn {var, _value} -> var end))
      end

      %{space: space, variables: space_variables} =
        create_stable_space(
          # solution_handler: solution_handler
        )

      Process.sleep(100)

      {state, _data} = Space.get_state_and_data(space)
      assert state == :stable

      solutions =
        Enum.map(1..2, fn _ ->
          receive do
            {:solution, sol} -> sol
          end
        end)

      # Only 2 solutions, nothing else has come in the mailbox
      refute_receive _msg, 100

      # For all solutions, constraints (x != y and y != z) are satisfied.
      assert Enum.all?(solutions, fn variables ->
               [x, y, z] = Enum.map(variables, fn {_id, value} -> value end)
               x != y && y != z
             end)
    end

    test "solved space" do
      %{space: space} = create_solved_space()
      {state, _data} = Space.get_state_and_data(space)
      assert state == :propagating

      Process.sleep(10)
      {state, %{variables: space_variables} = _data} = Space.get_state_and_data(space)
      assert state == :solved
      ## Check if all space variables are fixed
      assert Enum.all?(space_variables, fn var -> Store.get(space, var, :fixed?) end)
    end

    test "failing space" do
      x_values = 1..1
      y_values = 1..2
      z_values = 2..2

      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

      {:ok, space} = Space.create(variables, propagators)
      Process.sleep(10)
      {state, _data} = Space.get_state_and_data(space)
      assert state == :failed
    end

    test "solution handler as function" do
      target_pid = self()

      ## The solution will be send to the current process
      solution_handler = fn solution ->
        send(target_pid, Enum.sort_by(solution, fn {var, _value} -> var end))
      end

      ## Create a space with the solution handler as a function
      %{space: space, variables: space_variables} =
        create_solved_space(solution_handler: solution_handler)

      Process.sleep(10)
      ## Check the solution against the store
      store_vars =
        Enum.map(space_variables, fn v -> {v.id, Store.get(space, v, :min)} end)
        |> Enum.sort_by(fn {var, _value} -> var end)

      assert_receive ^store_vars, 10
    end

    test "solution handler as a module" do
      solution_handler = Solution.default_handler()

      ## Create a space with the solution handler as a function
      log =
        capture_log(fn ->
          _ = create_solved_space(solution_handler: solution_handler)

          Process.sleep(10)
        end)

      assert log =~ "Solution found"
      assert number_of_occurences(log, "<- 2") == 2
      assert number_of_occurences(log, "<- 1") == 1
    end

    test "distribute space" do
      %{space: space, variables: variables} = create_stable_space()
      Process.sleep(100)
      {_state, data} = Space.get_state_and_data(space)
      assert length(data.children) == 2
      [child1, child2] = data.children
    end

    defp create_solved_space(space_opts \\ []) do
      x_values = 1..2
      y_values = 1..1
      z_values = 1..2

      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

      {:ok, space} = Space.create(variables, propagators, space_opts)
      %{space: space, propagators: propagators, variables: variables}
    end

    defp create_stable_space(space_opts \\ []) do
      x_values = 1..2
      y_values = 1..2
      z_values = 1..2
      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

      {:ok, space} = Space.create(variables, propagators, space_opts)
      %{space: space, propagators: propagators, variables: variables, domains: values}
    end
  end
end
