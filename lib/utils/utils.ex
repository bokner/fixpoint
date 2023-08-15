defmodule CPSolver.Utils do
  def publish(topic, message) do
    :ebus.pub(topic, message)
  end

  def subscribe(pid, topic) when is_pid(pid) do
    :ebus.sub(pid, topic)
  end

  def unsubscribe(pid, topic) when is_pid(pid) do
    :ebus.unsub(pid, topic)
  end

  def subscribers(topic) do
    :ebus.subscribers(topic)
  end
end
