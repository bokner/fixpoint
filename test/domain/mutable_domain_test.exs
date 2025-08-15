defmodule CPSolverTest.MutableDomain do
  use ExUnit.Case

  describe "Mutable domain" do
    alias CPSolver.BitVectorDomain, as: Domain

    test "creates domain from integer range and list" do
      assert catch_throw(Domain.new([])) == :fail

      assert Domain.size(Domain.new(1..10)) == 10

      int_list = [-1, 2, 4, 8, 10]
      assert Domain.size(Domain.new(int_list)) == length(int_list)
    end

    test "fixed?" do
      assert Domain.new([1]) |> Domain.fixed?()
      refute Domain.new([1, 2]) |> Domain.fixed?()
    end

    test "min, max" do
      values = [0, 2, 3, -1, 4, 10]
      domain = Domain.new(values)
      assert Domain.min(domain) == Enum.min(values)
      assert Domain.max(domain) == Enum.max(values)
    end

    test "contains?" do
      values = [1, 3, 7, -1, 0, -2, 10]
      domain = Domain.new(values)
      Enum.all?(values, fn v -> Domain.contains?(domain, v) end)
      refute Domain.contains?(domain, 9)
    end

    test "remove" do
      values = [0, 2, 3, -1, 4, 10]
      domain = Domain.new(values)

      {:domain_change, domain} = Domain.remove(domain, 3)
      refute Domain.contains?(domain, 3)
      assert Domain.size(domain) == length(values) - 1

      {:min_change, domain} = Domain.remove(domain, -1)
      {:max_change, domain} = Domain.remove(domain, 10)

      assert 0 == Domain.min(domain)
      assert 4 == Domain.max(domain)
      {:domain_change, domain} = Domain.remove(domain, 2)

      {:fixed, _fixed} = Domain.remove(domain, 4)

      assert 0 == Domain.min(domain)
    end

    test "removeBelow" do
      values = [-1, 0, 2, 3, 4, 10]
      domain = Domain.new(values)

      {:min_change, cutBelow} = Domain.removeBelow(domain, 1)
      assert Domain.min(cutBelow) == 2

      assert Domain.size(domain) == 4

      {:min_change, cutBelow} = Domain.removeBelow(domain, 3)

      assert Domain.min(cutBelow) == 3

      assert :no_change == Domain.removeBelow(domain, Enum.min(values))
      {:fixed, _fixed} = Domain.removeBelow(domain, Enum.max(values))
      assert Domain.fixed?(domain)
      assert catch_throw(Domain.removeBelow(domain, Enum.max(values) + 1)) == :fail
    end

    test "removeAbove" do
      values = [-1, 0, 2, 3, 4, 10]
      domain = Domain.new(values)

      {:max_change, cutAbove} = Domain.removeAbove(domain, 3)
      assert Domain.max(cutAbove) == 3

      assert Domain.size(domain) == 4
      {:max_change, cutAbove} = Domain.removeAbove(domain, 1)

      assert Domain.max(cutAbove) == 0

      assert :no_change == Domain.removeAbove(domain, Enum.max(values))
      {:fixed, _fixed} = Domain.removeAbove(domain, Enum.min(values))
      assert Domain.fixed?(domain)
      assert catch_throw(Domain.removeAbove(domain, Enum.min(values) - 1)) == :fail
    end

    test "fix" do
      values = [0, -2, 4, 5, 6]

      assert Enum.all?(values, fn val ->
               domain = Domain.new(values)
               :fixed = Domain.fix(domain, val)

               Domain.fixed?(domain) &&
                 Domain.min(domain) == val &&
                 Domain.max(domain) == val
             end)

      ## Fixing non-existing value leads to a failure
      domain = Domain.new(values)
      assert catch_throw(Domain.fix(domain, 1)) == :fail
    end

    test "to_list, map" do
      values = [0, 2, 3, -1, 4, 10]
      domain = Domain.new(values)
      assert Enum.sort(Domain.to_list(domain)) == Enum.sort(values)

      mapper_fun = fn x -> 2 * x end

      assert Domain.map(domain, mapper_fun) |> Enum.sort() ==
               Enum.map(values, mapper_fun) |> Enum.sort()
    end

    test "copy" do
      values = 200..500
      domain = Domain.new(values)
      Domain.removeAbove(domain, 300)
      domain_copy = Domain.copy(domain)
      assert Domain.to_list(domain) == Domain.to_list(domain_copy)
      assert Domain.size(domain) == Domain.size(domain_copy)
      assert Domain.min(domain) == Domain.min(domain_copy)
      assert Domain.max(domain) == Domain.max(domain_copy)

      Domain.removeBelow(domain_copy, 250)
      domain_copy2 = Domain.copy(domain_copy)
      assert Domain.to_list(domain_copy2) == Domain.to_list(domain_copy)
      assert Domain.size(domain_copy2) == Domain.size(domain_copy)
      assert Domain.min(domain_copy2) == Domain.min(domain_copy)
      assert Domain.max(domain_copy2) == Domain.max(domain_copy)
    end

    test "consistency" do
      data = %{
        max: 76,
        min: 14,
        raw: %{offset: -11, content: [4_503_599_644_147_720, 2, 279_172_874_243]},
        size: 4,
        remove: 76,
        values: [76, 63, 35, 14],
        failed?: false,
        fixed?: false
      }

      domain = build_domain(data)
      assert_domain(domain, data.values)

      {:max_change, _} = Domain.remove(domain, Domain.max(domain))

      values1 = List.delete(data.values, Enum.max(data.values))

      assert_domain(domain, values1)
    end

    @tag :slow
    test "Concurrent removal of values (threads remove distinct values)" do
      ##
      values = 1..100_000
      domain = Domain.new(values)

      Task.async_stream(
        values,
        fn val ->
          try do
            Domain.remove(domain, val)
          catch
            _ ->
              :ok
          end
        end,
        max_concurrency: 8
      )
      |> Enum.to_list()

      assert Domain.failed?(domain)
    end

    test "Concurrent removal of values (multiple threads remove shared values)" do
      ##
      n_values = 3
      values = 1..n_values
      domain = Domain.new(values)

      Task.async_stream(
        1..2,
        fn _thread_id ->
          try do
            ## Keep one random value, remove the rest
            Enum.each(Enum.take(values, n_values - 1), fn val ->
              Domain.remove(domain, val)
            end)
          catch
            _ ->
              :failed
          end
        end,
        max_concurrency: 8
      )
      |> Enum.to_list()

      assert Domain.fixed?(domain)
    end

    defp build_domain(data) do
      ref = :atomics.new(length(data.raw.content), [{:signed, false}])

      Enum.each(Enum.with_index(data.raw.content, 1), fn {val, idx} ->
        :atomics.put(ref, idx, val)
      end)

      bit_vector = {:bit_vector, ref}
      _domain = {bit_vector, data.raw.offset}
    end

    defp assert_domain(domain, values) do
      assert Domain.to_list(domain) |> Enum.sort() == values |> Enum.sort()
      assert Domain.size(domain) == length(values)
      assert Domain.min(domain) == Enum.min(values)
      assert Domain.max(domain) == Enum.max(values)
      refute Domain.fixed?(domain)
      refute Domain.failed?(domain)
    end
  end

  describe "Single-value domain" do
    alias CPSolver.DefaultDomain, as: Domain

    test "single-value domain" do
      assert Domain.fixed?(1)
      assert Domain.size(5) == 1
      assert Domain.contains?(1, 1)
      refute Domain.contains?(1, 2)

      assert Domain.min(1) == 1
      assert Domain.max(1) == 1

      assert Domain.to_list(1) == MapSet.new([1])
      assert Domain.map(3, fn x -> 2 * x end) == [6]
      assert Domain.copy(1) == 1

      assert Domain.remove(2, 1) == :no_change
      assert catch_throw(Domain.remove(2, 2)) == :fail

      assert Domain.removeAbove(2, 2) == :no_change
      assert catch_throw(Domain.removeAbove(3, 2)) == :fail

      assert Domain.removeBelow(2, 2) == :no_change
      assert catch_throw(Domain.removeBelow(2, 3)) == :fail

      assert Domain.fix(1, 1) == :no_change
      assert catch_throw(Domain.fix(1, 2)) == :fail
    end
  end

  describe "iterating" do
    alias CPSolver.DefaultDomain, as: Domain

    test "next value" do
      ## interval domain
      interval = -1000..1000
      assert_next(interval)
      ## enumerable domain
      enum_domain = [-100, -65, -1, 0, 1, 22, 64, 65, 228, 1002]
      assert_next(enum_domain)
    end

    test "iterator" do
      interval = -1000..1000
      values = Enum.take_random(interval, 10)
      domain = Domain.new(values)
      iterator = Domain.iterator(domain)
      assert Enum.sort(Iter.Iterable.to_list(iterator)) == Enum.sort(values)
      ## Pipe iterator into another one
      mapper = fn val -> val * 2 end
      piped_iterator = Iter.Iterable.Mapper.new(iterator, mapper)

      assert Enum.sort(Iter.Iterable.to_list(piped_iterator)) ==
               Enum.sort(Enum.map(values, mapper))
    end

    defp assert_next(values) do
      domain = Domain.new(values)
      ## next(domain, value) takes next value for all but the max(domain)
      assert Enum.drop(values, -1)
             |> Enum.with_index(0)
             |> Enum.all?(fn {val, pos} ->
               Domain.next(domain, val) == Enum.at(values, pos + 1)
             end)

      ## No next for the max value
      refute Domain.next(domain, Domain.max(domain))
      ## next is min(domain) for values less than min
      assert Domain.next(domain, Domain.min(domain) - 1) == Domain.min(domain)
    end
  end
end
