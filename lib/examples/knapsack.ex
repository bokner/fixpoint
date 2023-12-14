defmodule CPSolver.Examples.Knapsack do
  @moduledoc """
  The 'knapsack' problem is mathematically formulated in
  the following way. Given n items to choose from, each item i ∈ 0 ...n − 1 has a value v[i] and a
  weight w[i]. The knapsack has a limited capacity K. Let x[i] be a variable that is 1 if you choose
  to take item i and 0 if you leave item i behind. Then the knapsack problem is formalized as the
  following optimization problem:

  Maximize sum(x[i]*v[i]), i = 0 ... n - 1
  subject to sum(x[i] * w[i]) <= K

  Input data:
  First line: "n K"
  Next lines: "value weight"
  """
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Constraint.Sum
  alias CPSolver.Constraint.LessOrEqual
  import CPSolver.Variable.View.Factory
  alias CPSolver.Objective

  def model(values, weights, capacity) do
    items = Enum.map(1..length(values), fn i -> Variable.new(0..1, name: "item_#{i}") end)
    total_weight = Variable.new(0..capacity, name: "total_weight")
    total_value = Variable.new(0..Enum.sum(values), name: "total_value")

    constraints = [
      Sum.new(
        total_weight,
        Enum.map(
          Enum.zip(items, weights),
          fn {item, weight} -> mul(item, weight) end
        )
      ),
      Sum.new(
        total_value,
        Enum.map(
          Enum.zip(items, values),
          fn {item, value} -> mul(item, value) end
        )
      ),
      LessOrEqual.new(total_weight, capacity)
    ]

    %{
      variables: items ++ [total_weight, total_value],
      constraints: constraints,
      objective: Objective.maximize(total_value)
    }
  end

  def model(input) do
    input
    |> File.read!()
    |> String.trim()
    |> String.split("\n")
    |> then(fn lines ->
      [header | item_data] = lines
      capacity = String.split(header, " ") |> List.last() |> String.to_integer()

      {values, weights} =
        List.foldr(item_data, {[], []}, fn str, {vals_acc, weights_acc} ->
          [v, w] = String.split(str, " ")

          {
            [String.to_integer(v) | vals_acc],
            [String.to_integer(w) | weights_acc]
          }
        end)

      model(values, weights, capacity)
    end)
  end
end
