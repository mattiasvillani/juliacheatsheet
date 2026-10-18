---
title: Parallel computing
toc: true
---

# Parallel computing

Julia has three main ways to use more hardware: **threads** (shared memory, one process), **distributed processes** (separate memory, can span machines) and **GPUs**. Threads are usually the place to start. The examples were run with 4 threads (`julia --threads=4`); timings depend on the machine.

<div class="cheatbox jl-slate">

## Starting Julia with threads

The number of threads is fixed when Julia starts.

```julia
Threads.nthreads()              # threads available (1 by default)
# start Julia with:  julia --threads=auto   or  julia -t 8
# or set:            export JULIA_NUM_THREADS=8
# in VS Code:        setting "julia.NumThreads"
Sys.CPU_THREADS                 # logical cores on this machine
using LinearAlgebra
BLAS.get_num_threads()          # BLAS (matrix products) has its own threads
```

Do not combine many Julia threads with many BLAS threads on the same cores: when your threads call linear algebra, set `BLAS.set_num_threads(1)`.

<details class="example">
<summary>Example</summary>

Check the setup at the start of a script, and see which threads run which loop iterations.

```julia
println("Julia threads: ", Threads.nthreads(), "   cores: ", Sys.CPU_THREADS)

owner = zeros(Int, 12)
Threads.@threads :static for i in 1:12
    owner[i] = Threads.threadid()
end
owner                            # :static gives each thread a contiguous block
```

```text
Julia threads: 4   cores: 16
12-element Vector{Int64}:
 2
 2
 2
 3
 3
 3
 4
 4
 4
 5
 5
 5
```

</details>
</div>

<div class="cheatbox jl-slate">

## Parallel loops with `@threads`

Splits the iterations of a `for` loop over the threads. Each iteration must be independent and write to its own place.

```julia
n = 10
out = zeros(n)
Threads.@threads for i in 1:n
    out[i] = sum(sqrt, 1:i)       # each iteration writes its own element
end
out
```

Schedulers: `@threads :dynamic` (default, one block per thread), `:static` (fixed blocks, pinned to threads) and `:greedy` (Julia 1.11+, one iteration at a time: best when iterations take very different times). Never use `Threads.threadid()` to index per-thread buffers: tasks can move between threads.

<details class="example">
<summary>Example</summary>

A simulation study: estimate the coverage of a 95% t-interval for several sample sizes, split into 96 batch jobs. Each job has its own seeded random number generator, so results do not depend on the number of threads. The jobs for large n take much longer, which matters for how the loop is scheduled.

```julia
using Random, Statistics

function coverage(n, nrep, seed)
    rng = Xoshiro(seed)
    x = zeros(n)                            # one buffer, reused: no allocation in the loop
    hits = 0
    for _ in 1:nrep
        randexp!(rng, x)                    # true mean 1, skewed data
        m, s = mean(x), std(x)
        hits += abs(m - 1) <= 2.0 * s / sqrt(n)
    end
    return hits / nrep
end

jobs = [(n, seed) for n in [5, 10, 20, 40, 80, 160] for seed in 1:16]

run_serial(jobs) = [coverage(n, 2_000, seed) for (n, seed) in jobs]

function run_default(jobs)                  # pass jobs as an argument, not a global
    out = zeros(length(jobs))
    Threads.@threads for k in eachindex(jobs)
        n, seed = jobs[k]
        out[k] = coverage(n, 2_000, seed)
    end
    return out
end

function run_greedy(jobs)
    out = zeros(length(jobs))
    Threads.@threads :greedy for k in eachindex(jobs)
        n, seed = jobs[k]
        out[k] = coverage(n, 2_000, seed)
    end
    return out
end

run_serial(jobs) == run_default(jobs) == run_greedy(jobs)   # same seeds, same answers
```

```text
true
```

```julia
t = [minimum(@elapsed(f(jobs)) for _ in 1:5) for f in (run_serial, run_default, run_greedy)]
println("speed-up with ", Threads.nthreads(), " threads:  default ",
        round(t[1] / t[2], digits = 1), "×   :greedy ", round(t[1] / t[3], digits = 1), "×")
```

