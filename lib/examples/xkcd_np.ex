defmodule CPSolver.Examples.XKCD.NP do
  @doc """
  <a href="https://xkcd.com/287/">xkcd-np</a>.
  """
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model

  import CPSolver.Variable.View.Factory
  import CPSolver.Constraint.Factory

  def model() do
    appetizers = [
      {:mixed_fruit, 215},
      {:french_fries, 275},
      {:side_salad, 335},
      {:hot_wings, 355},
      {:mozarella_sticks, 420},
      {:sampler_plate, 580}
    ]

    total = 1505

    quantities =
      Enum.map(appetizers, fn {name, price} ->
        mul(Variable.new(0..div(total, price), name: name), price)
      end)

    sum_constraint = sum(quantities, total)

    Model.new(quantities, [sum_constraint], extra: %{appetizers: appetizers, total: total})
  end

  def check_solution(solution, %{extra: %{appetizers: appetizers, total: total}} = _model) do
    appetizers
    |> Enum.zip(solution |> Enum.take(length(appetizers)))
    |> Enum.reduce(0, fn {{_name, price}, quantity}, acc -> acc + price * quantity end)
    |> then(fn sum -> sum == total end)
  end

  def solve() do
    model = model()
    num_appetizers = length(model.extra.appetizers)
    {:ok, res} = CPSolver.solve(model)

    Enum.map_join(res.solutions, "\n OR \n", fn sol ->
      sol
      |> Enum.zip(res.variables)
      |> Enum.take(num_appetizers)
      |> Enum.reject(fn {q, _name} -> q == 0 end)
      |> Enum.map_join(", ", fn {q, name} -> "#{name} : #{q}" end)
    end)
    |> IO.puts()
  end
end
