---
title: Functions
toc: true
---

# Functions

<div class="cheatbox jl-magenta">

## Defining functions

The value of the last expression is returned, so `return` is optional. Functions return several values as a tuple.

```julia
function f(x, y)
    z = x + y
    return 2z            # explicit return
end
g(x) = x^2 + 1           # one-line form
h = x -> x^2 + 1         # anonymous function
sumprod(a, b) = (a + b, a * b)   # return a tuple
s, p = sumprod(2, 3)     # destructure: s = 5, p = 6
f(1, 2), g(3), h(3)      # (6, 10, 10)
```

Mutating functions end in `!` by convention, e.g. `sort!(v)` sorts in place and `sort(v)` returns a copy. They usually change their first argument.

<details class="example">
<summary>Example</summary>

A function that returns several summaries as a named tuple, and a mutating version that standardises in place.

```julia
using Statistics

function describe(x)
    m, s = mean(x), std(x)
    return (mean = m, sd = s, cv = s / m)
end

function standardize!(x)
    m, s = mean(x), std(x)
    x .= (x .- m) ./ s
    return x
end

x = [2.0, 4.0, 4.0, 5.0, 7.0, 8.0]
d = describe(x)
println(d)
println("cv = ", round(d.cv; digits = 3))
standardize!(x)
println("standardized: ", round.(x; digits = 3))
```

```text
(mean = 5.0, sd = 2.1908902300206643, cv = 0.43817804600413285)
cv = 0.438
standardized: [-1.369, -0.456, -0.456, 0.0, 0.913, 1.369]
```

</details>
</div>

<div class="cheatbox jl-magenta">

## Default, keyword and variable arguments

Keyword arguments come after `;` in the definition. In a call the `;` is optional.

```julia
pow(x, p = 2) = x^p               # default positional argument
pow(3), pow(3, 3)                 # (9, 27)
function sim(n; mu = 0.0, sigma = 1.0)   # keyword arguments
    mu .+ sigma .* randn(n)
end
sim(5; sigma = 2)                 # or sim(5, sigma = 2)
sigma = 3; sim(5; sigma)          # same as sigma = sigma
total(xs...) = sum(xs)            # varargs: xs is a tuple
total(1, 2, 3)                    # 6
v = [1, 2, 3]; total(v...)        # 6   splat a collection into arguments
opts = (mu = 1.0, sigma = 0.5); sim(3; opts...)   # splat keywords
```

Dispatch uses only positional arguments, never keyword arguments.

<details class="example">
<summary>Example</summary>

A random walk Metropolis sampler whose tuning settings are keyword arguments with defaults.

```julia
using Random

function rwm(logpost, θ0; n = 5000, step = 1.0, rng = Random.default_rng())
    θ, lp = θ0, logpost(θ0)
    draws = zeros(n)
    accepted = 0
    for i in 1:n
        θp = θ + step * randn(rng)
        lpp = logpost(θp)
        if log(rand(rng)) < lpp - lp
            θ, lp = θp, lpp
            accepted += 1
        end
        draws[i] = θ
    end
    return draws, accepted / n
end

logpost(θ) = -0.5 * (θ - 3)^2 / 0.5^2     # N(3, 0.5²)
for step in (0.1, 1.0, 10.0)
    draws, acc = rwm(logpost, 0.0; step, rng = Xoshiro(1))
    println("step = $step: acceptance = $(round(acc; digits = 2)), mean = $(round(sum(draws[1001:end]) / 4000; digits = 2))")
end
```

```text
step = 0.1: acceptance = 0.93, mean = 2.96
step = 1.0: acceptance = 0.51, mean = 2.99
step = 10.0: acceptance = 0.06, mean = 3.02
```

</details>
</div>

<div class="cheatbox jl-magenta">

## Multiple dispatch

A function can have many methods. Julia picks the most specific method for the types of **all** the arguments.