```text
speed-up with 4 threads:  default 1.6×   :greedy 3.3×
```

The default scheduler gives each thread one contiguous block of iterations, and the last block holds all the slow n = 80 and n = 160 jobs. `:greedy` hands out iterations one at a time to whichever thread is free. Shuffling the jobs would also help.

```julia
res = run_greedy(jobs)
[(n = n, coverage = round(mean(res[[j[1] == n for j in jobs]]), digits = 3)) for n in (5, 20, 80, 160)]
```

```text
4-element Vector{@NamedTuple{n::Int64, coverage::Float64}}:
 (n = 5, coverage = 0.82)
 (n = 20, coverage = 0.91)
 (n = 80, coverage = 0.941)
 (n = 160, coverage = 0.95)
```

</details>
</div>

<div class="cheatbox jl-slate">

## Tasks: `@spawn` and `fetch`

`Threads.@spawn` starts a task on any free thread and returns at once. `fetch` waits for its result.

```julia
t = Threads.@spawn sum(abs2, randn(10^6))   # runs in the background
fetch(t)                                    # wait and get the result
tasks = [Threads.@spawn(i^2) for i in 1:4]
fetch.(tasks)                               # [1, 4, 9, 16]
@sync begin                                 # wait for everything inside
    Threads.@spawn println("task A")
    Threads.@spawn println("task B")
end
```

Tasks suit uneven work, such as MCMC chains that take different times. Errors inside a task appear when you `fetch` or `wait` it.

<details class="example">
<summary>Example</summary>

Run four MCMC chains at the same time, one task per chain, each with its own seeded generator.

```julia
using Random, Statistics

function rwm(logpost, θ0, nIter; step = 1.0, seed = 1)
    rng = Xoshiro(seed)
    θ, lp = θ0, logpost(θ0)
    draws = zeros(nIter)
    for i in 1:nIter
        prop = θ + step * randn(rng)
        lpprop = logpost(prop)
        if log(rand(rng)) < lpprop - lp
            θ, lp = prop, lpprop
        end
        draws[i] = θ
    end
    return draws
end

logpost(θ) = -0.5 * (θ - 3)^2 / 0.5^2           # N(3, 0.5²) target
starts = [-10.0, 0.0, 10.0, 20.0]

tasks = [Threads.@spawn rwm(logpost, starts[c], 50_000; step = 1.2, seed = c) for c in 1:4]
chains = fetch.(tasks)                           # Vector of 4 draw vectors

[(start = starts[c], mean = round(mean(chains[c][1001:end]), digits = 3),
  sd = round(std(chains[c][1001:end]), digits = 3)) for c in 1:4]
```

```text
4-element Vector{@NamedTuple{start::Float64, mean::Float64, sd::Float64}}:
 (start = -10.0, mean = 3.005, sd = 0.5)
 (start = 0.0, mean = 2.999, sd = 0.493)
 (start = 10.0, mean = 3.001, sd = 0.504)
 (start = 20.0, mean = 2.998, sd = 0.504)
```

</details>
</div>

<div class="cheatbox jl-slate">

## Reductions and data races

Updating one shared variable from several threads gives wrong answers. Give each chunk of work its own partial result, then combine.

```julia
x = rand(10^6)
s = 0.0
Threads.@threads for i in eachindex(x)
    global s += x[i]                # WRONG: data race, lost updates
end
chunks = Iterators.partition(eachindex(x), cld(length(x), Threads.nthreads()))
partials = map(chunks) do idx
    Threads.@spawn sum(@view x[idx])
end
sum(fetch.(partials)) ≈ sum(x)      # true: one partial sum per task
acc = Threads.Atomic{Float64}(0.0)
Threads.atomic_add!(acc, 1.5)       # atomic update: safe, but slow if frequent
results, lk = Float64[], ReentrantLock()
Threads.@threads for i in 1:4
    r = sqrt(i)                     # compute in parallel...
    lock(lk) do                     # ...but push! one thread at a time
        push!(results, r)
    end
end
```

<details class="example">
<summary>Example</summary>

Count Monte Carlo hits inside the unit circle (to estimate π): the racy version loses updates; chunked partial sums and atomics are correct.

