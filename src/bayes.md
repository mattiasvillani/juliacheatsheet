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
chain = sample(model, NUTS(), 1000; progress = false)
```

Write `y ~ MvNormal(fill(μ, n), σ^2 * I)` instead of the loop for a faster vectorised likelihood. Constrained parameters such as `σ` are transformed to the real line automatically.

<details class="example">
<summary>Example</summary>

A normal model with unknown mean and standard deviation, sampled with NUTS.

```julia
using Turing, Random
Random.seed!(1)

@model function normal_model(y)
    μ ~ Normal(0, 10)
    σ ~ Exponential(5)
    y ~ MvNormal(fill(μ, length(y)), σ^2 * I)
end

y = 2 .+ 1.5 .* randn(100)
chain = sample(normal_model(y), NUTS(), 2000; progress = false)
summarystats(chain)
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
sample(model, NUTS(), 1000; progress = false, discard_initial = 0)
```

Start Julia with `--threads=4` (or `auto`) so that `MCMCThreads()` really runs the chains in parallel.

<details class="example">
<summary>Example</summary>

Four NUTS chains in parallel. `rhat` close to 1 and a large effective sample size suggest the chains have converged.

```julia
using Turing, Random
Random.seed!(2)
@model function normal_model(y)
    μ ~ Normal(0, 10)
    σ ~ Exponential(5)
    y ~ MvNormal(fill(μ, length(y)), σ^2 * I)
end
y = 2 .+ 1.5 .* randn(100)
chains = sample(normal_model(y), NUTS(), MCMCThreads(), 1000, 4; progress = false)
println("threads: ", Threads.nthreads(), ", chains: ", size(chains, 3))
ess_rhat(chains)
```

</details>
</div>

<div class="cheatbox jl-wine">

## Working with chains

A chain is an `MCMCChains.Chains` object: iterations × parameters × chains.

```julia norun
summarystats(chain)            # mean, std, mcse, ess, rhat per parameter
quantile(chain)                # 2.5%, 25%, 50%, 75%, 97.5%
chain[:μ]                      # draws of μ (iterations × chains)
vec(chain[:μ])                 # as one vector
mean(chain[:σ])
Array(chain)                   # matrix of all parameters
DataFrame(chain)               # with DataFrames loaded
names(chain, :parameters)      # [:μ, :σ]
chain[501:end]                 # drop the first 500 draws
```

`plot(chain)` with StatsPlots loaded draws trace plots and densities for every parameter.

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
chain = sample(two_groups(y1, y2), NUTS(), 2000; progress = false)
d = vec(chain[:μ2]) .- vec(chain[:μ1])
println("posterior mean of μ2 - μ1: ", round(mean(d); digits = 3))
println("95% interval: ", round.(quantile(d, [0.025, 0.975]); digits = 3))
println("P(μ2 > μ1 | data) = ", round(mean(d .> 0); digits = 3))
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
chain = sample(logistic_reg(X, y), NUTS(), 1500; progress = false)
B = Array(group(chain, :β))
for j in 1:3
    println("β[$j]: true ", rpad(βtrue[j], 5), " posterior mean ", round(mean(B[:, j]); digits = 2),
            " sd ", round(std(B[:, j]); digits = 2))
end
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
chain = sample(linreg(x, y), NUTS(), 1000; progress = false)

xnew = [0.0, 5.0, 12.0]
pred = predict(linreg(xnew, fill(missing, 3)), chain)
P = Array(pred)
for (j, xj) in enumerate(xnew)
    lo, hi = quantile(P[:, j], [0.05, 0.95])
    println("x = $xj: 90% predictive interval [", round(lo; digits = 2), ", ", round(hi; digits = 2), "]")
end

yrep = Array(predict(linreg(x, fill(missing, 40)), chain))
sds = vec(std(yrep; dims = 2))
println("P(sd(yrep) > sd(y)) = ", round(mean(sds .> std(y)); digits = 2))
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
map_est.values                        # named vector of estimates
coeftable(mle_est)                    # estimates with standard errors (needs StatsBase)
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
println("MAP: ", round.(maximum_a_posteriori(m).values.array; digits = 3))
println("MLE: ", round.(maximum_likelihood(m).values.array; digits = 3))
println("mean and sd(y; corrected = false): ", round.([mean(y), std(y; corrected = false)]; digits = 3))
```

</details>
</div>
