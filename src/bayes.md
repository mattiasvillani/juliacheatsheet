---
title: Bayesian inference
toc: true
---

# Bayesian inference

<div class="cheatbox jl-wine">

## Conjugate posteriors with Distributions

When the prior is conjugate, the posterior is a `Distribution` object, so `mean`, `quantile` and `rand` work on it directly.

```julia
using Distributions
a, b = 2, 2                       # Beta(2, 2) prior on a success probability θ
s, n = 7, 20                      # 7 successes in 20 trials
post = Beta(a + s, b + n - s)     # Beta(9, 15)
mean(post)                        # 0.375
quantile.(post, [0.025, 0.975])   # 95% equal-tail credible interval
rand(post, 1000)                  # posterior draws
pdf(post, 0.3)                    # posterior density at θ = 0.3
pred = BetaBinomial(10, a + s, b + n - s)   # predictive for 10 new trials
```

<details class="example">
<summary>Example</summary>

Normal data with known variance and a normal prior on the mean: the posterior after each new batch of data.

```julia
using Distributions, Random
rng = Xoshiro(10)
σ = 2.0                              # known data standard deviation
μ0, τ0 = 0.0, 10.0                   # prior N(μ0, τ0²)
y = rand(rng, Normal(3.0, σ), 100)

for n in (0, 1, 5, 20, 100)
    w = 1 / τ0^2 + n / σ^2           # posterior precision
    μn = (μ0 / τ0^2 + sum(y[1:n]) / σ^2) / w
    post = Normal(μn, sqrt(1 / w))
    lo, hi = quantile(post, 0.025), quantile(post, 0.975)
    println(lpad(n, 3), " obs: mean ", rpad(round(mean(post); digits = 3), 7),
            " 95% interval [", round(lo; digits = 2), ", ", round(hi; digits = 2), "]")
end
```

```text
  0 obs: mean 0.0     95% interval [-19.6, 19.6]
  1 obs: mean 5.338   95% interval [1.49, 9.18]
  5 obs: mean 3.779   95% interval [2.03, 5.53]
 20 obs: mean 3.216   95% interval [2.34, 4.09]
100 obs: mean 3.009   95% interval [2.62, 3.4]
```

</details>
</div>

<div class="cheatbox jl-wine">

## A Turing model

`@model` turns a function into a probabilistic model. `~` gives a variable a distribution; variables that are arguments are observed, the rest are parameters.

```julia
using Turing
@model function normal_model(y)
    μ ~ Normal(0, 10)             # prior
    σ ~ truncated(Cauchy(0, 5); lower = 0)
    for i in eachindex(y)
        y[i] ~ Normal(μ, σ)       # likelihood: y is an argument, so observed
    end
end
model = normal_model(randn(50) .+ 2)
chain = sample(model, NUTS(), 1000; progress = false, verbose = false)
```

Write `y ~ MvNormal(fill(μ, n), σ^2 * I)` instead of the loop for a faster vectorised likelihood. Constrained parameters such as `σ` are transformed to the real line automatically. Since Turing 0.49, `sample` returns a `FlexiChain`; add the FlexiChains package for `summarystats`, `ess` and `rhat`.

<details class="example">
<summary>Example</summary>

A normal model with unknown mean and standard deviation, sampled with NUTS.

```julia
using Turing, FlexiChains, Random
Random.seed!(1)

@model function normal_model(y)
    μ ~ Normal(0, 10)
    σ ~ Exponential(5)
    y ~ MvNormal(fill(μ, length(y)), σ^2 * I)
end

y = 2 .+ 1.5 .* randn(100)
chain = sample(normal_model(y), NUTS(), 2000; progress = false, verbose = false)
summarystats(chain)
```

