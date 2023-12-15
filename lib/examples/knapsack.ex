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

  @doc """
  From Rosetta code:
  http://rosettacode.org/wiki/Knapsack_problem/0-1

  A tourist wants to make a good trip at the weekend with his friends. They
  will go to the mountains to see the wonders of nature, so he needs to
  pack well for the trip. He has a good knapsack for carrying things, but
  knows that he can carry a maximum of only 4kg in it and it will have
  to last the whole day. He creates a list of what he wants to bring for the
  trip but the total weight of all items is too much. He then decides to
  add columns to his initial list detailing their weights and a numerical
  value representing how important the item is for the trip.

  Here is the list:
  Table of potential knapsack items
  item 	weight (dag) 	value
  map 	9 	150
  compass 	13 	35
  water 	153 	200
  sandwich 	50 	160
  glucose 	15 	60
  tin 	68 	45
  banana 	27 	60
  apple 	39 	40
  cheese 	23 	30
  beer 	52 	10
  suntan cream 	11 	70
  camera 	32 	30
  T-shirt 	24 	15
  trousers 	48 	10
  umbrella 	73 	40
  waterproof trousers 	42 	70
  waterproof overclothes 	43 	75
  note-case 	22 	80
  sunglasses 	7 	20
  towel 	18 	12
  socks 	4 	50
  book 	30 	10
  knapsack 	<=400 dag 	 ?

  The tourist can choose to take any combination of items from the list, but
  only one of each item is available. He may not cut or diminish the items,
  so he can only take whole units of any item.

  Which items does the tourist carry in his knapsack so that their total weight
  does not exceed 400 dag [4 kg], and their total value is maximised?

  [dag = decagram = 10 grams]
  """
  def tourist_knapsack() do
    items = [
      {:map, 9, 150},
      {:compass, 13, 35},
      {:water, 153, 200},
      {:sandwich, 50, 160},
      {:glucose, 15, 60},
      {:tin, 68, 45},
      {:banana, 27, 60},
      {:apple, 39, 40},
      {:cheese, 23, 30},
      {:beer, 52, 10},
      {:suntan_cream, 11, 70},
      {:camera, 32, 30},
      {:t_shirt, 24, 15},
      {:trousers, 48, 10},
      {:umbrella, 73, 40},
      {:waterproof_trousers, 42, 70},
      {:waterproof_overclothes, 43, 75},
      {:note_case, 22, 80},
      {:sunglasses, 7, 20},
      {:towel, 18, 12},
      {:socks, 4, 50},
      {:book, 30, 10}
    ]

    capacity = 400

    {item_names, weights, values} =
      List.foldr(items, {[], [], []}, fn {n, w, v}, {n_acc, w_acc, v_acc} = _acc ->
        {[n | n_acc], [w | w_acc], [v | v_acc]}
      end)

    model = model(values, weights, capacity)
    {:ok, res} = CPSolver.solve_sync(model, timeout: 5_000)
    ## total_value variable (which is one in maximization objective) is at pos 23
    optimal_solution = Enum.max_by(res.solutions, fn sol -> Enum.at(sol, 23) end)

    {items_to_pick, total_value} =
      List.foldr(Enum.with_index(item_names), {[], 0}, fn {item, idx}, {item_list, total_value} ->
        in_the_list = Enum.at(optimal_solution, idx) == 1

        {
          (in_the_list && [item | item_list]) || item_list,
          (in_the_list && total_value + Enum.at(values, idx)) || total_value
        }
      end)

    IO.puts("Items to pick: #{IO.ANSI.blue()}#{inspect(items_to_pick)}#{IO.ANSI.reset()}")
    IO.puts("Total value: #{IO.ANSI.red()}#{total_value}#{IO.ANSI.reset()}")
  end
end
