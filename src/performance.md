---
title: Performance
toc: true
---

# Performance

<div class="cheatbox jl-indigo">

## Timing code

The first call of a function includes compilation, so time the second call. BenchmarkTools runs the code many times and reports the minimum or a distribution.

```julia
using BenchmarkTools
f(x) = sum(abs2, x)
x = randn(10^6)
@time f(x)                 # time, allocations and % compilation of one call
@elapsed f(x)              # seconds as a number
@allocated f(x)            # bytes allocated
@btime f($x)               # minimum time over many runs; $ interpolates x
@benchmark f($x)           # histogram, mean, median, GC time
```

Without `$`, `x` is an untyped global and the benchmark includes the cost of looking it up.

<details class="example">
<summary>Example</summary>

The first `@time` includes compilation. `@btime` reports the minimum.

```julia
using BenchmarkTools
logsumexp(x) = (m = maximum(x); m + log(sum(exp.(x .- m))))
x = randn(10_000)
@time logsumexp(x)
@time logsumexp(x)
@btime logsumexp($x)
t = @belapsed logsumexp($x)
println("about ", round(t * 1e9 / length(x); digits = 2), " ns per element")
```

```text
  0.059715 seconds (187.70 k allocations: 9.333 MiB, 99.81% compilation time)
  0.000083 seconds (4 allocations: 78.211 KiB)
  46.915 μs (3 allocations: 78.20 KiB)
about 4.69 ns per element
```

</details>
</div>

<div class="cheatbox jl-indigo">

## Type stability

A function is type stable if the type of its result depends only on the types of its arguments. Then the compiler can generate fast specialised code.

```julia
unstable(x) = x > 0 ? x : 0         # Int 0 for a Float64 x: returns Union{Float64, Int}
stable(x) = x > 0 ? x : zero(x)     # same type as x
@code_warntype unstable(1.0)        # red Union / Any marks the problem
function sumsq(v)
    s = 0                           # Int, then Float64 after the first +=
    for x in v; s += x^2; end
    s
end
# fix: s = zero(eltype(v))
```

Use `zero(x)`, `one(x)`, `similar(x)` and `eltype(x)` to make literals and arrays match the input types.

<details class="example">
<summary>Example</summary>

The initial value `0` makes the accumulator a `Union{Float64, Int64}`. Julia handles small unions well (union splitting), so here the cost is negligible. Instability is expensive when inference gives up and returns `Any`, as with the untyped global and abstract fields in the next box.

```julia
using BenchmarkTools, InteractiveUtils

function sumsq_bad(v)
    s = 0
    for x in v
        s += x^2
    end
    return s
end
function sumsq_good(v)
    s = zero(eltype(v))
    for x in v
        s += x^2
    end
    return s
end

v = randn(10^6)
@btime sumsq_bad($v)
@btime sumsq_good($v)
println(Base.return_types(sumsq_bad, (Vector{Float64},)))
println(Base.return_types(sumsq_good, (Vector{Float64},)))
```

```text
  871.647 μs (0 allocations: 0 bytes)
  871.652 μs (0 allocations: 0 bytes)
Any[Union{Float64, Int64}]
Any[Float64]
```

</details>
</div>

<div class="cheatbox jl-indigo">

## Globals and containers with abstract types

Global variables can change type at any time, so code that uses them is slow. The same goes for arrays and struct fields with abstract element types.

```julia
x = 1.0                  # untyped global: slow inside functions that read it
const C = 2.0            # constant global: fast
y::Float64 = 1.0         # typed global: fast enough
v = Any[1.0, 2.0]        # Vector{Any}: every element is boxed
w = Float64[]            # concrete element type: fast
struct Slow; a::Real; end              # abstract field type
struct Fast{T<:Real}; a::T; end        # parametric: concrete for each T
f(data) = sum(data)      # pass data as arguments rather than using globals
```

<details class="example">
<summary>Example</summary>

The same loop over an untyped global, a `const` global and an argument.