```text
╭─FlexiSummary (9 statistics) ─────────────────────────────────────────────────────────────────────╮
│   iter    collapsed                                                                              │
│   chain   collapsed                                                                              │
│ ↓ stat  = [mean, std, mcse, ess_bulk, ess_tail, rhat, q5, q50, q95]                              │
│                                                                                                  │
│ Parameters (2) ── AbstractPPL.VarName                                                            │
│  Float64  μ, σ                                                                                   │
│                                                                                                  │
│ Extras (14)                                                                                      │
│  Float64  n_steps, is_accept, acceptance_rate, log_density, hamiltonian_energy                   │
│           hamiltonian_energy_error, max_hamiltonian_energy_error, tree_depth, numerical_error    │
│           step_size, nom_step_size, logprior, loglikelihood, logjoint                            │
│                                                                                                  │
│ Summary                                                                                          │
│  param  mean    std     mcse    ess_bulk   ess_tail   rhat    q5      q50     q95                │
│  μ      2.0445  0.1476  0.0033  1989.3332  1252.1120  1.0013  1.8044  2.0461  2.2914             │
│  σ      1.5007  0.1106  0.0025  1966.2162  1549.6661  0.9997  1.3360  1.4900  1.6959             │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
```

</details>
</div>

<div class="cheatbox jl-wine">

## Samplers and several chains

All samplers are called through `sample`. Several chains can run in parallel on threads.

```julia norun
sample(model, NUTS(), 1000)                  # No-U-Turn sampler, adapts its step size
sample(model, NUTS(500, 0.8), 1000)          # 500 adaptation steps, target acceptance 0.8
sample(model, HMC(0.05, 10), 1000)           # step size, leapfrog steps
sample(model, MH(), 10_000)                  # random walk Metropolis
sample(model, Gibbs(:μ => NUTS(), :σ => MH()), 1000)   # different samplers per block
sample(model, NUTS(), MCMCThreads(), 1000, 4)          # 4 chains on threads
sample(model, NUTS(), 1000; progress = false, verbose = false)   # no progress bar or step size messages
```

Start Julia with `--threads=4` (or `auto`) so that `MCMCThreads()` really runs the chains in parallel.

<details class="example">
<summary>Example</summary>

Four NUTS chains in parallel. `rhat` close to 1 and a large effective sample size (`ess_bulk`, `ess_tail`) suggest the chains have converged.

```julia
using Turing, FlexiChains, Random
Random.seed!(2)
@model function normal_model(y)
    μ ~ Normal(0, 10)
    σ ~ Exponential(5)
    y ~ MvNormal(fill(μ, length(y)), σ^2 * I)
end
y = 2 .+ 1.5 .* randn(100)
chains = sample(normal_model(y), NUTS(), MCMCThreads(), 1000, 4; progress = false, verbose = false)
println("threads: ", Threads.nthreads(), ", chains: ", size(chains, 2))   # size is (iterations, chains)
summarystats(chains)
```

```text
threads: 4, chains: 4
╭─FlexiSummary (9 statistics) ─────────────────────────────────────────────────────────────────────╮
│   iter    collapsed                                                                              │
│   chain   collapsed                                                                              │
│ ↓ stat  = [mean, std, mcse, ess_bulk, ess_tail, rhat, q5, q50, q95]                              │
│                                                                                                  │
│ Parameters (2) ── AbstractPPL.VarName                                                            │
│  Float64  μ, σ                                                                                   │
│                                                                                                  │
│ Extras (14)                                                                                      │
│  Float64  n_steps, is_accept, acceptance_rate, log_density, hamiltonian_energy                   │
│           hamiltonian_energy_error, max_hamiltonian_energy_error, tree_depth, numerical_error    │
│           step_size, nom_step_size, logprior, loglikelihood, logjoint                            │
│                                                                                                  │
│ Summary                                                                                          │
│  param  mean    std     mcse    ess_bulk   ess_tail   rhat    q5      q50     q95                │
│  μ      1.8067  0.1504  0.0027  3216.6957  2705.6372  1.0003  1.5591  1.8057  2.0674             │
│  σ      1.4733  0.1049  0.0019  3000.8641  2569.8987  1.0000  1.3113  1.4688  1.6580             │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
```

</details>
</div>

<div class="cheatbox jl-wine">

## Working with chains

A chain is a `FlexiChain` indexed by parameter, iteration and chain. Load FlexiChains for the summary functions.

