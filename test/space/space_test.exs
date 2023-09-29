defmodule CPSolverTest.Space do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import CPSolver.Test.Helpers

  describe "Computation space" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Space, as: Space
    alias CPSolver.Propagator.NotEqual
    alias CPSolver.Solution

    setup do
      Logger.configure(level: :debug)
      on_exit(fn -> Logger.configure(level: :error) end)
    end

    test "create space" do
      x_values = 1..10
      y_values = -5..5
      z_values = 0..2
      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

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
      %{space: space} = create_stable_space()

      Process.sleep(100)

      refute Process.alive?(space)

      solutions =
        Enum.map(1..2, fn _ ->
          receive do
            {:solution, sol} -> sol
          end
        end)

      node_creations =
        Enum.reduce(1..1, 0, fn _, acc ->
          receive do
            {:nodes, nodes} -> length(nodes) + acc
          end
        end)

      # For all solutions, constraints (x != y and y != z) are satisfied.
      assert Enum.all?(solutions, fn variables ->
               [x, y, z] = Enum.map(variables, fn {_id, value} -> value end)
               x != y && y != z
             end)

      assert node_creations == 2
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
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

      {:ok, space} = Space.create(variables, propagators)
      Process.sleep(10)
      refute Process.alive?(space)
    end

    test "solution handler as function" do
      target_pid = self()

      ## The solution will be send to the current process
      solution_handler = fn solution ->
        send(target_pid, Enum.sort_by(solution, fn {var, _value} -> var end))
      end

      ## Create a space with the solution handler as a function
      %{variables: space_variables} =
        create_solved_space(solution_handler: solution_handler)

      Process.sleep(10)
      ## Check the solution against the store
      store_vars =
        Enum.map(space_variables, fn v -> {v.id, Variable.min(v)} end)
        |> Enum.sort_by(fn {var, _value} -> var end)

      assert_receive ^store_vars, 10
    end

    test "solution handler as a module" do
      solution_handler = Solution.default_handler()

      ## Create a space with the solution handler as a function
      log =
        capture_log([level: :debug], fn ->
          _ = create_solved_space(solution_handler: solution_handler)

          Process.sleep(10)
        end)

      assert log =~ "Solution found"
      assert number_of_occurences(log, "<- 2") == 2
      assert number_of_occurences(log, "<- 1") == 1
    end

    test "distribute space" do
      %{space: _space} = create_stable_space()
      Process.sleep(10)
      :to_complete
    end

    defp create_solved_space(space_opts \\ []) do
      x_values = 1..2
      y_values = 1..1
      z_values = 1..2

      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

      {:ok, space} =
        Space.create(variables, propagators, Keyword.put(space_opts, :keep_alive, true))

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