```julia
using BenchmarkTools
data = randn(10^5)
const cdata = randn(10^5)

function total_global()
    s = 0.0
    for x in data; s += x; end
    return s
end
function total_const()
    s = 0.0
    for x in cdata; s += x; end
    return s
end
function total_arg(d)
    s = 0.0
    for x in d; s += x; end
    return s
end

@btime total_global()
@btime total_const()
@btime total_arg($data)

struct PointAbstract; x::Real; y::Real; end
struct PointConcrete{T<:Real}; x::T; y::T; end
pa = [PointAbstract(randn(), randn()) for _ in 1:10^5]
pc = [PointConcrete(randn(), randn()) for _ in 1:10^5]
@btime sum(p -> p.x * p.y, $pa)
@btime sum(p -> p.x * p.y, $pc);
```

```text
  6.529 ms (399490 allocations: 7.62 MiB)
  87.177 μs (0 allocations: 0 bytes)
  87.180 μs (0 allocations: 0 bytes)
  3.257 ms (199999 allocations: 3.05 MiB)
  29.389 μs (0 allocations: 0 bytes)
```

</details>
</div>

<div class="cheatbox jl-indigo">

## Avoiding allocations

Allocating new arrays in a hot loop costs time and garbage collection. Preallocate, write in place, and use views.

```julia
using LinearAlgebra
x = randn(3); A = randn(3, 3); F = lu(A); b = randn(3)
y = similar(x)               # allocate once, reuse
y .= 2 .* x .+ 1             # in place: no new array
mul!(y, A, x)                # y = A * x in place;  mul!(C, A, B) for matrices
ldiv!(F, b)                  # solve with a factorization F, overwriting b
@views s = sum(x[2:end])     # slices become views instead of copies
x[2:end]                     # a copy;  view(x, 2:end) is not
copyto!(y, x)                # copy into an existing array
```

Fewer allocations usually matter more than micro-optimising arithmetic. `@time` shows how many there are.

<details class="example">
<summary>Example</summary>

Iterating `x ← A x / ‖A x‖` (the power method) with a new vector each step, and in place with `mul!`.

```julia
using LinearAlgebra, BenchmarkTools, Random
A = Symmetric(randn(Xoshiro(1), 200, 200))

function power_alloc(A, iters)
    x = ones(size(A, 1))
    for _ in 1:iters
        x = A * x
        x = x / norm(x)
    end
    return dot(x, A * x)
end

function power_inplace(A, iters)
    x = ones(size(A, 1)); y = similar(x)
    for _ in 1:iters
        mul!(y, A, x)
        x .= y ./ norm(y)
    end
    mul!(y, A, x)
    return dot(x, y)
end

println(power_alloc(A, 500) ≈ power_inplace(A, 500))
@btime power_alloc($A, 500)
@btime power_inplace($A, 500);
```

```text
true
  3.121 ms (2004 allocations: 1.59 MiB)
  1.915 ms (4 allocations: 3.25 KiB)
```

</details>
</div>

<div class="cheatbox jl-indigo">

## Memory order and small arrays

Arrays are column-major: loop over the first index in the innermost loop. For small fixed-size vectors and matrices, StaticArrays avoids heap allocation.

```julia
A = zeros(3, 3)
for j in axes(A, 2), i in axes(A, 1)   # i (rows) varies fastest: fast
    A[i, j] += 1
end
using StaticArrays
p = SVector(1.0, 2.0)            # immutable, size in the type, on the stack
R = @SMatrix [0.0 -1.0; 1.0 0.0]
R * p                            # [-2.0, 1.0]  unrolled, no allocation
m = MVector(1.0, 2.0); m[1] = 5  # mutable version
```

StaticArrays pays off up to about 100 elements. Beyond that, compile times grow and plain arrays are as fast.

<details class="example">
<summary>Example</summary>

Row-wise versus column-wise loops, and many 2D rotations with plain vectors versus `SVector`s.

