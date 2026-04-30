defmodule CPSolverTest.Space.ThreadPool do
  use ExUnit.Case

  alias CPSolver.Space.ThreadPool

  describe "The pool for space threads" do
    test "checkouts" do
      num_threads = 4
      {:ok, thread_pool} = ThreadPool.new(num_threads)
      {:ok, %{queue: q}} = ThreadPool.get_pool_state(thread_pool)
      assert 0 = :queue.len(q)
      ## If number of checkouts does not exceed the pool capacity,
      ## the process queue is empty.
      assert Enum.all?(1..num_threads, fn i ->
        spawn(fn ->
          ThreadPool.run_task(
            fn -> :timer.sleep(100) end,
            thread_pool)
        end)
        ## Give it a bit of time for the process to check out.
        :timer.sleep(10)
        {:ok, %{queue: q, available: available_threads}} = ThreadPool.get_pool_state(thread_pool)
        ## No queue, available thread count is down with every checkout
        :queue.len(q) == 0 && available_threads == num_threads - i
      end)
      ## No available threads now
      {:ok, %{available: available}} = ThreadPool.get_pool_state(thread_pool)
      assert 0 = available
      ## This process will be added to pool queue
      my_pid = self()
      waiting_process = spawn(fn ->
        ThreadPool.run_task(
        fn ->
          send(my_pid, {:completed, self()})
        end,
        thread_pool)
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

    test "checkins" do
      num_threads = 4
      {:ok, thread_pool} = ThreadPool.new(num_threads)

      ## Checking in while the pool is at capacity
      sleep_interval = 100
      spawn(fn ->
          ThreadPool.checkin(thread_pool)
          :timer.sleep(sleep_interval)
      end)
      ## Give some time for the process to check in, but not to complete
      :timer.sleep(div(sleep_interval, 2))
      {:ok, %{available: available}} = ThreadPool.get_pool_state(thread_pool)
      ## No effect on the pool
      assert num_threads == available
      ## Check out all the capacity
      Enum.each(1..num_threads, fn _ ->
        ThreadPool.checkout(thread_pool)
        :timer.sleep(10)
      end)
      {:ok, %{available: available, queue: queue}} = ThreadPool.get_pool_state(thread_pool)
      assert 0 = available
      assert 0 = :queue.len(queue)

      ## This process will wait until first check-in
      waiting_process = spawn(fn ->
        ThreadPool.checkout(thread_pool)
      end)
      :timer.sleep(10)
      {:ok, %{queue: queue, available: available}} = ThreadPool.get_pool_state(thread_pool)
      assert 0 = available
      {:value, {process_pid, _ref}} = :queue.peek(queue)
      ## Process is in the queue
      assert waiting_process == process_pid
      ## Process is alive
      assert Process.alive?(waiting_process)
      ## Now, do a check-in
      ThreadPool.checkin(thread_pool)
      :timer.sleep(10)
      ## The process has completed
      refute Process.alive?(waiting_process)
      ## The queue has been cleaned, but there is still no available threads
      {:ok, %{queue: queue, available: available}} = ThreadPool.get_pool_state(thread_pool)
      assert (0 = available)
      assert :queue.len(queue) == 0
      ## Another check-in to free up one thread
      ThreadPool.checkin(thread_pool)
      :timer.sleep(10)
      {:ok, %{available: available}} = ThreadPool.get_pool_state(thread_pool)
      assert 1 = available
    end
  end

end
