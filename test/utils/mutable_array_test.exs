defmodule CPSolverTest.Utils.MutableArray do
  use ExUnit.Case
  import CPSolver.Utils.MutableArray

  describe "Mutable order" do
    alias CPSolver.Utils.MutableOrder

    test "create" do
      values = [2, 8, 3, 5, 2]
      order_rec = MutableOrder.new(values)
      assert {_sort_index, [2, 2, 3, 5, 8]} = MutableOrder.to_sorted(order_rec) |> Enum.unzip()
    end

    test "update (current value decreasing)" do
      values = [2, 8, 3, 5, 2]
      order_rec = MutableOrder.new(values)

      ## Current value of element at position 1 (that is, 8) changes to 2
      change = {1, 2}
      MutableOrder.update(order_rec, change)
      ## The changed value has been updated internally
      assert to_array(order_rec.values) == [2, 2, 3, 5, 2]
      ## The order is maintained
      {asc_sort_index, asc_sorted_values} = MutableOrder.to_sorted(order_rec, :asc) |> Enum.unzip()
      {desc_sort_index, desc_sorted_values} = MutableOrder.to_sorted(order_rec, :desc) |> Enum.unzip()

      assert Enum.reverse(asc_sort_index) == desc_sort_index
      assert Enum.reverse(asc_sorted_values) == desc_sorted_values

      assert MutableOrder.valid?(order_rec)
    end

    test "update (current value increasing)" do
      values = [2, 8, 3, 5, 2]
      order_rec = MutableOrder.new(values)

      ## Current value of element at position 2 (that is, 3) changes to 9
      change = {2, 9}
      MutableOrder.update(order_rec, change)
      ## The changed value has been updated internally
      assert to_array(order_rec.values) == [2, 8, 9, 5, 2]
      ## The order is maintained
      {asc_sort_index, asc_sorted_values} = MutableOrder.to_sorted(order_rec, :asc) |> Enum.unzip()
      {desc_sort_index, desc_sorted_values} = MutableOrder.to_sorted(order_rec, :desc) |> Enum.unzip()

      assert Enum.reverse(asc_sort_index) == desc_sort_index
      assert Enum.reverse(asc_sorted_values) == desc_sorted_values

      assert MutableOrder.valid?(order_rec)
    end

    test "get" do
      values = [2, 8, 3, 5, 2]
      order_rec = MutableOrder.new(values)
      assert Enum.sort(values) == Enum.map(0..(length(values) - 1), fn idx -> MutableOrder.get(order_rec, idx) end)
    end

    test "valid?" do
      values = [4, 1, 5, 3, 9, 6, 7, 8, 2]
      order = MutableOrder.new(values)
      assert MutableOrder.valid?(order)
      MutableOrder.update(order, {0, 0})
      assert MutableOrder.valid?(order)

      ## Swap values without changing the sort index
      range = Enum.to_list(0..length(values)-1)
      rnd1 = Enum.random(range)
      rnd2 = Enum.random(List.delete(range, rnd1))
      swap(order.values, rnd1, rnd2)
      refute MutableOrder.valid?(order)
    end
  end
end
