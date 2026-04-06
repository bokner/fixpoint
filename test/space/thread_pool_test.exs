defmodule CPSolverTest.Space.ThreadPool do
  use ExUnit.Case

  alias CPSolver.Space.ThreadPool

  describe "The pool for space threads" do
    test "thread pool" do
      num_threads = 4
      {:ok, thread_pool} = ThreadPool.new(num_threads)
      {:ok, %{queue: q}} = ThreadPool.get_pool_state(thread_pool)
      assert 0 = :queue.len(q)
      ## If number of checkouts does not exceed the pool capacity,
      ## the process queue is empty.
      assert Enum.all?(1..num_threads, fn i ->
        spawn(fn ->
          ThreadPool.checkout(thread_pool)
          :timer.sleep(100)
          ThreadPool.checkin(thread_pool)
        end)
        {:ok, %{queue: q, available: available_threads}} = ThreadPool.get_pool_state(thread_pool)
        :queue.len(q) == 0
      end)
      ## No available threads now
      {:ok, %{available: available}} = ThreadPool.get_pool_state(thread_pool)
      assert 0 = available
      ## This process will be added to pool queue
      my_pid = self()
      waiting_process = spawn(fn ->
        ThreadPool.checkout(thread_pool)
        ThreadPool.checkin(thread_pool)
        send(my_pid, {:completed, self()})
      end)
      ## Give it a bit of time for the process to be added to the thread pool.
      :timer.sleep(10)
      {:ok, %{queue: q}} = ThreadPool.get_pool_state(thread_pool)
      assert :queue.len(q) == 1
      ## Wait for any of the processes previously checked out to complete and check in
      :timer.sleep(100)
      ## The waiting process should be removed from the queue...
      {:ok, %{queue: q}} = ThreadPool.get_pool_state(thread_pool)
      assert :queue.len(q) == 0
      ## ...and processed
      assert_receive {:completed, ^waiting_process}

      ## The pool is now at full capacity
      {:ok, %{available: available}} = ThreadPool.get_pool_state(thread_pool)
      assert num_threads == available
    end
  end

end
