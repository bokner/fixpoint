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
  alias CPSolver.Model
  alias CPSolver.Constraint.Sum
  alias CPSolver.Constraint.LessOrEqual
  import CPSolver.Variable.View.Factory
  alias CPSolver.Objective

  def prebuild_model(values, weights, capacity) do
    items = Enum.map(1..length(values), fn i -> Variable.new(0..1, name: "item_#{i}") end)
    total_weight = Variable.new(0..capacity, name: "total_weight")
    total_value = Variable.new(0..Enum.sum(values), name: "total_value")

    weight_views =
      Enum.map(
        Enum.zip(items, weights),
        fn {item, weight} -> mul(item, weight) end
      )

    value_views =
      Enum.map(
        Enum.zip(items, values),
        fn {item, value} -> mul(item, value) end
      )

    %{
      items: items,
      total_value: total_value,
      total_weight: total_weight,
      weight_views: weight_views,
      value_views: value_views
    }
  end

  def value_maximization_model(values, weights, capacity) do
    %{
      items: items,
      total_value: total_value,
      total_weight: total_weight,
      weight_views: weight_views,
      value_views: value_views
    } =
      prebuild_model(values, weights, capacity)

    constraints = [
      Sum.new(
        total_weight,
        weight_views
      ),
      Sum.new(total_value, value_views),
      LessOrEqual.new(total_weight, capacity)
    ]

    Model.new(
      items ++ [total_weight, total_value],
      constraints,
      objective: Objective.maximize(total_value)
    )
  end

  def model(input, kind \\ :value_maximization) do
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

      model(values, weights, capacity, kind)
    end)
  end

  def model(values, weights, capacity, kind \\ :value_maximization)

  def model(values, weights, capacity, :value_maximization) do
    value_maximization_model(values, weights, capacity)
  end

  def model(values, weights, capacity, :free_space_minimization) do
    free_space_minimization_model(values, weights, capacity)
  end

  ## Minimizes free space
  def free_space_minimization_model(values, weights, capacity) do
    %{
      items: items,
      total_weight: total_weight,
      weight_views: weight_views
    } =
      prebuild_model(values, weights, capacity)

    space_constraints = [
      Sum.new(total_weight, weight_views),
      LessOrEqual.new(total_weight, capacity)
    ]

    Model.new(
      items ++ [total_weight],
      space_constraints,
      objective: Objective.minimize(linear(total_weight, -1, capacity))
    )
  end

  def check_solution(solution, optimal, values, weights, capacity) do
    items_to_pack = Enum.take(solution, length(weights))
    total_weight = sum_products(items_to_pack, weights)

    total_weight <= capacity && sum_products(items_to_pack, values) <= optimal
  end

  defp sum_products(list1, list2) do
    Enum.zip(list1, list2)
    |> Enum.reduce(0, fn {el1, el2}, acc -> acc + el1 * el2 end)
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
  def tourist_knapsack_model() do
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

    model(values, weights, capacity)
    |> replace_variable_names(item_names)
  end

  defp replace_variable_names(%{variables: variables} = model, item_names) do
    variables
    |> Enum.zip(item_names ++ List.duplicate(nil, length(variables) - length(item_names)))
    |> Enum.map(fn {var, name} -> (name && Map.put(var, :name, name)) || var end)
    |> then(fn named_vars -> Map.put(model, :variables, named_vars) end)
  end
end