```julia
using Random

n = 4_000_000
pts = rand(Xoshiro(1), 2, n)
inside(i) = pts[1, i]^2 + pts[2, i]^2 <= 1

function racy(n)
    count = Ref(0)
    Threads.@threads for i in 1:n
        count[] += inside(i)                     # read-modify-write race
    end
    return count[]
end

function chunked(n)
    chunks = Iterators.partition(1:n, cld(n, Threads.nthreads()))
    tasks = [Threads.@spawn count(inside, c) for c in chunks]
    return sum(fetch.(tasks))
end

function atomic(n)
    count = Threads.Atomic{Int}(0)
    Threads.@threads for i in 1:n
        inside(i) && Threads.atomic_add!(count, 1)
    end
    return count[]
end

exact = count(inside, 1:n)
(exact = exact, racy = racy(n), chunked = chunked(n), atomic = atomic(n))
```

```text
(exact = 3142008, racy = 915175, chunked = 3142008, atomic = 3142008)
```

```julia
4 * chunked(n) / n          # estimate of π
```

```text
3.142008
```

</details>
</div>

<div class="cheatbox jl-slate">

## OhMyThreads.jl: parallel map and reduce

Ready-made threaded versions of `map`, `mapreduce` and `foreach`, with chunking done for you.

```julia
using OhMyThreads
tmap(x -> x^2, 1:5)                   # [1, 4, 9, 16, 25]
tmapreduce(x -> x^2, +, 1:10)         # 385
treduce(+, 1:100)                     # 5050
tforeach(1:3) do i
    println("item ", i)
end
tmap(x -> 2x, 1:100; ntasks = 4)      # control the number of tasks
@tasks for i in 1:3                   # macro form of a parallel loop
    println(i^2)
end
```

`] add OhMyThreads`. Prefer it over hand-written chunking for most map/reduce work.

<details class="example">
<summary>Example</summary>

A parallel bootstrap of a correlation coefficient with `tmap`. Seeds are tied to replicate numbers, so the result does not depend on the number of threads.

```julia
using OhMyThreads, Random, Statistics

rng = Xoshiro(3)
n = 200
x = randn(rng, n)
y = 0.6 .* x .+ 0.8 .* randn(rng, n)

function boot_cor(b)
    r = Xoshiro(b)                    # one generator per replicate
    idx = rand(r, 1:n, n)
    return cor(x[idx], y[idx])
end

B = 20_000
boot = tmap(boot_cor, 1:B)
serial = map(boot_cor, 1:B)
boot == serial, cor(x, y), quantile(boot, [0.025, 0.975])
```

```text
(true, 0.6615350698281041, [0.5756093443936076, 0.7352853142953062])
```

```julia
t1 = minimum(@elapsed(map(boot_cor, 1:B)) for _ in 1:3)
t4 = minimum(@elapsed(tmap(boot_cor, 1:B)) for _ in 1:3)
println("speed-up: ", round(t1 / t4, digits = 1), "×")
```

```text
speed-up: 2.1×
```

The speed-up is modest because every replicate allocates new arrays, and all threads share one garbage collector. Code that allocates little in the inner loop scales much better.

</details>
</div>

<div class="cheatbox jl-slate">

## Distributed computing: separate processes

Worker processes have their own memory, so code and data must be sent to them. They can run on other machines.

```julia
using Distributed
addprocs(4)                     # start 4 local workers (julia -p 4 does the same)
nworkers(), workers()           # (4, [2, 3, 4, 5])
@everywhere using Statistics    # load packages on every worker
@everywhere f(x) = x^2          # define functions on every worker
pmap(f, 1:10)                   # parallel map, good for slow, uneven tasks
@distributed (+) for i in 1:1000
    f(i)                        # parallel loop with a reduction
end
r = remotecall(rand, 2, 3)      # run rand(3) on worker 2
fetch(r)
rmprocs(workers())              # stop the workers
```

On a SLURM cluster, `SlurmClusterManager.jl` starts workers across nodes inside a job. For many independent runs, a SLURM job array of separate Julia scripts is often simpler.

<details class="example">
<summary>Example</summary>

