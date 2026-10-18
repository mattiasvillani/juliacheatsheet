---
title: Statistics
toc: true
---

# Statistics

`Statistics` and `Random` come with Julia. The rest uses [StatsBase.jl](https://juliastats.org/StatsBase.jl/stable/) and [Distributions.jl](https://juliastats.org/Distributions.jl/stable/): install them once with `] add StatsBase Distributions`.

<div class="cheatbox jl-teal">

## Descriptive statistics

```julia
using Statistics
x = [2.0, 4.0, 4.0, 5.0, 10.0]
mean(x), median(x)          # (5.0, 4.0)
var(x), std(x)              # (9.0, 3.0)  divide by n - 1
var(x, corrected = false)   # 7.2         divide by n
quantile(x, [0.25, 0.75])   # [4.0, 5.0]
mean(abs2, x)               # 32.2   mean of f.(x), no temporary array
y = [1.0, 3.0, 2.0, 5.0, 9.0]
cor(x, y), cov(x, y)        # (0.975..., 9.25)
X = [x y]
mean(X, dims = 1)           # [5.0 4.0]  column means
cor(X)                      # 2×2 correlation matrix of the columns
mean(skipmissing([1, missing, 3]))   # 2.0
```

`cov` and `cor` on a matrix treat columns as variables and rows as observations.

<details class="example">
<summary>Example</summary>

A posterior summary table from a matrix of MCMC draws (rows are draws, columns are parameters).

```julia
using Statistics, Random
Random.seed!(1)

draws = [randn(4000) .+ 1  2 .* randn(4000)  exp.(0.3 .* randn(4000))]
names = ["μ", "β", "σ"]

println(rpad("param", 7), lpad("mean", 8), lpad("sd", 8), lpad("2.5%", 8), lpad("median", 8), lpad("97.5%", 8))
for (j, name) in enumerate(names)
    d = draws[:, j]
    q = quantile(d, [0.025, 0.5, 0.975])
    println(rpad(name, 7), join(lpad.(round.([mean(d), std(d), q...], digits = 3), 8)))
end
```

```text
param      mean      sd    2.5%  median   97.5%
μ         1.024   1.007   -0.99   1.044   3.021
β        -0.012   1.988  -3.752  -0.047   3.932
σ         1.037   0.315    0.54   0.991    1.78
```

```julia
round.(cor(draws), digits = 3)
```

```text
3×3 Matrix{Float64}:
  1.0    -0.003   0.007
 -0.003   1.0    -0.018
  0.007  -0.018   1.0
```

</details>
</div>

<div class="cheatbox jl-teal">

## StatsBase: counts, weights and more

```julia
using StatsBase
z = ["a", "b", "a", "c", "a"]
countmap(z)                 # Dict("a" => 3, "b" => 1, "c" => 1)
proportionmap(z)            # Dict("a" => 0.6, ...)
mode(z)                     # "a"
counts([1, 2, 2, 3, 3, 3])  # [1, 2, 3]  counts of 1, 2, 3
x = [2.0, 4.0, 4.0, 5.0, 10.0]
mean(x, Weights([1, 1, 1, 1, 6]))   # 7.5  weighted mean
zscore(x)                   # standardized: (x .- mean) ./ std
F = ecdf(x); F(4.5)         # 0.6    empirical CDF
autocor(x, [1, 2])          # autocorrelations at lags 1 and 2
sample(1:10, 3; replace = false)          # 3 distinct values
sample(["a", "b"], Weights([0.9, 0.1]), 5)  # weighted draws
summarystats(x)             # mean, quartiles, min, max
```

<details class="example">
<summary>Example</summary>

Autocorrelation of an AR(1) chain, as for MCMC output, and the resulting effective sample size.

```julia
using StatsBase, Random
Random.seed!(2)

ϕ, n = 0.9, 50_000
x = zeros(n)
for t in 2:n
    x[t] = ϕ * x[t-1] + randn()
end

ρ = autocor(x, 0:5)
round.(ρ, digits = 3), round.(ϕ .^ (0:5), digits = 3)   # estimate vs theory
```

```text
([1.0, 0.901, 0.812, 0.733, 0.662, 0.597], [1.0, 0.9, 0.81, 0.729, 0.656, 0.59])
```

```julia
# effective sample size: n / (1 + 2 Σρₖ), summing until ρₖ becomes small
ρall = autocor(x, 1:200)
K = something(findfirst(<(0.05), ρall), length(ρall))
ess = n / (1 + 2 * sum(ρall[1:K]))
round(Int, ess), round(Int, n * (1 - ϕ) / (1 + ϕ))      # estimate vs theory
```

```text
(2761, 2632)
```

</details>
</div>

<div class="cheatbox jl-teal">

## Random numbers

```julia
using Random
Random.seed!(123)           # reproducible global stream
rand()                      # uniform on [0, 1)
rand(3), randn(2, 2)        # uniform vector, standard normal matrix
rand(1:6, 10)               # 10 dice rolls
rand(["a", "b", "c"])       # random element
randperm(5)                 # random permutation of 1:5
shuffle([1, 2, 3, 4])       # shuffled copy (shuffle! in place)
randexp(3)                  # Exponential(1) draws
rng = Xoshiro(42)           # independent generator object
rand(rng, 3)                # same numbers every time for seed 42
x = zeros(3); randn!(rng, x)   # fill an existing array
```

Pass an `rng` argument through your functions to make simulations reproducible without relying on the global seed.

<details class="example">
<summary>Example</summary>

A bootstrap confidence interval for a median, with an explicit random number generator.

```julia
using Random, Statistics

function bootstrap(rng, stat, x, B)
    n = length(x)
    return [stat(x[rand(rng, 1:n, n)]) for _ in 1:B]
end

data = [3.1, 4.7, 2.2, 8.9, 5.0, 4.1, 3.8, 12.5, 4.4, 5.9]
boot = bootstrap(Xoshiro(1), median, data, 10_000)
median(data), quantile(boot, [0.025, 0.975])
```

```text
(4.550000000000001, [3.5999999999999996, 6.95])
```

```julia
# same seed, same result
bootstrap(Xoshiro(1), median, data, 5) == bootstrap(Xoshiro(1), median, data, 5)
```

```text
true
```

</details>
</div>

<div class="cheatbox jl-teal">

## Distributions: creating and parameters

Distributions are types. Check the parametrization in the docs: several use a scale, not a rate.

```julia
using Distributions
Normal(0, 2)                # mean 0, standard deviation 2 (not variance)
Gamma(2, 3)                 # shape α = 2, scale θ = 3 (mean 6)
Gamma(2, 1 / 3)             # shape 2, rate 3: pass scale = 1/rate
Exponential(2)              # scale 2, mean 2 (rate 1/2)
Beta(2, 5), Uniform(0, 1), TDist(5), Cauchy(0, 1)
InverseGamma(3, 2), LogNormal(0, 1), Laplace(0, 1)
Binomial(10, 0.3), Poisson(4), Bernoulli(0.2)
NegativeBinomial(3, 0.5), Geometric(0.2), Categorical([0.2, 0.5, 0.3])
d = Gamma(2, 3)
params(d)                   # (2.0, 3.0)
shape(d), scale(d), rate(d) # (2.0, 3.0, 0.333...)
mean(d), var(d), std(d)     # (6.0, 18.0, 4.24...)
mode(d), median(d)          # (3.0, 5.03...)
```

<details class="example">
<summary>Example</summary>

Summaries of a few common priors, computed the same way for every distribution.

```julia
using Distributions

priors = [Normal(0, 10), Gamma(2, 0.5), InverseGamma(3, 2), Beta(2, 8), Poisson(4)]

label(d) = string(nameof(typeof(d)), "(", join(params(d), ", "), ")")

println(rpad("distribution", 22), lpad("mean", 8), lpad("sd", 8), lpad("2.5%", 8), lpad("97.5%", 8))
for d in priors
    vals = [mean(d), std(d), quantile(d, 0.025), quantile(d, 0.975)]
    println(rpad(label(d), 22), join(lpad.(round.(vals, digits = 3), 8)))
end
```

```text
distribution              mean      sd    2.5%   97.5%
Normal(0.0, 10.0)          0.0    10.0   -19.6    19.6
Gamma(2.0, 0.5)            1.0   0.707   0.121   2.786
InverseGamma(3.0, 2.0)     1.0     1.0   0.277   3.233
Beta(2.0, 8.0)             0.2   0.121   0.028   0.482
Poisson(4.0)               4.0     2.0     1.0     8.0
```

```julia
# a Gamma prior with given mean m and sd s: shape = (m/s)², scale = s²/m
m, s = 5.0, 2.0
d = Gamma((m / s)^2, s^2 / m)
mean(d), std(d)
```

```text
(5.0, 2.0)
```

</details>
</div>

<div class="cheatbox jl-teal">

## Densities, probabilities, quantiles and draws

The same functions work for every distribution.

```julia
using Distributions
d = Normal(1, 2)
pdf(d, 1.0)                 # 0.1994...  density at 1
logpdf(d, 1.0)              # -1.612...  use this for likelihoods
cdf(d, 1.0)                 # 0.5        P(X ≤ 1)
ccdf(d, 5.0)                # 0.0227...  P(X > 5), accurate in the tail
quantile(d, 0.975)          # 4.919...
rand(d), rand(d, 5)         # one draw, five draws
logpdf.(d, [0.0, 1.0])      # broadcast over values
loglikelihood(d, [0.0, 1.0, 2.0])   # sum of logpdf over the data
pdf(Poisson(3), 2)          # 0.224...  probability mass for discrete
support(Beta(2, 2))         # RealInterval(0.0, 1.0)
insupport(Poisson(3), -1)   # false
```

<details class="example">
<summary>Example</summary>

Beta–binomial updating: posterior summaries, an equal-tailed credible interval and a posterior predictive probability.

```julia
using Distributions

prior = Beta(2, 2)
s, f = 14, 6                                 # successes and failures
post = Beta(params(prior)[1] + s, params(prior)[2] + f)

(mean = mean(post), mode = mode(post), sd = std(post),
 interval = quantile.(post, [0.025, 0.975]))
```

```text
(mean = 0.6666666666666666, mode = 0.6818181818181818, sd = 0.09428090415820634, interval = [0.47080833399149336, 0.8362364016250502])
```

```julia
cdf(post, 0.5), 1 - cdf(post, 0.5)          # P(θ ≤ 0.5 | data), P(θ > 0.5 | data)
```

```text
(0.046569824218750035, 0.95343017578125)
```

```julia
# predictive distribution of successes in 10 new trials
α, β = params(post)
pred = BetaBinomial(10, α, β)
[(k = k, prob = round(pdf(pred, k), digits = 3)) for k in 5:9]
```

```text
5-element Vector{@NamedTuple{k::Int64, prob::Float64}}:
 (k = 5, prob = 0.133)
 (k = 6, prob = 0.193)
 (k = 7, prob = 0.221)
 (k = 8, prob = 0.191)
 (k = 9, prob = 0.113)
```

```julia
# the same predictive probability by simulation
θs = rand(post, 100_000)
mean(rand.(Binomial.(10, θs)) .== 7), pdf(pred, 7)
```

```text
(0.21971, 0.22110036793017843)
```

</details>
</div>

<div class="cheatbox jl-teal">

## Fitting distributions to data

`fit` gives the maximum likelihood estimate for many distributions.

```julia
using Distributions, Random
Random.seed!(1)
x = rand(Gamma(2, 3), 1000)
fit(Normal, x)              # Normal(μ = x̄, σ = MLE sd)
fit(Gamma, x)               # ≈ Gamma(2, 3)
fit_mle(Exponential, x)     # same as fit
fit(Poisson, [2, 3, 1, 4])  # Poisson(λ = 2.5)
fit(Categorical, [1, 2, 2, 3])   # proportions of 1, 2, 3
loglikelihood(fit(Gamma, x), x)  # maximized log-likelihood
```

<details class="example">
<summary>Example</summary>

Fit several distributions to positive data and compare them with AIC (lower is better).

```julia
using Distributions, Random
Random.seed!(4)

x = rand(LogNormal(1, 0.5), 500)

for D in (Exponential, Gamma, LogNormal, Weibull)
    d = fit(D, x)
    k = length(params(d))
    aic = -2 * loglikelihood(d, x) + 2k
    println(rpad(nameof(D), 12), lpad(round(aic, digits = 1), 8), "   params ", round.(params(d), digits = 3))
end
```

```text
Exponential   2112.4   params (3.036,)
Gamma         1748.6   params (4.029, 0.753)
LogNormal     1749.8   params (0.981, 0.52)
Weibull       1786.2   params (2.058, 3.439)
```

</details>
</div>

<div class="cheatbox jl-teal">

## Multivariate distributions

Draws from a multivariate distribution are columns: `rand(d, n)` returns a dim × n matrix.

```julia
using Distributions, LinearAlgebra
μ = [0.0, 1.0]
Σ = [1.0 0.5; 0.5 2.0]
d = MvNormal(μ, Σ)
length(d)                   # 2
mean(d), cov(d)             # μ and Σ
logpdf(d, [0.0, 1.0])       # -2.1177...
X = rand(d, 1000)           # 2×1000
Dirichlet([1.0, 2.0, 3.0])  # probabilities summing to 1
Multinomial(10, [0.2, 0.3, 0.5])
MvNormal(zeros(3), I)       # identity covariance (I from LinearAlgebra)
product_distribution([Normal(), Exponential()])  # independent components
```

<details class="example">
<summary>Example</summary>

Conditional distribution of one component of a bivariate normal given the other, checked by simulation.

```julia
using Distributions, Statistics, Random
Random.seed!(5)

μ = [1.0, 2.0]
Σ = [1.0 0.8; 0.8 2.0]
d = MvNormal(μ, Σ)

# x₂ | x₁ = a  ~  N(μ₂ + Σ₂₁/Σ₁₁ (a - μ₁),  Σ₂₂ - Σ₂₁²/Σ₁₁)
a = 2.0
cond = Normal(μ[2] + Σ[2, 1] / Σ[1, 1] * (a - μ[1]), sqrt(Σ[2, 2] - Σ[2, 1]^2 / Σ[1, 1]))
```

```text
Distributions.Normal{Float64}(μ=2.8, σ=1.16619037896906)
```

```julia
X = rand(d, 1_000_000)
near = abs.(X[1, :] .- a) .< 0.01          # draws with x₁ close to a
mean(X[2, near]), std(X[2, near]), mean(cond), std(cond)
```

```text
(2.811669082618327, 1.1855822807964118, 2.8, 1.16619037896906)
```

```julia
# Dirichlet–multinomial updating of category probabilities
prior = Dirichlet([1.0, 1.0, 1.0])
counts = [12, 30, 8]
post = Dirichlet(prior.alpha .+ counts)
round.(mean(post), digits = 3)
```

```text
3-element Vector{Float64}:
 0.245
 0.585
 0.17
```

</details>
</div>

<div class="cheatbox jl-teal">

## Truncation, mixtures and location-scale

Build new distributions from old ones. The results support `pdf`, `cdf`, `rand` and so on.

```julia
using Distributions
truncated(Normal(0, 1); lower = 0)      # half-normal
truncated(Normal(5, 2), 0, 10)          # on [0, 10]
m = MixtureModel([Normal(-2, 1), Normal(3, 0.5)], [0.3, 0.7])
mean(m)                                 # 1.5
pdf(m, 0.0)                             # 0.0162...
3 + 2 * TDist(4)                        # location 3, scale 2 Student-t
LocationScale(3, 2, TDist(4))           # the same, written out
censored(Normal(), -1, 1)               # values outside [-1, 1] piled at the ends
```

<details class="example">
<summary>Example</summary>

A two-component mixture: density, simulated data and the posterior probability of component membership for each observation.

```julia
using Distributions, Random, Statistics
Random.seed!(6)

w = [0.4, 0.6]
comps = [Normal(0, 1), Normal(4, 1.5)]
m = MixtureModel(comps, w)

x = rand(m, 10_000)
mean(x), mean(m), var(x), var(m)
```

```text
(2.4239976904491494, 2.4, 5.598285578446384, 5.590000000000001)
```

```julia
# P(component k | x) ∝ w_k p_k(x)
function membership(x)
    p = w .* pdf.(comps, x)
    return p ./ sum(p)
end

[(x = xi, p = round.(membership(xi), digits = 3)) for xi in (-1.0, 1.5, 2.0, 3.0, 6.0)]
```

```text
5-element Vector{@NamedTuple{x::Float64, p::Vector{Float64}}}:
 (x = -1.0, p = [0.994, 0.006])
 (x = 1.5, p = [0.566, 0.434])
 (x = 2.0, p = [0.248, 0.752])
 (x = 3.0, p = [0.014, 0.986])
 (x = 6.0, p = [0.0, 1.0])
```

```julia
# a truncated normal: draws stay inside the bounds
tn = truncated(Normal(0, 1), 1, Inf)
draws = rand(tn, 100_000)
minimum(draws), mean(draws), mean(tn)
```

```text
(1.0000028594428654, 1.526432121998909, 1.525135276160981)
```

</details>
</div>
