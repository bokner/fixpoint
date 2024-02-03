defmodule CPSolverTest.MutableDomain do
  use ExUnit.Case

  describe "Default domain" do
    alias CPSolver.BitVectorDomain, as: Domain

    test "creates domain from integer range and list" do
      assert catch_throw(Domain.new([])) == :empty_domain

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

      {:fixed, domain} = Domain.remove(domain, 4)

      assert 0 == Domain.min(domain)
    end

    test "removeBelow, removeAbove" do
      values = [-1, 0, 2, 3, 4, 10]
      domain = Domain.new(values)

      {:min_change, cutBelow} = Domain.removeBelow(domain, 1)
      assert Domain.min(cutBelow) >= 1

      {:min_change, cutBelow} = Domain.removeBelow(domain, 3)

      assert Domain.min(cutBelow) == 3

      assert Domain.removeBelow(domain, Enum.max(values) + 1) == :fail

      assert :no_change == Domain.removeBelow(domain, Enum.min(values))
      {:fixed, fixed} = Domain.removeBelow(domain, Enum.max(values))
      assert Domain.fixed?(fixed)
    end

    test "removeAbove" do
      values = [-1, 0, 2, 3, 4, 10]
      domain = Domain.new(values)

      {:max_change, cutAbove} = Domain.removeAbove(domain, 3)
      assert Domain.max(cutAbove) <= 3

      {:max_change, cutAbove} = Domain.removeAbove(domain, 1)

      assert Domain.max(cutAbove) == 0

      assert Domain.removeAbove(domain, Enum.min(values) - 1) == :fail
      assert :no_change == Domain.removeAbove(domain, Enum.max(values))
      {:fixed, fixed} = Domain.removeAbove(domain, Enum.min(values))
      assert Domain.fixed?(fixed)
    end

    test "fix" do
      values = [0, -2, 4, 5, 6]
      domain = Domain.new(values)

      assert Enum.all?(values, fn val ->
               {:fixed, fixed} = Domain.fix(domain, val)

               Domain.fixed?(fixed) &&
                 Domain.min(fixed) == val &&
                 Domain.max(fixed) == val
             end)

      ## Fixing non-existing value leads to a failure
      assert :fail == Domain.fix(domain, 1)
    end

    test "to_list, map" do
      values = [0, 2, 3, -1, 4, 10]
      domain = Domain.new(values)
      assert Enum.sort(Domain.to_list(domain)) == Enum.sort(values)

      mapper_fun = fn x -> 2 * x end

      assert Domain.map(domain, mapper_fun) |> Enum.sort() ==
               Enum.map(values, mapper_fun) |> Enum.sort()
    end
  end
end