```julia
area(r::Real) = π * r^2                  # circle
area(w::Real, h::Real) = w * h           # rectangle
describe(x::Integer) = "integer"
describe(x::AbstractFloat) = "float"
describe(x) = "something else"           # fallback, x::Any
describe(1), describe(1.0), describe("a")   # ("integer", "float", "something else")
methods(describe)                        # list the 3 methods
@which describe(1)                       # the method that is called
combine(x::Int, y::Float64) = 1
combine(x::Float64, y::Int) = 2          # dispatch on both arguments
```

Type annotations on arguments are for dispatch, not speed: the compiler specializes on the actual types anyway.

<details class="example">
<summary>Example</summary>

Log densities as methods of one function, dispatching on our own distribution types.

```julia
struct Normal1; μ::Float64; σ::Float64; end
struct Exponential1; λ::Float64; end

logdensity(d::Normal1, x) = -0.5 * log(2π) - log(d.σ) - 0.5 * ((x - d.μ) / d.σ)^2
logdensity(d::Exponential1, x) = x < 0 ? -Inf : log(d.λ) - d.λ * x
loglik(d, data::AbstractVector) = sum(x -> logdensity(d, x), data)   # works for both

data = [0.5, 1.2, 0.3, 2.2, 0.9]
for d in (Normal1(1, 1), Exponential1(1), Exponential1(1 / 1.02))
    println(rpad(string(d), 32), round(loglik(d, data); digits = 3))
end
```

```text
Normal1(1.0, 1.0)  -5.71
Exponential1(1.0)  -5.1
Exponential1(0.9803921568627451)-5.099
```

</details>
</div>

<div class="cheatbox jl-magenta">

## Broadcasting with dot syntax

`f.(x)` applies `f` to each element. Dotted operators `.+ .* .^` work elementwise and fuse into one loop.

```julia
x = [1.0, 2.0, 3.0]
sqrt.(x)               # [1.0, 1.414, 1.732]
x .^ 2 .+ 1            # [2.0, 5.0, 10.0]
@. x^2 + 2x            # [3.0, 8.0, 15.0]   @. dots everything
x .+ [10 20]           # 3×2 Matrix: shapes are expanded
max.(x, 2)             # [2.0, 2.0, 3.0]    scalars are reused
y = similar(x); y .= x .* 2   # write into an existing array
startswith.(["ab", "ba"], Ref("a"))   # [true, false]  Ref: treat as scalar
```

Your own functions broadcast with no extra code: define `f(x::Real)` and call `f.(v)`.

<details class="example">
<summary>Example</summary>

Evaluate a normal density on a grid of points and parameters in one broadcast.

```julia
dnorm(x, μ, σ) = exp(-0.5 * ((x - μ) / σ)^2) / (σ * sqrt(2π))

x = -2:1.0:2
μ = [0.0 1.0]                 # a row: one column per mean
dens = dnorm.(x, μ, 1.0)      # 5×2 matrix
display(round.(dens; digits = 4))

z = zeros(length(x))
z .= dnorm.(x, 0.0, 1.0) .* 2   # fused, writes into z, no temporary arrays
println(z == 2 .* dens[:, 1])
```

```text
5×2 Matrix{Float64}:
 0.054   0.0044
 0.242   0.054
 0.3989  0.242
 0.242   0.3989
 0.054   0.242
true
```

</details>
</div>

<div class="cheatbox jl-magenta">

## Higher-order functions

Functions are values: pass them to functions and return them.

```julia
map(x -> x^2, 1:3)                 # [1, 4, 9]
filter(iseven, 1:6)                # [2, 4, 6]
reduce(+, 1:4)                     # 10
foldl((acc, x) -> 10acc + x, [1, 2, 3])   # 123
sum(abs2, [1, -2, 3])              # 14   many reducers take a function first
count(>(2), [1, 3, 5])             # 2    >(2) is the function x -> x > 2
findall(==(0), [0, 1, 0])          # [1, 3]
sort(["bb", "a", "ccc"]; by = length, rev = true)   # ["ccc", "bb", "a"]
any(isnan, [1.0, NaN]), all(>(0), [1, 2])          # (true, true)
```

