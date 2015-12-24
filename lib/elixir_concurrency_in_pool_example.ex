defmodule ElixirConcurrencyInPoolExample do
  use Application

  def start(_type, _args) do
    # We must start the pool with the application otherwise
    # the application is not kept alive.
    start_pool()
  end

  def run(range) do
    {:ok, _pid} = start_pool()
    start_jobs(range)
    collect_job_responses(range)
  end

  defp start_jobs(range) do
    caller = self
    Enum.each(
      range,
      fn(x) ->
        spawn(fn() ->
          execute_job(caller, x)
        end)
        IO.puts("Job #{x} enqueued")
      end
    )
  end

  defp execute_job(caller, x) do
    response = pooled_job(x)
    send caller, {:ok, response}
  end

  defp collect_job_responses(range) do
    Enum.map(range, fn(_) -> get_job_response() end)
  end

  defp get_job_response() do
    receive do
      {:ok, response} -> response
    end
  end

  defp start_pool() do
    poolboy_config = [
      {:name, {:local, :example_pool}},
      {:worker_module, ElixirConcurrencyInPoolExample.Worker},
      {:size, 0},
      {:max_overflow, 2}
    ]

    children = [
     :poolboy.child_spec(:example_pool, poolboy_config, [])
    ]

    options = [
     strategy: :one_for_one,
     name: ElixirConcurrencyInPoolExample.Worker
    ]

    case Supervisor.start_link(children, options) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  defp pooled_job(x) do
    :poolboy.transaction(
      :example_pool,
      fn(pid) -> ElixirConcurrencyInPoolExample.Worker.run(pid, x) end
    )
  end
end
