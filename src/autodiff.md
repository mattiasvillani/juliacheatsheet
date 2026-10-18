---
title: Automatic differentiation
toc: true
---

# Automatic differentiation

Automatic differentiation (AD) computes exact derivatives of Julia code. [ForwardDiff.jl](https://juliadiff.org/ForwardDiff.jl/stable/) does forward mode, [Mooncake.jl](https://chalk-lab.github.io/Mooncake.jl/stable/) does reverse mode (and forward), and [DifferentiationInterface.jl](https://juliadiff.org/DifferentiationInterface.jl/DifferentiationInterface/stable/) gives one interface to all AD packages. Install with `] add ForwardDiff Mooncake DifferentiationInterface`.

<div class="cheatbox jl-orange">

## Forward or reverse mode?

For f: ℝⁿ → ℝᵐ, forward mode costs about n evaluations of f and reverse mode about m. A log density has m = 1, so reverse mode wins when there are many parameters.

```julia
using DifferentiationInterface   # exports the backend types below
AutoForwardDiff()       # forward: best for few inputs (n ≲ 50)
AutoMooncake()          # reverse: many inputs, scalar output
AutoMooncakeForward()   # Mooncake's forward mode
AutoZygote(), AutoEnzyme()   # two of many other backends
check_available(AutoMooncake())   # true after using Mooncake
```

Backends are only selectors: the AD package itself must also be loaded with `using`.

<details class="example">
<summary>Example</summary>

Time the gradient of a scalar function as the number of parameters grows. The times depend on the machine, but the trend does not: forward mode gets slower in proportion to n.

```julia
using DifferentiationInterface, ForwardDiff, Mooncake, Random
Random.seed!(1)

println(rpad("n", 8), lpad("ForwardDiff", 14), lpad("Mooncake", 12), lpad("ratio", 9))
for n in (10, 100, 1000, 10_000)
    a = randn(n)
    f(z) = sum(abs2, z .- a) / 2 + sum(log1p.(exp.(z)))
    z = randn(n)
    times = map((AutoForwardDiff(), AutoMooncake())) do backend
        prep = prepare_gradient(f, backend, z)
        gradient(f, prep, backend, z)                       # compile first
        minimum(@elapsed(gradient(f, prep, backend, z)) for _ in 1:5)
    end
    println(rpad(n, 8), lpad(round(times[1] * 1e6, digits = 1), 11), " µs",
            lpad(round(times[2] * 1e6, digits = 1), 9), " µs", lpad(round(times[1] / times[2], digits = 1), 8), "×")
end
```

```text
n          ForwardDiff    Mooncake    ratio
10              0.5 µs      1.1 µs     0.5×
100            41.8 µs      7.4 µs     5.7×
1000         3441.8 µs     97.5 µs    35.3×
10000      494539.0 µs   1136.1 µs   435.3×
```

</details>
</div>

<div class="cheatbox jl-orange">

## ForwardDiff directly

Works on any generic Julia function of numbers or arrays.

```julia
using ForwardDiff
f(x) = x[1]^2 * x[2] + exp(x[2])
ForwardDiff.derivative(x -> x^3, 2.0)      # 12.0
ForwardDiff.gradient(f, [1.0, 0.0])        # [0.0, 2.0]
ForwardDiff.hessian(f, [1.0, 0.0])         # [0.0 2.0; 2.0 1.0]
ForwardDiff.jacobian(x -> [x[1] * x[2], sin(x[1])], [1.0, 2.0])
G = zeros(2)
ForwardDiff.gradient!(G, f, [1.0, 0.0])    # write into G
d = ForwardDiff.Dual(2.0, 1.0)             # value 2, seed 1
d^3                                        # Dual(8.0, 12.0)
```

ForwardDiff passes `Dual` numbers through your code, so the code must accept any number type: `zeros(n)` inside a function breaks it, `zeros(eltype(x), n)` works.

<details class="example">
<summary>Example</summary>

Newton's method for the maximum likelihood estimate in Poisson regression, with the gradient and Hessian from ForwardDiff.

```julia
using ForwardDiff, LinearAlgebra, Distributions, Random
Random.seed!(2)

n = 200
X = [ones(n) randn(n)]
y = [rand(Poisson(exp(0.5 + 0.8xi))) for xi in X[:, 2]]   # true β = (0.5, 0.8)

loglik(β) = sum(y .* (X * β) .- exp.(X * β))

β = zeros(2)
for iter in 1:20
    g = ForwardDiff.gradient(loglik, β)
    H = ForwardDiff.hessian(loglik, β)
    step = -(H \ g)
    β .+= step
    println(iter, "  β = ", round.(β, digits = 4), "   |step| = ", round(norm(step), sigdigits = 2))
    norm(step) < 1e-10 && break
end
```

```text
1  β = [1.12, 1.3677]   |step| = 1.8
2  β = [0.6706, 1.1502]   |step| = 0.5
3  β = [0.5302, 0.8914]   |step| = 0.29
4  β = [0.5019, 0.7768]   |step| = 0.12
5  β = [0.4976, 0.7657]   |step| = 0.012
6  β = [0.4975, 0.7656]   |step| = 0.00011
7  β = [0.4975, 0.7656]   |step| = 1.0e-8
8  β = [0.4975, 0.7656]   |step| = 9.7e-17
```

```julia
# standard errors from the Hessian at the maximum
sqrt.(diag(inv(-ForwardDiff.hessian(loglik, β))))
```

```text
2-element Vector{Float64}:
 0.0597175428836235
 0.057063109715194626
```

</details>
</div>

<div class="cheatbox jl-orange">

## Mooncake directly

Reverse mode: build a cache once for the argument types, then call it many times.

```julia
using Mooncake
f(x) = sum(abs2, x) + prod(x)
x = [1.0, 2.0, 3.0]
cache = Mooncake.prepare_gradient_cache(f, x)
val, grads = Mooncake.value_and_gradient!!(cache, f, x)
val                     # 20.0
grads                   # (NoTangent(), [8.0, 7.0, 8.0])  ∂/∂f, ∂/∂x
grads[2]                # [8.0, 7.0, 8.0]
g(a, x) = a * sum(abs2, x)            # several arguments
c2 = Mooncake.prepare_gradient_cache(g, 2.0, x)
Mooncake.value_and_gradient!!(c2, g, 2.0, x)   # (28.0, (NoTangent(), 14.0, [4.0, 8.0, 12.0]))
```

The `!!` means the returned gradient arrays are reused by the next call on the same cache: `copy` them if you keep them. Mooncake differentiates loops, branches, mutation and `Float64` buffers, but not reverse-over-reverse (Hessians need forward mode, see below).

<details class="example">
<summary>Example</summary>

Mooncake differentiates with respect to structured inputs too. Here the parameters of a regression are a NamedTuple, and the gradient comes back with the same shape.

```julia
using Mooncake, Random
Random.seed!(3)

n = 100
x = randn(n)
y = 1.0 .+ 2.0 .* x .+ 0.5 .* randn(n)

function logpost(θ)
    μ = θ.α .+ θ.β .* x
    σ = exp(θ.logσ)
    return -n * log(σ) - sum(abs2, y .- μ) / (2σ^2) - (θ.α^2 + θ.β^2) / 200
end

θ = (α = 0.0, β = 0.0, logσ = 0.0)
cache = Mooncake.prepare_gradient_cache(logpost, θ)
val, (_, ∇θ) = Mooncake.value_and_gradient!!(cache, logpost, θ)
∇θ
```

```text
(α = 117.4380577102911, β = 193.25947854876932, logσ = 412.1754865944623)
```

```julia
# a few steps of gradient ascent on the NamedTuple
for _ in 1:2000
    _, (_, g) = Mooncake.value_and_gradient!!(cache, logpost, θ)
    global θ = (α = θ.α + 0.002g.α, β = θ.β + 0.002g.β, logσ = θ.logσ + 0.002g.logσ)
end
(α = θ.α, β = θ.β, σ = exp(θ.logσ))
```

```text
(α = 0.9645782207942359, β = 1.9397942144210925, σ = 0.48992255124530465)
```

```julia
# a Float64 buffer inside the function: fine for Mooncake
function with_buffer(v)
    r = zeros(length(v))          # Float64 array; ForwardDiff would fail here
    r .= v .^ 2
    return sum(r)
end
c = Mooncake.prepare_gradient_cache(with_buffer, [1.0, 2.0])
Mooncake.value_and_gradient!!(c, with_buffer, [1.0, 2.0])
```

```text
(5.0, (Mooncake.NoTangent(), [2.0, 4.0]))
```

</details>
</div>

<div class="cheatbox jl-orange">

## DifferentiationInterface: one syntax for all backends

Pick the backend with an argument; the rest of the code stays the same.

```julia
using DifferentiationInterface, ForwardDiff, Mooncake
f(x) = sum(abs2, x) + prod(x)
x = [1.0, 2.0, 3.0]
backend = AutoMooncake()               # or AutoForwardDiff(), ...
gradient(f, backend, x)                # [8.0, 7.0, 8.0]
value_and_gradient(f, backend, x)      # (20.0, [8.0, 7.0, 8.0])
derivative(sin, AutoForwardDiff(), 1.0)          # 0.5403...  scalar input
second_derivative(sin, AutoForwardDiff(), 1.0)   # -0.8414...
jacobian(x -> [x[1] * x[2], sin(x[1])], backend, x)  # 2×3
hessian(f, AutoForwardDiff(), x)       # 3×3
value_gradient_and_hessian(f, AutoForwardDiff(), x)
```

DI functions take the function first and the backend second: `gradient(f, backend, x)`.

<details class="example">
<summary>Example</summary>

Write the model once, differentiate it with every backend, and check that they agree.

```julia
using DifferentiationInterface, ForwardDiff, Mooncake

y = [2, 0, 3, 1, 4]
loglik(θ) = sum(y .* θ[1] .- exp(θ[1])) - θ[2]^2 / 2 + sin(θ[2]) * θ[1]
θ = [0.5, 0.2]

backends = [AutoForwardDiff(), AutoMooncake(), AutoMooncakeForward()]
grads = [gradient(loglik, b, θ) for b in backends]
for (b, g) in zip(backends, grads)
    println(rpad(nameof(typeof(b)), 22), g)
end
all(g -> g ≈ grads[1], grads)
```

```text
AutoForwardDiff       [1.9550629772944204, 0.2900332889206208]
AutoMooncake          [1.9550629772944195, 0.2900332889206208]
AutoMooncakeForward   [1.9550629772944204, 0.2900332889206208]
true
```

</details>
</div>

<div class="cheatbox jl-orange">

## Preparation: fast repeated calls

`prepare_*` does the one-time work (tracing, compiling, allocating). Reuse the result for inputs of the same type and size.

```julia
using DifferentiationInterface, Mooncake
f(x) = sum(abs2, x) + prod(x)
backend = AutoMooncake()
x = [1.0, 2.0, 3.0]
prep = prepare_gradient(f, backend, x)
gradient(f, prep, backend, [4.0, 5.0, 6.0])   # [38.0, 34.0, 32.0]
G = similar(x)
gradient!(f, G, prep, backend, x)             # in place, no allocation
value_and_gradient!(f, G, prep, backend, x)   # (20.0, G)
# gradient(f, prep, backend, [1.0, 2.0])      # ERROR: size differs from preparation
```

Other operators follow the same pattern: `prepare_jacobian`, `prepare_hessian`, `prepare_pullback`, …

<details class="example">
<summary>Example</summary>

Gradient ascent to a posterior mode, with the gradient prepared once and written into the same vector every iteration.

```julia
using DifferentiationInterface, Mooncake, Random, LinearAlgebra
Random.seed!(4)

p = 50
X = randn(500, p)
βtrue = randn(p) ./ 2
y = X * βtrue .+ randn(500)

logpost(β) = -sum(abs2, y .- X * β) / 2 - sum(abs2, β) / 2

backend = AutoMooncake()
β = zeros(p)
G = similar(β)
prep = prepare_gradient(logpost, backend, β)

for iter in 1:500
    gradient!(logpost, G, prep, backend, β)
    β .+= 1e-3 .* G
end

βexact = (X'X + I) \ (X'y)        # posterior mode in closed form
norm(β - βexact), norm(G)
```

```text
(1.880445248884739e-15, 1.1596412923824594e-13)
```

```julia
# time with and without preparation
gradient(logpost, backend, β)                       # compile first
t_unprepared = minimum(@elapsed(gradient(logpost, backend, β)) for _ in 1:5)
t_prepared = minimum(@elapsed(gradient!(logpost, G, prep, backend, β)) for _ in 1:5)
println("preparation makes each call ", round(Int, t_unprepared / t_prepared), "× faster")
```

```text
preparation makes each call 3× faster
```

</details>
</div>

<div class="cheatbox jl-orange">

## Extra arguments: `Constant` and `Cache`

Differentiate with respect to the first argument only. Pass data with `Constant` and scratch arrays with `Cache`, after `x`.

```julia
using DifferentiationInterface, ForwardDiff, Mooncake
h(x, c) = sum(c .* x .^ 2)          # x: parameters, c: data
x = [1.0, 2.0, 3.0]
gradient(h, AutoForwardDiff(), x, Constant([1.0, 2.0, 3.0]))   # [2.0, 8.0, 18.0]
prep = prepare_gradient(h, AutoMooncake(), x, Constant(zeros(3)))
gradient(h, prep, AutoMooncake(), x, Constant([1.0, 1.0, 1.0]))  # new data, same prep
# scratch space: DI gives the function a buffer of the right element type
function hbuf(x, buf)
    buf .= x .^ 2
    return sum(buf)
end
gradient(hbuf, AutoForwardDiff(), x, Cache(similar(x)))   # [2.0, 4.0, 6.0]
```

A closure such as `θ -> loglik(θ, data)` also works, but `Constant` lets one preparation serve many datasets.

<details class="example">
<summary>Example</summary>

One prepared gradient used for the log-likelihoods of several datasets, as in a simulation study.

```julia
using DifferentiationInterface, Mooncake, Random
Random.seed!(5)

# θ = (μ, log σ)
loglik(θ, y) = -length(y) * θ[2] - sum(abs2, y .- θ[1]) / (2 * exp(2θ[2]))

backend = AutoMooncake()
θ0 = [0.0, 0.0]
prep = prepare_gradient(loglik, backend, θ0, Constant(zeros(50)))

for μtrue in (-1.0, 0.0, 2.0)
    y = μtrue .+ randn(50)
    θ = copy(θ0)
    for _ in 1:3000                                    # gradient ascent
        θ .+= 0.005 .* gradient(loglik, prep, backend, θ, Constant(y))
    end
    println("true μ = ", μtrue, "   estimate = ", round(θ[1], digits = 3),
            "   sample mean = ", round(sum(y) / 50, digits = 3))
end
```

```text
true μ = -1.0   estimate = -0.867   sample mean = -0.867
true μ = 0.0   estimate = -0.189   sample mean = -0.189
true μ = 2.0   estimate = 2.183   sample mean = 2.183
```

</details>
</div>

<div class="cheatbox jl-orange">

## Jacobians, pushforwards and pullbacks

For f: ℝⁿ → ℝᵐ. A pushforward (JVP) is J·v, one forward pass. A pullback (VJP) is wᵀJ, one reverse pass. Neither forms J.

```julia
using DifferentiationInterface, ForwardDiff, Mooncake
f(x) = [x[1] * x[2], sin(x[1]), x[3]^2]
x = [1.0, 2.0, 3.0]
J = jacobian(f, AutoForwardDiff(), x)                 # 3×3
value_and_jacobian(f, AutoMooncake(), x)
pushforward(f, AutoForwardDiff(), x, ([1.0, 0, 0],))  # (J * e₁,) = ([2.0, 0.54..., 0.0],)
pullback(f, AutoMooncake(), x, ([1.0, 0, 0],))        # (J' * e₁,) = ([2.0, 1.0, 0.0],)
hvp(x -> sum(abs2, x) + prod(x), AutoForwardDiff(), x, ([1.0, 0, 0],))   # (H * e₁,)
```

Tangents go in a tuple, so several directions can be pushed at once: `(v1, v2)`.

<details class="example">
<summary>Example</summary>

The log absolute determinant of a Jacobian, as needed for a change of variables in a density. Here the transformation is from polar to Cartesian coordinates, where |det J| = r.

```julia
using DifferentiationInterface, ForwardDiff, LinearAlgebra

polar_to_xy(u) = [u[1] * cos(u[2]), u[1] * sin(u[2])]     # u = (r, φ)

u = [2.0, π / 3]
J = jacobian(polar_to_xy, AutoForwardDiff(), u)
det(J), u[1]
```

```text
(2.0, 2.0)
```

```julia
# density of (r, φ) when (x, y) is standard normal: p_xy(T(u)) |det J(u)|
logp_xy(z) = -log(2π) - sum(abs2, z) / 2
logp_polar(u) = logp_xy(polar_to_xy(u)) + logabsdet(jacobian(polar_to_xy, AutoForwardDiff(), u))[1]

# r has a Rayleigh density r exp(-r²/2), φ is uniform on [0, 2π)
logp_polar(u), log(u[1]) - u[1]^2 / 2 - log(2π)
```

```text
(-3.1447298858494, -3.1447298858494)
```

</details>
</div>

<div class="cheatbox jl-orange">

## Hessians and second order

Combine two backends with `SecondOrder(outer, inner)`. Reverse-over-forward is efficient for Hessians of scalar functions of many variables.

```julia
using DifferentiationInterface, ForwardDiff, Mooncake
f(x) = sum(abs2, x) + prod(x)
x = [1.0, 2.0, 3.0]
hessian(f, AutoForwardDiff(), x)       # [2.0 3.0 2.0; 3.0 2.0 1.0; 2.0 1.0 2.0]
backend2 = SecondOrder(AutoMooncake(), AutoForwardDiff())   # reverse over forward
hessian(f, backend2, x)                # same matrix
# hessian(f, AutoMooncake(), x)        # ERROR: reverse over reverse not supported
prep = prepare_hessian(f, backend2, x)
hessian(f, prep, backend2, [0.0, 1.0, 0.0])
```

For large problems, `hvp` (Hessian-vector products) avoids building the n×n matrix.

<details class="example">
<summary>Example</summary>

A Laplace approximation of a posterior: the mode from Optim with a Mooncake gradient, and the curvature from a reverse-over-forward Hessian.

```julia
using DifferentiationInterface, ForwardDiff, Mooncake, Optim, LinearAlgebra, Random
Random.seed!(6)

n, p = 400, 4
X = [ones(n) randn(n, p - 1)]
β = [0.5, -1.0, 0.8, 0.0]
y = rand(n) .< 1 ./ (1 .+ exp.(-X * β))

log1pexp(η) = η > 0 ? η + log1p(exp(-η)) : log1p(exp(η))
logpost(b) = sum(y .* (X * b) .- log1pexp.(X * b)) - sum(abs2, b) / (2 * 5^2)

res = optimize(b -> -logpost(b), zeros(p), BFGS(); autodiff = AutoMooncake())
mode = Optim.minimizer(res)
H = hessian(logpost, SecondOrder(AutoMooncake(), AutoForwardDiff()), mode)
sd = sqrt.(diag(inv(-H)))
round.([β mode sd], digits = 3)          # true, posterior mode, approximate sd
```

```text
4×3 Matrix{Float64}:
  0.5   0.319  0.122
 -1.0  -1.17   0.146
  0.8   0.984  0.14
  0.0  -0.038  0.119
```

</details>
</div>

<div class="cheatbox jl-orange">

## What breaks AD

Most failures come from code that is not generic or not differentiable.

```julia
using ForwardDiff
bad1(x) = (r = zeros(2); r .= x; sum(r))          # Float64 buffer: ForwardDiff fails
good1(x) = (r = similar(x); r .= x; sum(r))       # takes x's element type
ForwardDiff.derivative(abs, 0.0)                  # 1.0: one side of a kink, no error
ForwardDiff.derivative(x -> x > 1 ? x^2 : x, 1.0) # 2.0: at a tie, the branch just above x
ForwardDiff.derivative(x -> round(x), 0.3)        # 0.0: piecewise constant
ForwardDiff.gradient(x -> sum(x), [1, 2])         # [1, 1] even for Int input
```

In ForwardDiff 1.x, comparisons of a `Dual` at a tie follow the direction of the derivative, so branches give the right-hand derivative, and `x == 1` is `false` for a `Dual`. Also avoid: `rand` inside the function (fix the random numbers outside), `try`/`catch` around the computation, calls to C or Fortran code, and functions annotated `::Float64`. Check new code against finite differences.

<details class="example">
<summary>Example</summary>

A small finite-difference checker, used to catch a hand-written gradient with a bug.

```julia
using ForwardDiff, LinearAlgebra

function fd_gradient(f, x; h = 1e-6)
    g = similar(x)
    for i in eachindex(x)
        e = zeros(length(x)); e[i] = h
        g[i] = (f(x + e) - f(x - e)) / 2h
    end
    return g
end

f(x) = x[1]^2 * x[2] + exp(x[1] * x[2])
mygrad(x) = [2x[1] * x[2] + x[2] * exp(x[1] * x[2]),
             x[1]^2 + exp(x[1] * x[2])]                  # bug: missing factor x[1]

x = [0.7, 1.3]
ad = ForwardDiff.gradient(f, x)
fd = fd_gradient(f, x)
norm(ad - fd), norm(mygrad(x) - fd)                       # AD agrees, mygrad does not
```

```text
(2.0986358842803093e-10, 0.7452967600921685)
```

```julia
# the derivative at a kink depends on how the function is written
f1(x) = abs(x)
f2(x) = sqrt(x^2)
ForwardDiff.derivative(f1, 0.0), ForwardDiff.derivative(f2, 0.0)
```

```text
(1.0, NaN)
```

</details>
</div>