A simulation study across worker processes with `pmap`: each parameter setting is one task.

```julia
using Distributed
addprocs(4)

@everywhere using Random, Statistics

@everywhere function mse_of_median(n, seed)
    rng = Xoshiro(seed)
    est = [median(randn(rng, n)) for _ in 1:20_000]
    return (n = n, mse = mean(abs2, est), worker = myid())
end

settings = [10, 20, 40, 80, 160, 320]
res = pmap(i -> mse_of_median(settings[i], i), eachindex(settings))
```

```text
6-element Vector{@NamedTuple{n::Int64, mse::Float64, worker::Int64}}:
 (n = 10, mse = 0.13947509530645374, worker = 6)
 (n = 20, mse = 0.07262612423029957, worker = 7)
 (n = 40, mse = 0.03814923323415664, worker = 8)
 (n = 80, mse = 0.019076740752195776, worker = 9)
 (n = 160, mse = 0.009806091456607194, worker = 7)
 (n = 320, mse = 0.004858437254309016, worker = 8)
```

```julia
# theory: Var(median) ≈ π / (2n) for normal data
[(n = r.n, mse = round(r.mse, sigdigits = 3), theory = round(π / (2r.n), sigdigits = 3)) for r in res]
```

```text
6-element Vector{@NamedTuple{n::Int64, mse::Float64, theory::Float64}}:
 (n = 10, mse = 0.139, theory = 0.157)
 (n = 20, mse = 0.0726, theory = 0.0785)
 (n = 40, mse = 0.0381, theory = 0.0393)
 (n = 80, mse = 0.0191, theory = 0.0196)
 (n = 160, mse = 0.00981, theory = 0.00982)
 (n = 320, mse = 0.00486, theory = 0.00491)
```

```julia
rmprocs(workers())
nprocs()
```

```text
1
```

</details>
</div>

<div class="cheatbox jl-slate">

## Before parallelizing: fast serial code

Parallelism multiplies serial speed, so first make one core fast: avoid allocations in loops, use views, and help the compiler vectorize.

```julia
function mysum(x)
    s = zero(eltype(x))
    @inbounds @simd for i in eachindex(x)    # allow SIMD reordering
        s += x[i]
    end
    return s
end
x = rand(10^6)
mysum(x) ≈ sum(x)                 # true
y = similar(x)
@. y = 2x + sin(x)                # fused broadcast: one loop, no temporaries
@views sum(x[1:10])               # slices as views
```

`@simd` lets the compiler reorder floating-point additions, so results can differ in the last digits.

<details class="example">
<summary>Example</summary>

The effect of `@simd`, and of avoiding temporary arrays, on a single thread.

```julia
function plain_sum(x)
    s = 0.0
    for i in eachindex(x)
        s += x[i]
    end
    return s
end

function simd_sum(x)
    s = 0.0
    @inbounds @simd for i in eachindex(x)
        s += x[i]
    end
    return s
end

x = rand(10^7)
plain_sum(x); simd_sum(x)                                # compile first
t_plain = minimum(@elapsed(plain_sum(x)) for _ in 1:5)
t_simd = minimum(@elapsed(simd_sum(x)) for _ in 1:5)
println("@simd is ", round(t_plain / t_simd, digits = 1), "× faster")
```

```text
@simd is 1.5× faster
```

```julia
y = similar(x)
unfused(x) = 2 .* x .+ sin.(x)         # one loop, but allocates the result
fused!(y, x) = (@. y = 2x + sin(x))    # writes into y
unfused(x); fused!(y, x)
@allocated(unfused(x)), @allocated(fused!(y, x))
```

```text
(80003072, 0)
```

</details>
</div>

<div class="cheatbox jl-slate">

## GPU computing with CUDA.jl

Move arrays to the GPU, then use ordinary array code: broadcasts, reductions and linear algebra run on the GPU. Needs an NVIDIA GPU. (Not run when building this page.)