```julia
using BenchmarkTools, StaticArrays

function colsum_rowloop(A)
    s = 0.0
    for i in axes(A, 1), j in axes(A, 2)    # j fastest: jumps through memory
        s += A[i, j]
    end
    s
end
function colsum_colloop(A)
    s = 0.0
    for j in axes(A, 2), i in axes(A, 1)    # i fastest: contiguous
        s += A[i, j]
    end
    s
end
A = randn(2000, 2000)
@btime colsum_rowloop($A)
@btime colsum_colloop($A)

rotate(R, ps) = [R * p for p in ps]
θ = 0.3
R = [cos(θ) -sin(θ); sin(θ) cos(θ)]
Rs = SMatrix{2,2}(R)
ps = [randn(2) for _ in 1:10^4]
sps = [SVector{2}(p) for p in ps]
@btime rotate($R, $ps)
@btime rotate($Rs, $sps);
```

```text
  9.885 ms (0 allocations: 0 bytes)
  3.768 ms (0 allocations: 0 bytes)
  456.944 μs (20003 allocations: 859.45 KiB)
  9.277 μs (3 allocations: 156.32 KiB)
```

</details>
</div>

<div class="cheatbox jl-indigo">

## Profiling

A profiler shows where the time goes. In VS Code, `@profview` draws a flame graph. Wide bars are where the time is spent, and red bars mark type instability.

```julia norun
@profview f(x)               # VS Code: flame graph of one call
@profview_allocs f(x)        # VS Code: where the allocations happen
using Profile
@profile for _ in 1:100; f(x); end
Profile.print(format = :flat, sortedby = :count)   # text report
Profile.clear()
using ProfileView; @profview f(x)   # flame graph outside VS Code
```

Profile code that runs for at least a second, wrapping a fast function in a loop, so the sampler collects enough samples.

<details class="example">
<summary>Example</summary>

A text profile of a small simulation shows that most samples fall in `randn` and the cumulative sum.

```julia norun
using Profile
function sim(n)
    s = 0.0
    for _ in 1:n
        x = cumsum(randn(100))
        s += maximum(x)
    end
    s / n
end
sim(10)                         # compile first
@profile sim(200_000)
Profile.print(format = :flat, sortedby = :count, mincount = 50)
```

</details>
</div>

<div class="cheatbox jl-indigo">

## Performance checklist

The main rules from the Julia manual's performance tips.

```julia norun
# 1. put code in functions; avoid untyped globals (or make them const)
# 2. keep functions type stable; check with @code_warntype or JET.jl's @report_opt
# 3. concrete element types in containers and struct fields
# 4. preallocate and work in place in hot loops: .=, mul!, views
# 5. loop in column-major order; loops are fast, no need to vectorise
# 6. benchmark with @btime f($x), not the first call
# 7. many small fixed-size arrays: StaticArrays
# 8. only then: @inbounds, @simd, @fastmath, threads (see Parallel computing)
```

Loops are fast in Julia, so there is no need to vectorise for speed. One exception: a floating-point sum in a loop is not SIMD-vectorised unless `@simd` allows it to reorder the additions.

<details class="example">
<summary>Example</summary>

A Gaussian log likelihood as a plain loop, a loop with `@simd`, and vectorised code. The `@simd` loop is the fastest and allocates nothing.

```julia
using BenchmarkTools
function loglik_loop(y, μ, σ)
    s = 0.0
    for yi in y
        s += -0.5 * ((yi - μ) / σ)^2
    end
    return s - length(y) * (log(σ) + 0.5 * log(2π))
end
function loglik_simd(y, μ, σ)
    s = 0.0
    @simd for yi in y
        s += -0.5 * ((yi - μ) / σ)^2
    end
    return s - length(y) * (log(σ) + 0.5 * log(2π))
end
loglik_vec(y, μ, σ) = sum(-0.5 .* ((y .- μ) ./ σ) .^ 2) - length(y) * (log(σ) + 0.5 * log(2π))
y = randn(10^5)
println(loglik_loop(y, 0.1, 1.2) ≈ loglik_simd(y, 0.1, 1.2) ≈ loglik_vec(y, 0.1, 1.2))
@btime loglik_loop($y, 0.1, 1.2)
@btime loglik_simd($y, 0.1, 1.2)
@btime loglik_vec($y, 0.1, 1.2);
```

```text
true
  154.497 μs (0 allocations: 0 bytes)
  38.419 μs (0 allocations: 0 bytes)
  61.995 μs (3 allocations: 781.32 KiB)
```

</details>
</div>
