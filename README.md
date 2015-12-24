# Elixir Concurrency in Pool

## tl;dr;

A simple Elixir example for performing **concurrent operations, limiting the maximum concurrency using a pool mechanism** and **collecting the results** of all operations.

## Context

To learn Elixir, I'm building a simple backend application that performs calls to another webservice and performs some transformations for the client-side application.

Since Elixir is known for its proficiency in concurrency, I wanted to start learning how to handle it as soon as possible. In my use case, this meant performing calls to the external webservice concurrently. However, to prevent my Elixir app from running too much simultaneous requests, I wanted to be able to limit the concurrency.

I found two excellent articles to help me with that:
- [Parallelizing independent tasks](http://theerlangelist.blogspot.fr/2013/04/parallelizing-independent-tasks.html)
- [Beyond Task.async](http://theerlangelist.com/article/beyond_taskasync)

These articles describe in details several approaches to perform parallel operations in Elixir, pooling (using [poolboy](https://github.com/devinus/poolboy)) and collecting asynchronous jobs results. However, there is no example describing how to do all three altogether. I hope this example fills the gap.

### Disclaimer

I'm too much of a newbie in Elixir to go in much details on the code of the example. Instead, I will briefly describe the main parts and let you go deeper through the references and other resources.

It's ~~probably~~ not:

- the best way to do it,
- production-ready.

Use it at your own risk ;)

## Explanations

### Overview

The code is split in 3 parts:
- `elixir_concurrency_in_pool_example.ex`: the main module, which is the Elixir application,
- `elixir_concurrency_in_pool_example/worker.ex`: the worker module, which will perform the work and will be managed by the pool,
- `elixir_concurrency_in_pool_example/processor.ex`: the module defining the job to be done (in the example the job is only sleeping for 500 ms to _fake_ an external webservice request).

When we start the application (`ElixirConcurrencyInPoolExample`), we start the pool with `start_pool/0`. The pool is provided by [poolboy](https://github.com/devinus/poolboy) and configured to spawn a maximum of 2 concurrent workers (`{:max_overflow, 2}`).

Once the application is started, the processing can be done using `ElixirConcurrencyInPoolExample.run(1..10)`. A range is passed which represents the number of jobs to be run.

### run/1

```elixir
def run(range) do
  {:ok, _pid} = start_pool()
  start_jobs(range)
  collect_job_responses(range)
end
```

`ElixirConcurrencyInPoolExample.run(1..5)` performs 3 things:
- starts the pool (it has already been started when starting the application but the `start_pool/0` method can be called multiple times)
- start 5 processing jobs for the 1..5 range,
- collect the responses of the jobs.

### start_pool/0

This function is based on [elixir_poolboy_example](https://github.com/thestonefox/elixir_poolboy_example) where you will find more details. The only change I made was this:

```elixir
case Supervisor.start_link(children, options) do
  {:ok, pid} -> {:ok, pid}
  {:error, {:already_started, pid}} -> {:ok, pid}
end
```

This allows to call the function several times. It handles the case when the pool has already been started, and returns its pid too.

### start_jobs/1

```elixir
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
```

Here we simple iterate over the range to start a job in an independent process for every item of the range. The job is handled by `execute_job/2`. We pass `caller` so that the job can `send` a message back to the caller. We will use this to collect the responses.

```
defp execute_job(caller, x) do
  response = pooled_job(x)
  send caller, {:ok, response}
end
```

`execute_job/2` will perform the job through a pool worker, using `pooled_job/1`.

```
defp pooled_job(x) do
  :poolboy.transaction(
    :example_pool,
    fn(pid) -> ElixirConcurrencyInPoolExample.Worker.run(pid, x) end
  )
end
```

`pooled_job/1` run the job defined by `ElixirConcurrencyInPoolExample.Worker` within a poolboy transaction. This ensures we won't get more concurrent workers that the pool's concurrency.

I won't go in details for `Worker` and `Processor`. `Worker` is basically the same as [the one from elixir_poolbox_example](https://github.com/thestonefox/elixir_poolboy_example/blob/master/lib/elixir_poolboy_example/worker.ex) and `Processor` should be quite easy to understand.

Now that we spawned all jobs and each job is processed by a worker of the pool, we'll go on with collecting the responses.

### collect_job_responses/1

```elixir
defp collect_job_responses(range) do
  Enum.map(range, fn(_) -> get_job_response() end)
end

defp get_job_response() do
  receive do
    {:ok, response} -> response
  end
end
```

We iterate over the range to run `receive` as many times as spawned jobs. Each spawned job will call `send` to provide the caller with the response. In `collect_job_responses/1` we simply collect the responses of all ran jobs using `Enum.map/2`.

## Conclusion

Combining the 3 techniques is not trivial when you're learning Elixir! I hope this example will help some of you.

There is a lot to improve, so do not hesitate to share your comments or your own articles and examples. And if you wish to contribute to this article and the example code, feel free to submit issues / pull requests on the [Github repository](https://github.com/rchampourlier/elixir-concurrency-in-pool-example)!

## Playing with the example

```shell
bin/console
iex(1)> ElixirConcurrencyInPoolExample.run(1..5)
Job 1 enqueued
Job 2 enqueued
Job 3 enqueued
Job 2 starting (sleeping 500 ms)
Job 1 starting (sleeping 500 ms)
Job 4 enqueued
Job 5 enqueued
Job 2 done
Job 1 done
Job 3 starting (sleeping 500 ms)
Job 4 starting (sleeping 500 ms)
Job 3 done
Job 4 done
Job 5 starting (sleeping 500 ms)
Job 5 done
[2, 1, 3, 4, 5]
```

We can see that only 2 jobs get processed at the same time while the other remain pending until the workers in the pool are available. The results of each worker operation are collected and returned once all operations have been performed.