```julia norun
using CUDA                       # ] add CUDA; downloads the CUDA toolkit
CUDA.functional()                # true if a usable GPU is found
x = cu(rand(10^6))               # copy to the GPU (as Float32)
y = CUDA.rand(Float32, 10^6)     # create directly on the GPU
z = 2 .* x .+ sin.(y)            # runs on the GPU
sum(z), maximum(z)               # GPU reductions
A = CUDA.randn(Float32, 1000, 1000)
B = A * A'                       # cuBLAS matrix product
Array(B)                         # copy back to the CPU
CUDA.@allowscalar x[1]           # scalar indexing is disallowed by default
CUDA.@time A * A'                # time GPU work (includes synchronization)
```

Use `Float32`: consumer GPUs are much slower in `Float64`. Avoid `x[i]` loops on GPU arrays; write whole-array operations. Apple GPUs use `Metal.jl` (`MtlArray`), AMD GPUs `AMDGPU.jl` (`ROCArray`).

<details class="example">
<summary>Example</summary>

Many independent random-walk Metropolis chains at once on the GPU, all chains updated in one broadcast per iteration. (Not run here: no working GPU on the build machine.)

```julia norun
using CUDA

logpost(θ) = -0.5f0 * (θ - 3f0)^2 / 0.25f0         # N(3, 0.5²) target

nchains, niter = 100_000, 2_000
θ = CUDA.zeros(Float32, nchains)
lp = logpost.(θ)
for _ in 1:niter
    prop = θ .+ 1.2f0 .* CUDA.randn(Float32, nchains)
    lpprop = logpost.(prop)
    accept = log.(CUDA.rand(Float32, nchains)) .< lpprop .- lp
    θ = ifelse.(accept, prop, θ)
    lp = ifelse.(accept, lpprop, lp)
end
θcpu = Array(θ)                  # final state of every chain
sum(θcpu) / nchains              # ≈ 3
```

</details>
</div>

<div class="cheatbox jl-slate">

## Portable GPU kernels: KernelAbstractions.jl

Write a kernel once and run it on CPU threads, NVIDIA, AMD, Intel or Apple GPUs by changing the backend.

```julia
using KernelAbstractions
@kernel function saxpy!(y, a, @Const(x))
    i = @index(Global)              # this work item's index
    @inbounds y[i] = a * x[i] + y[i]
end
x = ones(Float32, 8); y = fill(2f0, 8)
backend = get_backend(y)            # CPU backend for Array; CUDABackend() for CuArray
kernel! = saxpy!(backend)
kernel!(y, 3f0, x; ndrange = length(y))
KernelAbstractions.synchronize(backend)
y                                   # all 5.0
```

Kernels run asynchronously: call `synchronize` before using the result. With `using CUDA`, the same kernel runs on `CuArray`s unchanged.

<details class="example">
<summary>Example</summary>

A kernel that evaluates a Gaussian log-likelihood at many parameter values at once, run on the CPU here. On a GPU, only the array type changes.

```julia
using KernelAbstractions

@kernel function loglik_grid!(ll, @Const(μs), @Const(σs), @Const(y))
    j = @index(Global)
    μ, σ = μs[j], σs[j]
    s = zero(eltype(ll))
    for i in eachindex(y)
        s += -log(σ) - (y[i] - μ)^2 / (2σ^2)
    end
    ll[j] = s
end

y = Float32[2.1, 3.4, 1.9, 2.8, 2.5]
μs = Float32.(repeat(range(1, 4, length = 61), outer = 41))
σs = Float32.(repeat(range(0.2, 2, length = 41), inner = 61))
ll = similar(μs)

backend = get_backend(ll)
loglik_grid!(backend)(ll, μs, σs, y; ndrange = length(ll))
KernelAbstractions.synchronize(backend)

j = argmax(ll)
(μ = μs[j], σ = σs[j], loglik = ll[j])          # grid maximum ≈ MLE
```

```text
(μ = 2.55f0, σ = 0.515f0, loglik = 0.655108f0)
```

```julia
# the MLE in closed form, for comparison
n = length(y)
(μ = sum(y) / n, σ = sqrt(sum(abs2, y .- sum(y) / n) / n))
```

```text
(μ = 2.54f0, σ = 0.53141326f0)
```

On an NVIDIA GPU the same kernel call works after `using CUDA` and `μs, σs, y, ll = cu.((μs, σs, y, ll))`.

</details>
</div>