```julia norun
using FlexiChains
summarystats(chain)            # mean, std, mcse, ess_bulk, ess_tail, rhat, q5, q50, q95
mean(chain), ess(chain), rhat(chain)   # one statistic for every parameter
chain[:μ]                      # draws of μ (iterations × chains)
vec(chain[:μ])                 # as one vector
mean(chain[:σ]); quantile(vec(chain[:σ]), [0.025, 0.975])
chain[@varname(β[2])]          # one element of a vector parameter
stack(vec(chain[:β]); dims = 1)   # vector parameter β as a draws × length(β) matrix
FlexiChains.parameters(chain)  # [μ, σ]
DataFrame(chain)               # with DataFrames loaded
chain[iter = 501:1000]         # keep iterations 501 to 1000
```

`traceplot(chain)` and `mixeddensity(chain)` from FlexiChains draw trace and density plots once Plots is loaded.

<details class="example">
<summary>Example</summary>

Posterior probabilities and summaries computed from the draws.

```julia
using Turing, Statistics, Random
Random.seed!(3)
@model function two_groups(y1, y2)
    μ1 ~ Normal(0, 10)
    μ2 ~ Normal(0, 10)
    σ ~ Exponential(5)
    y1 ~ MvNormal(fill(μ1, length(y1)), σ^2 * I)
    y2 ~ MvNormal(fill(μ2, length(y2)), σ^2 * I)
end
y1 = 5.0 .+ randn(30)
y2 = 5.6 .+ randn(30)
chain = sample(two_groups(y1, y2), NUTS(), 2000; progress = false, verbose = false)
d = vec(chain[:μ2]) .- vec(chain[:μ1])
println("posterior mean of μ2 - μ1: ", round(mean(d); digits = 3))
println("95% interval: ", round.(quantile(d, [0.025, 0.975]); digits = 3))
println("P(μ2 > μ1 | data) = ", round(mean(d .> 0); digits = 3))
```

```text
posterior mean of μ2 - μ1: 0.904
95% interval: [0.415, 1.399]
P(μ2 > μ1 | data) = 1.0
```

</details>
</div>

<div class="cheatbox jl-wine">

## Regression models

Use vectors of parameters with `filldist` (independent and identical) or `MvNormal` priors.

```julia
using Turing
@model function logistic_reg(X, y)
    p = size(X, 2)
    β ~ MvNormal(zeros(p), 10^2 * I)       # or filldist(Normal(0, 10), p)
    η = X * β
    for i in eachindex(y)
        y[i] ~ BernoulliLogit(η[i])         # Bernoulli(logistic(η[i]))
    end
end
@model function poisson_reg(X, y)
    β ~ filldist(Normal(0, 2), size(X, 2))
    y ~ arraydist(LogPoisson.(X * β))       # independent, not identical
end
```

<details class="example">
<summary>Example</summary>

Logistic regression on simulated data, compared with the true coefficients.

```julia
using Turing, Random, Statistics
Random.seed!(4)
n = 300
X = [ones(n) randn(n, 2)]
βtrue = [-0.5, 1.5, -1.0]
y = rand.(BernoulliLogit.(X * βtrue))

@model function logistic_reg(X, y)
    β ~ filldist(Normal(0, 5), size(X, 2))
    y ~ arraydist(BernoulliLogit.(X * β))
end
chain = sample(logistic_reg(X, y), NUTS(), 1500; progress = false, verbose = false)
B = stack(vec(chain[:β]); dims = 1)     # draws × 3
for j in 1:3
    println("β[$j]: true ", rpad(βtrue[j], 5), " posterior mean ", round(mean(B[:, j]); digits = 2),
            " sd ", round(std(B[:, j]); digits = 2))
end
```

```text
β[1]: true -0.5  posterior mean -0.24 sd 0.15
β[2]: true 1.5   posterior mean 1.78 sd 0.22
β[3]: true -1.0  posterior mean -1.17 sd 0.19
```

</details>
</div>

<div class="cheatbox jl-wine">

## Predictions and posterior predictive checks

