defmodule ElixirConcurrencyInPoolExample.Worker do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, :worker)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(x, from, state) do
    result = ElixirConcurrencyInPoolExample.Processor.run(x)
    {:reply, result, state}
  end

  def run(pid, x) do
    GenServer.call(pid, x)
  end
end