<details class="example">
<summary>Example</summary>

Composing numerical tools from functions: a derivative by finite differences and Newton's method that takes the function as an argument.

```julia
deriv(f; h = 1e-6) = x -> (f(x + h) - f(x - h)) / 2h   # returns a function

function newton(f, x; tol = 1e-10, maxit = 50)
    df = deriv(f)
    for i in 1:maxit
        step = f(x) / df(x)
        x -= step
        abs(step) < tol && return (root = x, iterations = i)
    end
    error("no convergence")
end

println(newton(x -> x^2 - 2, 1.0))
println(newton(cos, 1.0))
println(map(f -> newton(f, 1.0).root, [x -> x^3 - 2, x -> exp(x) - 3]))
```

```text
(root = 1.4142135623730951, iterations = 5)
(root = 1.5707963267948966, iterations = 4)
[1.2599210498948732, 1.0986122886681096]
```

</details>
</div>

<div class="cheatbox jl-magenta">

## `do` blocks, pipes and composition

A `do` block passes an anonymous function as the **first** argument.

```julia
map([1, 2, 3]) do x       # same as map(x -> 2x + 1, [1, 2, 3])
    2x + 1
end                       # [3, 5, 7]
open("out.txt", "w") do io   # the file is closed even after an error
    println(io, "hello")
end
[1, 4, 9] |> sum |> sqrt  # 3.7416573867739413   pipe: sqrt(sum(x))
(sqrt ∘ sum)([1, 4, 9])   # same, ∘ is \circ<tab>
[1, 4, 9] .|> sqrt        # [1.0, 2.0, 3.0]  broadcast pipe
```

<details class="example">
<summary>Example</summary>

`do` blocks with `filter`, `mapreduce` and `cd`, and a pipeline of small functions.

```julia
words = ["julia", "is", "fast", "and", "dynamic"]
long = filter(words) do w
    length(w) > 3 && w != "julia"
end
println(long)

total = mapreduce(+, words) do w
    count(in("aeiou"), w)
end
println("vowels: ", total)

cd(mktempdir()) do
    write("a.txt", "1\n2\n3\n")
    readlines("a.txt") .|> (s -> parse(Int, s)) |> sum |> println
end
```

```text
["fast", "dynamic"]
vowels: 8
6
```

</details>
</div>

<div class="cheatbox jl-magenta">

## Closures and functors

A closure captures variables from where it was defined. A functor is a struct that can be called like a function.

```julia
make_loglik(y) = μ -> -0.5 * sum((y .- μ) .^ 2)   # captures the data y
ll = make_loglik([1.0, 2.0, 3.0])
ll(2.0)                                         # -1.0
struct Affine; a::Float64; b::Float64; end
(f::Affine)(x) = f.a * x + f.b                   # make Affine callable
f = Affine(2, 1); f(3)                           # 7.0
```

A closure that reassigns a captured variable (`n += 1` on a captured `n`) puts `n` in a box and can be slow in hot loops.

<details class="example">
<summary>Example</summary>

Build a log posterior from data and pass it as a plain function of the parameter to a grid evaluation.

```julia
y = [4.2, 5.1, 3.9, 4.8, 5.5]
function make_logpost(y; μ0 = 0.0, τ0 = 10.0, σ = 1.0)
    return μ -> -0.5 * ((μ - μ0) / τ0)^2 - 0.5 * sum(((y .- μ) ./ σ) .^ 2)
end
logpost = make_logpost(y)

grid = 3.5:0.05:6.0
lp = logpost.(grid)
w = exp.(lp .- maximum(lp)); w ./= sum(w)
μhat = sum(grid .* w)
println("posterior mean ≈ ", round(μhat; digits = 3), ", sample mean = ", sum(y) / length(y))
```

```text
posterior mean ≈ 4.693, sample mean = 4.7
```

</details>
</div>
