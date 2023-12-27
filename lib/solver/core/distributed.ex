defmodule CPSolver.Distributed do
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
end
