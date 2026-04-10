defmodule CPSolver.Distributed do
  require Logger

  def call(node, solver, mod, function, args) do
    :erpc.call(node, mod, function, [solver | args])
  end

  def worker_nodes(node_list \\ [Node.self() | Node.list()]) do
    node_list
  end

  def choose_worker_node(nodes \\ worker_nodes())

  def choose_worker_node(true) do
    worker_nodes()
    |> choose_worker_node()
  end

  def choose_worker_node(distributed?) when not distributed? do
    Node.self()
  end

  def choose_worker_node(node_list) when is_list(node_list) do
    Enum.random(node_list)
  end

  def test() do
    alias CPSolver.Examples.{Sudoku, Queens}

    Logger.configure(level: :info)

    leader_node = :leader
    if Node.self() |> to_string() |> String.starts_with?(to_string(leader_node)) do
      ## cluster is up, skip initialization
      :ok
    else
      Node.start(leader_node, :shortnames)
      Node.set_cookie(:solver)
      # Run the solver with the model that takes noticeable time to complete.
      _worker_nodes = Enum.map(["node1", "node2", "node3"], fn node ->
        {:ok, _pid, node_name} = :peer.start(%{name: node, longnames: false, args: [~c"-setcookie", ~c"solver"]})
        :erpc.call(node_name, :code, :add_paths, [:code.get_path()])
        node_name
      end)
    end

    # Run the solver with the model that takes noticeable time to complete.
    my_pid = self()
    ## Distributed Sudoku
    Logger.notice("Sudoku test: starting")

    five_solutions_sudoku = Sudoku.puzzles().s9x9_5
    {:ok, _res} = CPSolver.solve(Sudoku.model(five_solutions_sudoku),
          solution_handler: fn solution ->
        send(my_pid, {Node.self(), solution})
      end,
      distributed: Enum.shuffle(Node.list())
    )
    verify_solutions(5)
    Logger.notice("Sudoku test: ok")


    ## Distributed Queens
    Logger.notice("Queens test: starting")

    {:ok, _res} = CPSolver.solve(Queens.model(8),
      solution_handler: fn solution ->
        send(my_pid, {Node.self(), solution})
      end,
      distributed: Enum.shuffle(Node.list())
    )
    verify_solutions(92)
    Logger.notice("Queens test: ok")
    true

  end

  def verify_solutions(expected_count) do
    solutions = CPSolver.Utils.flush()
    ^expected_count = length(solutions)
    true =
      solutions
      |> MapSet.new(fn {node, _solution} -> node end)
      |> tap(fn nodes -> Logger.info("Nodes with solutions: #{Enum.join(nodes, "")}") end)
      |> MapSet.subset?(MapSet.new(Node.list()))
  end




end
