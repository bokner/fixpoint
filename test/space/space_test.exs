defmodule CPSolverTest.Space do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import CPSolver.Test.Helpers

  describe "Computation space" do
    alias Mix.Utils
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Space, as: Space
    alias CPSolver.Propagator.NotEqual

    alias CPSolver.Utils

    test "create space" do
      x_values = 1..10
      y_values = -5..5
      z_values = 0..2
      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

      {:ok, space} = Space.create(variables, propagators)

      {state,
       %{propagators: space_propagators, variables: space_variables, propagator_threads: threads} =
         _data} =
        Space.get_state_and_data(space)

      assert state == :propagating
      assert length(propagators) == length(space_propagators)
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
      x_values = 1..10
      y_values = -5..5
      z_values = 0..2
      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

      {:ok, space} = Space.create(variables, propagators)

      Process.sleep(10)

      {state, _data} = Space.get_state_and_data(space)
      assert state == :stable
    end

    test "solved space" do
      x_values = 1..2
      y_values = 1..1
      z_values = 1..2

      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]

      {:ok, space} = Space.create(variables, propagators)
      Process.sleep(10)
      {state, %{variables: space_variables} = _data} = Space.get_state_and_data(space)
      assert state == :solved
      ## Check if all space variables are fixed
      assert Enum.all?(variables, fn var -> Store.get(space, var, :fixed?) end)
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
  end
end
