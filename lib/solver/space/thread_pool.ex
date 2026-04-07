defmodule CPSolver.Space.ThreadPool do
  use GenServer

  alias InPlace.Array

  @impl true
  def init(pool_size) do
    pool_ref = Array.new(1, pool_size)
    {:ok, %{space_queue: :queue.new(), pool_size: pool_size, pool_ref: pool_ref}}
  end

  @impl true
  def handle_call(:checkout, {caller_pid, _ref} = caller, %{space_queue: queue} = state) do
    if Process.alive?(caller_pid) do
      if checkout_impl?(state) do
        {:reply, true, state}
      else
        {:noreply, Map.put(state, :space_queue, :queue.in(caller, queue))}
      end
    else
      {:noreply, state}
    end
  end

  def handle_call(
        :get_pool_state,
        _caller,
        %{pool_size: pool_size, pool_ref: pool_ref, space_queue: queue} = state
      ) do
    {:reply, {:ok, %{queue: queue, pool_size: pool_size, available: get_free_threads(pool_ref)}},
     state}
  end

  @impl true
  def handle_cast(:checkin, state) do
    updated_queue = checkin_impl(state)
    {:noreply, Map.put(state, :space_queue, updated_queue)}
  end

  ## API
  def new(pool_size) when is_integer(pool_size) and pool_size > 0 do
    {:ok, _pid} = GenServer.start(__MODULE__, pool_size)
  end

  def checkout(thread_pool, timeout \\ :infinity) when is_pid(thread_pool) do
    GenServer.call(thread_pool, :checkout, timeout)
  end

  def checkin(thread_pool) when is_pid(thread_pool) do
    GenServer.cast(thread_pool, :checkin)
  end

  def get_pool_state(thread_pool) do
    GenServer.call(thread_pool, :get_pool_state)
  end

  defp get_free_threads(pool_ref) do
    Array.get(pool_ref, 1)
  end

  defp checkout_impl?(%{pool_ref: pool_ref} = _state) do
    case get_free_threads(pool_ref) do
      free_threads when free_threads > 0 ->
        Array.put(pool_ref, 1, free_threads - 1)
        true

      0 ->
        ## All threads are taken
        false

      _oversplill ->
        throw({:error, :thread_pool_checkout_error})
    end
  end

  defp checkin_impl(%{pool_size: pool_size, pool_ref: pool_ref, space_queue: queue} = _state) do
    increase_available_pool_count(pool_ref, pool_size)
    {process_to_checkout, updated_queue} = get_waiting_process(queue)

    if process_to_checkout do
      decrease_available_pool_count(pool_ref)
      ## Wake up the waiting the process
      GenServer.reply(process_to_checkout, true)
    end

    updated_queue
  end

  def get_waiting_process(queue) do
    case :queue.out(queue) do
      {:empty, q} ->
        {nil, q}

      {{:value, {pid, _ref} = caller}, q} ->
        if Process.alive?(pid) do
          {caller, q}
        else
          get_waiting_process(q)
        end
    end
  end

  defp increase_available_pool_count(pool_ref, pool_size) do
    Array.update(pool_ref, 1, fn current ->
      if current < pool_size do
        current + 1
      end
    end)
  end

  defp decrease_available_pool_count(pool_ref) do
    Array.update(pool_ref, 1, fn current ->
      if current > 0 do
        current - 1
      end
    end)
  end
end
