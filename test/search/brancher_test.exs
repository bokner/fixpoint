defmodule CPSolverTest.Search.FirstFail do
  use ExUnit.Case

  alias CPSolver.Search
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Search.DefaultBrancher

  alias CPSolver.Utils.Vector

  test "default brancher is the same as {:first_fail, :indomain_min}" do
    v1_values = 0..9
    v2_values = 1..10
    # This domain (will be assigned to `v2` variable) is the smallest among unfixed
    v3_values = 1..5
    values = [v1_values, v2_values, v3_values]
    variables = Enum.map(values, fn d -> Variable.new(d) end)

    ## Mocked space data
    space_data = %{unfixed_variables_tracker: nil}
    _default_brancher_partitions =
      [partition1, partition2] = Search.branch(variables, DefaultBrancher, space_data)

    ## 1st partition has var3 fixed
    %{variable_copies: vars, domain_changes: changes} = partition1.(variables, space_data)
    var3_copy = Vector.at(vars, 2)
    assert Map.values(changes) == [:fixed]
    assert Variable.fixed?(var3_copy) && Variable.min(var3_copy) == 1
    ## 2nd partition has min value (1) removed from var3
    %{variable_copies: vars, domain_changes: changes} = partition2.(variables, space_data)
    var3_copy = Vector.at(vars, 2)
    assert Map.values(changes) == [:min_change]
    refute Variable.contains?(var3_copy, 1)
  end
end
