defmodule ElixirConcurrencyInPoolExample.Processor do

  def run(x) do
    duration = 500
    IO.puts("Job #{x} starting (sleeping #{duration} ms)")
    :timer.sleep(duration)
    IO.puts("Job #{x} done")
    x
  end
end
