---
title: Optimization
toc: true
---

# Optimization

The examples use [Optim.jl](https://julianlsolvers.github.io/Optim.jl/stable/) (version 2), [ForwardDiff.jl](https://juliadiff.org/ForwardDiff.jl/stable/) and [Roots.jl](https://juliamath.github.io/Roots.jl/stable/). Install them once with `] add Optim ADTypes ForwardDiff Roots`.

<div class="cheatbox jl-red">

## Functions of one variable

Give `optimize` an interval instead of a starting value. The default method is Brent's.

```julia
using Optim
f(x) = (x - 2)^2 + 1
res = optimize(f, -5, 5)       # minimize f over [-5, 5]
Optim.minimizer(res)            # 2.0
Optim.minimum(res)              # 1.0
optimize(f, -5, 5, GoldenSection())   # other method
g(x) = -f(x)
r = maximize(g, -5, 5)
Optim.maximizer(r), Optim.maximum(r)  # (2.0, -1.0)
```

Optim always minimizes. `maximize` minimizes `-f` for you, and its results need `Optim.maximizer` and `Optim.maximum`. With several variables `maximize` does not accept `autodiff`, so minimize `x -> -f(x)` instead.

<details class="example">
<summary>Example</summary>

The posterior mode of a Beta(a, b) posterior for a probability θ, found numerically and compared with the formula (a - 1)/(a + b - 2).

```julia
using Optim

a, b = 3.0 + 14, 2.0 + 6          # Beta(3, 2) prior, 14 successes, 6 failures
logpost(θ) = (a - 1) * log(θ) + (b - 1) * log(1 - θ)

res = maximize(logpost, 0.0, 1.0)
θmode = Optim.maximizer(res)
θmode, (a - 1) / (a + b - 2)
```

```text
(0.6956521743360761, 0.6956521739130435)
```

```julia
# a function with several local minima: Brent finds one of them
h(x) = sin(3x) + 0.1x^2
[Optim.minimizer(optimize(h, lo, hi)) for (lo, hi) in ((-3, 0), (0, 3), (-3, 3))]
```

```text
3-element Vector{Float64}:
 -0.5122140291011691
  1.536589882956082
 -0.5122140301255439
```

</details>
</div>

<div class="cheatbox jl-red">

## Functions of several variables

Pass the function and a starting vector. Without a method, Optim uses Nelder–Mead, which needs no derivatives.

```julia
using Optim
rosen(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
res = optimize(rosen, [0.0, 0.0])
Optim.minimizer(res)       # [0.99996, 0.99993]  Nelder–Mead
Optim.minimum(res)         # 3.5e-9
Optim.converged(res)       # true
Optim.iterations(res)      # 60
summary(res)               # "Nelder-Mead"
res                        # prints a full report
```

Always check `Optim.converged`: a result is returned even when the method stops at the iteration limit.

<details class="example">
<summary>Example</summary>

Fit an exponential decay curve y = a·exp(-bt) + c by least squares.

```julia
using Optim, Random
Random.seed!(1)

t = 0:0.5:10
y = 5 .* exp.(-0.7 .* t) .+ 1 .+ 0.1 .* randn(length(t))

sse(p) = sum(abs2, y .- (p[1] .* exp.(-p[2] .* t) .+ p[3]))

res = optimize(sse, [1.0, 1.0, 0.0])
Optim.converged(res), round.(Optim.minimizer(res), digits = 3)
```

```text
(true, [5.04, 0.716, 0.995])
```

```julia
res
```

```text
 * Status: success

 * Candidate solution
    Final objective value:     2.340624e-01

 * Found with
    Algorithm:     Nelder-Mead

 * Convergence measures
    √(Σ(yᵢ-ȳ)²)/n ≤ 1.0e-08

 * Work counters
    Seconds run:   0  (vs limit Inf)
    Iterations:    145
    f(x) calls:    267
```

</details>
</div>

<div class="cheatbox jl-red">

## Gradient-based methods

BFGS, L-BFGS and Newton use derivatives and converge in far fewer iterations. Let automatic differentiation compute them.

```julia
using Optim, ADTypes, ForwardDiff
rosen(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
x0 = [0.0, 0.0]
ad = AutoForwardDiff()
optimize(rosen, x0, BFGS(); autodiff = ad)    # 21 iterations
optimize(rosen, x0, LBFGS(); autodiff = ad)   # for many parameters
optimize(rosen, x0, Newton(); autodiff = ad)  # uses the Hessian too

# or write the gradient yourself, filling G in place
function g!(G, x)
    G[1] = -2 * (1 - x[1]) - 400 * x[1] * (x[2] - x[1]^2)
    G[2] = 200 * (x[2] - x[1]^2)
end
optimize(rosen, g!, x0, BFGS())
```

Without `autodiff` or a gradient, BFGS uses finite differences, which can be slow and inaccurate. On this function it stops at the 1000-iteration limit. In Optim 2, `autodiff = :forward` is replaced by `AutoForwardDiff()` from ADTypes, and ForwardDiff must be loaded too.

<details class="example">
<summary>Example</summary>

Compare methods on the Rosenbrock function: iterations, function evaluations and whether they converged.

```julia
using Optim, ADTypes, ForwardDiff

rosen(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
x0 = [0.0, 0.0]
ad = AutoForwardDiff()

runs = [
    "Nelder-Mead"           => optimize(rosen, x0, NelderMead()),
    "BFGS, finite diff."    => optimize(rosen, x0, BFGS()),
    "BFGS, autodiff"        => optimize(rosen, x0, BFGS(); autodiff = ad),
    "L-BFGS, autodiff"      => optimize(rosen, x0, LBFGS(); autodiff = ad),
    "Newton, autodiff"      => optimize(rosen, x0, Newton(); autodiff = ad),
]

println(rpad("method", 22), rpad("converged", 11), rpad("iter", 7), "f calls")
for (name, r) in runs
    println(rpad(name, 22), rpad(Optim.converged(r), 11), rpad(Optim.iterations(r), 7), Optim.f_calls(r))
end
```

```text
method                converged  iter   f calls
Nelder-Mead           true       60     117
BFGS, finite diff.    false      1000   45919
BFGS, autodiff        true       21     34
L-BFGS, autodiff      true       27     44
Newton, autodiff      true       17     33
```

</details>
</div>

<div class="cheatbox jl-red">

## Automatic differentiation with ForwardDiff

Exact derivatives of ordinary Julia code, to machine precision.

```julia
using ForwardDiff
f(x) = x[1]^2 * x[2] + exp(x[2])
ForwardDiff.derivative(sin, 0.0)          # 1.0  for scalar → scalar
ForwardDiff.gradient(f, [1.0, 0.0])       # [0.0, 2.0]
ForwardDiff.hessian(f, [1.0, 0.0])        # [0.0 2.0; 2.0 1.0]
h(x) = [x[1] * x[2], sin(x[1])]
ForwardDiff.jacobian(h, [1.0, 2.0])       # 2×2 Jacobian
```

ForwardDiff calls your function with special `Dual` numbers. Code that forces `Float64`, like `zeros(n)` or a `::Float64` argument, fails. Use `zeros(eltype(x), n)` or `similar(x)` instead.

<details class="example">
<summary>Example</summary>

A log-likelihood written with a preallocated buffer: the first version only works for `Float64`, the second works with ForwardDiff.

```julia
using ForwardDiff

y = [1.2, 0.4, 2.2, 1.9, 0.8]

function loglik_bad(θ)
    r = zeros(length(y))                  # always Float64
    r .= y .- θ[1]
    return -length(y) * θ[2] - sum(abs2, r) / (2 * exp(2θ[2]))
end

function loglik(θ)
    r = zeros(eltype(θ), length(y))       # Float64 or Dual, whatever θ is
    r .= y .- θ[1]
    return -length(y) * θ[2] - sum(abs2, r) / (2 * exp(2θ[2]))
end

try
    ForwardDiff.gradient(loglik_bad, [1.0, 0.0])
catch err
    println(typeof(err))
end
ForwardDiff.gradient(loglik, [1.0, 0.0])
```

```text
MethodError
2-element Vector{Float64}:
  1.5000000000000002
 -2.3099999999999996
```

```julia
# check against a central finite difference
θ = [1.0, 0.0]
ε = 1e-6
fd = [(loglik(θ + ε * e) - loglik(θ - ε * e)) / 2ε for e in ([1.0, 0.0], [0.0, 1.0])]
fd, ForwardDiff.hessian(loglik, θ)
```

```text
([1.4999999999876223, -2.3100000000608745], [-5.0 -3.0000000000000004; -3.0000000000000004 -5.380000000000001])
```

</details>
</div>

<div class="cheatbox jl-red">

## Options and diagnostics

Tolerances, iteration limits and tracing go in `Optim.Options`, passed after the method.

```julia
using Optim, ADTypes, ForwardDiff
rosen(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
opts = Optim.Options(
    g_tol = 1e-8,          # stop when the gradient norm is below this
    iterations = 1000,     # maximum number of iterations
    show_trace = false,    # true prints each iteration
    store_trace = true)    # keep the trace in the result
res = optimize(rosen, [0.0, 0.0], BFGS(), opts; autodiff = AutoForwardDiff())
Optim.converged(res)       # true
Optim.iterations(res)      # 21
Optim.f_calls(res), Optim.g_calls(res)  # (34, 34)
Optim.f_trace(res)[1:3]    # [1.0, 0.8416, 0.6519]
```

Also useful: `time_limit` (seconds), `f_reltol`, `x_abstol`, and `show_every = 10` with `show_trace = true`.

<details class="example">
<summary>Example</summary>

Follow the path BFGS takes on the Rosenbrock function using the stored trace.

```julia
using Optim, ADTypes, ForwardDiff

rosen(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
opts = Optim.Options(store_trace = true, extended_trace = true)
res = optimize(rosen, [-1.2, 1.0], BFGS(), opts; autodiff = AutoForwardDiff())

xs = Optim.x_trace(res)            # parameter values per iteration
fs = Optim.f_trace(res)
for i in [1, 5, 10, 20, length(xs)]
    println(lpad(i - 1, 3), "  x = ", round.(xs[i], digits = 4), "   f = ", round(fs[i], sigdigits = 3))
end
```

```text
  0  x = [-1.2, 1.0]   f = 24.2
  4  x = [-0.8585, 0.7011]   f = 3.58
  9  x = [-0.2287, 0.0522]   f = 1.51
 19  x = [0.3126, 0.0915]   f = 0.476
 41  x = [1.0, 1.0]   f = 5.3699999999999996e-30
```

```julia
# a tight iteration limit: a result comes back, but it has not converged
short = optimize(rosen, [-1.2, 1.0], BFGS(), Optim.Options(iterations = 5); autodiff = AutoForwardDiff())
Optim.converged(short), Optim.minimizer(short)
```

```text
(false, [-0.6608128833956135, 0.3708978947596372])
```

</details>
</div>

<div class="cheatbox jl-red">

## Constraints and reparametrization

For bounds on parameters, either optimize on an unconstrained scale or wrap the method in `Fminbox`.

```julia
using Optim, ADTypes, ForwardDiff
rosen(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
lower, upper = [-1.0, -1.0], [0.5, 0.5]
res = optimize(rosen, lower, upper, [0.0, 0.0], Fminbox(LBFGS());
               autodiff = AutoForwardDiff())
Optim.minimizer(res)      # [0.5, 0.25]  on the boundary x₁ = 0.5

# σ > 0: optimize over η = log σ, then transform back
# 0 < p < 1: optimize over η = log(p / (1 - p)), p = 1 / (1 + exp(-η))
```

The starting value for `Fminbox` must be strictly inside the bounds.

<details class="example">
<summary>Example</summary>

Maximum likelihood for a normal model, where σ must be positive: optimize over log σ.

```julia
using Optim, ADTypes, ForwardDiff, Random
Random.seed!(2)
y = 3 .+ 2 .* randn(200)

# θ = (μ, log σ): every value of θ is allowed
negloglik(θ) = length(y) * θ[2] + sum(abs2, y .- θ[1]) / (2 * exp(2θ[2]))

res = optimize(negloglik, [0.0, 0.0], BFGS(); autodiff = AutoForwardDiff())
μhat, logσhat = Optim.minimizer(res)
(μ = μhat, σ = exp(logσhat))
```

```text
(μ = 2.81714233805867, σ = 1.9652830667333412)
```

```julia
# the MLE has a closed form here, so we can check
n = length(y)
(μ = sum(y) / n, σ = sqrt(sum(abs2, y .- sum(y) / n) / n))
```

```text
(μ = 2.8171423379507763, σ = 1.965283066702972)
```

```julia
# the same with box constraints on (μ, σ) directly
negloglik2(p) = length(y) * log(p[2]) + sum(abs2, y .- p[1]) / (2 * p[2]^2)
res2 = optimize(negloglik2, [-Inf, 1e-6], [Inf, Inf], [0.0, 1.0], Fminbox(LBFGS());
                autodiff = AutoForwardDiff())
Optim.minimizer(res2)
```

```text
2-element Vector{Float64}:
 2.817142337950775
 1.965283066716375
```

</details>
</div>

<div class="cheatbox jl-red">

## Maximum likelihood and standard errors

At the maximum, the inverse of the negative Hessian of the log-likelihood estimates the covariance matrix of the estimates. In Bayesian work, the same at the posterior mode gives a Laplace (normal) approximation.

```julia
using Optim, ADTypes, ForwardDiff, LinearAlgebra
y = [2.1, 3.4, 1.9, 2.8, 2.5]
# θ = (μ, log σ); any log-likelihood or log posterior works the same way
loglik(θ) = -length(y) * θ[2] - sum(abs2, y .- θ[1]) / (2 * exp(2θ[2]))
# minimize -loglik: maximize() with several variables does not take autodiff
res = optimize(θ -> -loglik(θ), [0.0, 0.0], BFGS(); autodiff = AutoForwardDiff())
θhat = Optim.minimizer(res)
H = ForwardDiff.hessian(loglik, θhat)
V = inv(-H)                      # covariance matrix
se = sqrt.(diag(V))              # [0.238, 0.316]  se of μ is σ̂/√n
# Laplace approximation: θ | data ≈ N(θhat, V)
```

Parameters on a transformed scale (like log σ) get standard errors on that scale.

<details class="example">
<summary>Example</summary>

Logistic regression: the maximum likelihood estimate, standard errors from the Hessian, and a Laplace approximation of the posterior under a normal prior.

```julia
using Optim, ADTypes, ForwardDiff, LinearAlgebra, Random
Random.seed!(3)

n = 300
X = [ones(n) randn(n) randn(n)]
β = [-0.5, 1.0, -2.0]
p = 1 ./ (1 .+ exp.(-X * β))
y = rand(n) .< p

# log(1 + exp(η)) written to avoid overflow for large η
log1pexp(η) = η > 0 ? η + log1p(exp(-η)) : log1p(exp(η))
loglik(b) = sum(y .* (X * b) .- log1pexp.(X * b))

res = optimize(b -> -loglik(b), zeros(3), BFGS(); autodiff = AutoForwardDiff())
βhat = Optim.minimizer(res)
se = sqrt.(diag(inv(-ForwardDiff.hessian(loglik, βhat))))
round.([β βhat se], digits = 3)          # true, estimate, standard error
```

```text
3×3 Matrix{Float64}:
 -0.5  -0.698  0.181
  1.0   0.939  0.209
 -2.0  -2.684  0.312
```

```julia
# Laplace approximation of the posterior with prior β ~ N(0, 10²I)
logpost(b) = loglik(b) - sum(abs2, b) / (2 * 10^2)
post = optimize(b -> -logpost(b), zeros(3), BFGS(); autodiff = AutoForwardDiff())
βmode = Optim.minimizer(post)
V = inv(-ForwardDiff.hessian(logpost, βmode))
lower = βmode .- 1.96 .* sqrt.(diag(V))
upper = βmode .+ 1.96 .* sqrt.(diag(V))
round.([βmode lower upper], digits = 3)  # mode and approximate 95% interval
```

```text
3×3 Matrix{Float64}:
 -0.698  -1.052  -0.343
  0.938   0.529   1.347
 -2.681  -3.292  -2.069
```

</details>
</div>

<div class="cheatbox jl-red">

## Root finding with Roots.jl

Solve f(x) = 0 for scalar x. A bracketing interval with a sign change is the most reliable.

```julia
using Roots
f(x) = x^2 - 2
find_zero(f, (0, 2))           # 1.4142135623730951  bisection, guaranteed
find_zero(f, 1.0)              # 1.414213562373095   from a starting guess
find_zeros(sin, 0, 10)         # [0.0, 3.14..., 6.28..., 9.42...]  all roots
g(x) = cos(x) - x
find_zero((g, x -> -sin(x) - 1), 0.5, Roots.Newton())  # 0.7390851332151607
```

For systems of equations, minimize the sum of squares with Optim or use NonlinearSolve.jl.

<details class="example">
<summary>Example</summary>

The Cauchy location model can have several maximum likelihood candidates: solve the score equation (derivative of the log-likelihood equal to zero) for all its roots.

```julia
using Roots

y = [-4.0, -3.5, 3.0, 4.2]                # two well-separated groups
loglik(μ) = -sum(log1p.((y .- μ) .^ 2))
score(μ) = sum(2 .* (y .- μ) ./ (1 .+ (y .- μ) .^ 2))

roots = find_zeros(score, -10, 10)
[(μ = round(r, digits = 3), loglik = round(loglik(r), digits = 3)) for r in roots]
```

```text
3-element Vector{@NamedTuple{μ::Float64, loglik::Float64}}:
 (μ = -3.582, loglik = -8.079)
 (μ = -0.106, loglik = -10.648)
 (μ = 3.23, loglik = -8.525)
```

The score is zero at two local maxima and the local minimum between them. Only a global search shows this; a local optimizer started near one group finds that group's maximum.

The 95% likelihood region is where the log-likelihood is within 1.92 of its maximum (1.92 ≈ χ²(1, 0.95)/2). Find where it crosses that level:

```julia
μhat = roots[argmax(loglik.(roots))]
target(μ) = loglik(μ) - (loglik(μhat) - 1.92)
round.(find_zeros(target, -20, 20), digits = 3)
```

```text
4-element Vector{Float64}:
 -4.793
 -1.702
  1.494
  4.631
```

Four crossings: the region is two separate intervals, one around each group. Searching from `μhat` with a single `find_zero` would have missed the second one.

</details>
</div>
