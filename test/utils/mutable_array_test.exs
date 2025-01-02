defmodule CPSolverTest.Utils.MutableArray do
  use ExUnit.Case
  import CPSolver.Utils.MutableArray

  describe "Mutable order" do
    alias CPSolver.Utils.MutableOrder
    test "create" do
      values = [2, 8, 3, 5, 2]
      order_rec = MutableOrder.new(values)
      assert [2, 2, 3, 5, 8] = MutableOrder.to_sorted(order_rec)
    end

    test "update (current value decreasing)" do
      values = [2, 8, 3, 5, 2]
      order_rec = MutableOrder.new(values)

      change = {1, 2} ## Current value of element at position 1 (that is, 8) changes to 2
      MutableOrder.update(order_rec, change)
      ## The changed value has been updated internally
      assert to_array(order_rec.values) == [2, 2, 3, 5, 2]
      ## The order is maintained
      assert [2, 2, 2, 3, 5] == MutableOrder.to_sorted(order_rec, :asc)
      assert Enum.reverse([2, 2, 2, 3, 5]) == MutableOrder.to_sorted(order_rec, :desc)
    end

    test "update (current value increasing)" do
      values = [2, 8, 3, 5, 2]
      order_rec = MutableOrder.new(values)

      change = {2, 9} ## Current value of element at position 2 (that is, 3) changes to 9
      MutableOrder.update(order_rec, change)
      ## The changed value has been updated internally
      assert to_array(order_rec.values) == [2, 8, 9, 5, 2]
      ## The order is maintained
      assert [2, 2, 5, 8, 9] == MutableOrder.to_sorted(order_rec, :asc)
      assert Enum.reverse([2, 2, 5, 8, 9]) == MutableOrder.to_sorted(order_rec, :desc)
    end
  end
end
