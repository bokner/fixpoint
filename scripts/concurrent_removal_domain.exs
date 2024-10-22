defmodule ConcurrentRemoval do
  alias CPSolver.BitVectorDomain, as: Domain

  def run() do
    n_values = 2
    values = 1..n_values
    domain = Domain.new(values)

    Task.async_stream(
      1..2,
      fn _thread_id ->
        try do
          ## Keep one random value, remove the rest
          Enum.each(Enum.take_random(values, n_values - 1), fn val ->
            Domain.remove(domain, val)
          end)
        catch
          _ ->
            :failed
        end
      end,
      max_concurrency: 2
    )
    |> Enum.to_list()

    !Domain.failed?(domain)
  end
end