Pass `missing` for the data to make it a parameter, then `predict` draws it for every posterior draw.

```julia norun
@model function linreg(x, y)
    α ~ Normal(0, 10); β ~ Normal(0, 10); σ ~ Exponential(1)
    for i in eachindex(x)
        y[i] ~ Normal(α + β * x[i], σ)
    end
end
chain = sample(linreg(x, y), NUTS(), 1000)
xnew = [1.0, 2.0]
pred = predict(linreg(xnew, fill(missing, length(xnew))), chain)
yrep = predict(linreg(x, fill(missing, length(y))), chain)   # replicated data for checks
vec(pred[@varname(y[2])])          # predictive draws at xnew[2]
```

<details class="example">
<summary>Example</summary>

Posterior predictive intervals for new x values, and a check that the replicated data have about the right spread.

```julia
using Turing, Random, Statistics
Random.seed!(5)
@model function linreg(x, y)
    α ~ Normal(0, 10)
    β ~ Normal(0, 10)
    σ ~ Exponential(1)
    for i in eachindex(x)
        y[i] ~ Normal(α + β * x[i], σ)
    end
end
x = collect(range(0, 10; length = 40))
y = 1 .+ 0.5 .* x .+ 0.8 .* randn(40)
chain = sample(linreg(x, y), NUTS(), 1000; progress = false, verbose = false)

xnew = [0.0, 5.0, 12.0]
pred = predict(linreg(xnew, fill(missing, 3)), chain)
for (j, xj) in enumerate(xnew)
    lo, hi = quantile(vec(pred[@varname(y[j])]), [0.05, 0.95])
    println("x = $xj: 90% predictive interval [", round(lo; digits = 2), ", ", round(hi; digits = 2), "]")
end

yrep = predict(linreg(x, fill(missing, 40)), chain)
Y = stack([vec(yrep[@varname(y[i])]) for i in 1:40])   # draws × 40
sds = vec(std(Y; dims = 2))
println("P(sd(yrep) > sd(y)) = ", round(mean(sds .> std(y)); digits = 2))
```

```text
x = 0.0: 90% predictive interval [-0.24, 2.72]
x = 5.0: 90% predictive interval [2.34, 5.11]
x = 12.0: 90% predictive interval [5.56, 8.53]
P(sd(yrep) > sd(y)) = 0.52
```

</details>
</div>

<div class="cheatbox jl-wine">

## Posterior mode and maximum likelihood

Turing finds the posterior mode (MAP) and the maximum likelihood estimate with an optimizer, using the same model.

```julia norun
m = normal_model(y)
map_est = maximum_a_posteriori(m)     # posterior mode
mle_est = maximum_likelihood(m)
map_est.params                        # VarNamedTuple(μ = ..., σ = ...)
map_est.params[@varname(μ)]           # one estimate
map_est.lp                            # log density at the mode
sample(m, NUTS(), 1000; initial_params = InitFromParams(map_est))   # start chains at the mode
```

<details class="example">
<summary>Example</summary>

MAP and maximum likelihood estimates of a normal model. With a vague prior and 100 observations they are close.

```julia
using Turing, Random, Statistics
Random.seed!(6)
@model function normal_model(y)
    μ ~ Normal(0, 10)
    σ ~ Exponential(5)
    y ~ MvNormal(fill(μ, length(y)), σ^2 * I)
end
y = 2 .+ 1.5 .* randn(100)
m = normal_model(y)
for (name, est) in [("MAP", maximum_a_posteriori(m)), ("MLE", maximum_likelihood(m))]
    μ, σ = est.params[@varname(μ)], est.params[@varname(σ)]
    println(name, ": μ = ", round(μ; digits = 3), ", σ = ", round(σ; digits = 3))
end
println("mean and sd(y; corrected = false): ", round.([mean(y), std(y; corrected = false)]; digits = 3))
```

```text
MAP: μ = 1.863, σ = 1.666
MLE: μ = 1.863, σ = 1.668
mean and sd(y; corrected = false): [1.863, 1.668]
```

</details>
</div>
