---
title: Types
toc: true
---

# Types

<div class="cheatbox jl-blue">

## Inspecting types

Every value has a concrete type. Types form a tree rooted at `Any`.

```julia
using InteractiveUtils  # auto-loaded in the REPL
typeof(1.0)             # Float64
supertype(Float64)      # AbstractFloat
supertypes(Int64)       # (Int64, Signed, Integer, Real, Number, Any)
Float64 <: Real         # true    subtype test
1.0 isa Real            # true    value-is-of-type test
isconcretetype(Real)    # false
eltype([1, 2, 3])       # Int64
subtypes(Integer)       # [Bool, Signed, Unsigned]
```

<details class="example">
<summary>Example</summary>

Walk up the type tree from a value, and print the subtree below an abstract type.

```julia
using InteractiveUtils   # supertypes, subtypes; auto-loaded in the REPL

for x in (1, 1.0, 1//2, π, true, "a")
    println(rpad(repr(x), 6), " ", join(supertypes(typeof(x)), " <: "))
end
```

```text
1      Int64 <: Signed <: Integer <: Real <: Number <: Any
1.0    Float64 <: AbstractFloat <: Real <: Number <: Any
1//2   Rational{Int64} <: Real <: Number <: Any
π      Irrational{:π} <: AbstractIrrational <: Real <: Number <: Any
true   Bool <: Integer <: Real <: Number <: Any
"a"    String <: AbstractString <: Any
```

```julia
function typetree(T, indent = 0)
    kind = isabstracttype(T) ? "  (abstract)" :
           T isa UnionAll    ? "  (parametric)" : ""
    println(" "^indent, T, kind)
    for S in subtypes(T)
        typetree(S, indent + 2)
    end
end

typetree(Real)
```

```text
Real  (abstract)
  AbstractFloat  (abstract)
    BigFloat
    Core.BFloat16
    Float16
    Float32
    Float64
  AbstractIrrational  (abstract)
    Irrational  (parametric)
  Integer  (abstract)
    Bool
    Signed  (abstract)
      BigInt
      Int128
      Int16
      Int32
      Int64
      Int8
    Unsigned  (abstract)
      UInt128
      UInt16
      UInt32
      UInt64
      UInt8
  Rational  (parametric)
```

</details>
</div>

<div class="cheatbox jl-blue">

## Abstract and concrete types

Abstract types have no fields and cannot be instantiated; they exist to organise dispatch. Only leaves (concrete types) hold data.

```julia
abstract type Shape end
struct Circle <: Shape
    r::Float64
end
struct Rect <: Shape
    w::Float64
    h::Float64
end
area(c::Circle) = π * c.r^2
area(s::Rect)   = s.w * s.h
sum(area, [Circle(1), Rect(2, 3)])   # 9.14...
```

Concrete types cannot be subtyped, so a `struct` is always a leaf.

<details class="example">
<summary>Example</summary>

A small prior hierarchy: the code that adds up the log prior only relies on the abstract type, and dispatch picks the right `logdensity` for each prior.

```julia
abstract type Prior end

struct NormalPrior <: Prior
    μ::Float64
    σ::Float64
end

struct UniformPrior <: Prior
    a::Float64
    b::Float64
end

logdensity(p::NormalPrior, x) = -0.5 * log(2π) - log(p.σ) - 0.5 * ((x - p.μ) / p.σ)^2
logdensity(p::UniformPrior, x) = p.a ≤ x ≤ p.b ? -log(p.b - p.a) : -Inf

# works for any vector of Prior subtypes, including ones defined later
logprior(priors::Vector{<:Prior}, θ) = sum(logdensity.(priors, θ))

priors = [NormalPrior(0, 1), UniformPrior(0, 10)]
logprior(priors, [0.3, 2.0])
```

```text
-3.2665236261987185
```

```julia
logprior(priors, [0.3, 11.0])   # outside the uniform's support
```

```text
-Inf
```

</details>
</div>

<div class="cheatbox jl-blue">

## `struct` vs `mutable struct`

A `struct` is immutable: fields cannot be reassigned (but a mutable field, like a `Vector`, can still be modified in place).

```julia
struct Chain1
    draws::Vector{Float64}
end
c = Chain1([0.1])
push!(c.draws, 0.2)     # OK, mutates the vector
# c.draws = [1.0]       # ERROR: immutable struct

mutable struct Sampler
    iter::Int
end
s = Sampler(0)
s.iter += 1             # OK
```

Prefer immutable: faster, can live on the stack. Redefining a struct needs a REPL restart (or Revise.jl).

<details class="example">
<summary>Example</summary>

A sampler's running state changes, so it is a `mutable struct`. The finished result does not change, so it is an immutable `struct`.

```julia
using Random
Random.seed!(2)

mutable struct MHState
    θ::Float64
    nAccept::Int
end

struct MHResult
    draws::Vector{Float64}
    acceptRate::Float64
end

function mh(logpost, θ0, nIter; step = 1.0)
    state = MHState(θ0, 0)
    draws = zeros(nIter)
    for i in 1:nIter
        prop = state.θ + step * randn()
        if log(rand()) < logpost(prop) - logpost(state.θ)
            state.θ = prop              # allowed: mutable
            state.nAccept += 1
        end
        draws[i] = state.θ
    end
    return MHResult(draws, state.nAccept / nIter)
end

res = mh(θ -> -θ^2 / 2, 0.0, 5000; step = 2.4)
res.acceptRate
```

```text
0.4454
```

```julia
try
    res.acceptRate = 1.0                # not allowed: immutable
catch err
    println(typeof(err))
end
push!(res.draws, 0.0)                   # allowed: the Vector itself is mutable
length(res.draws)
```

```text
ErrorException
5001
```

</details>
</div>

<div class="cheatbox jl-blue">

## Keyword constructors and defaults

`Base.@kwdef` gives a keyword constructor with default values.

```julia
Base.@kwdef struct MCMCOpts
    nIter::Int = 1000
    nBurn::Int = nIter ÷ 10
    stepSize::Float64 = 0.1
end
opts = MCMCOpts(nIter = 5000)
opts.nBurn              # 500
fieldnames(MCMCOpts)    # (:nIter, :nBurn, :stepSize)
```

<details class="example">
<summary>Example</summary>

`Base.@kwdef` suits settings objects: callers name only the settings they change. A default can depend on earlier fields.

```julia
Base.@kwdef struct SamplerSettings
    nIter::Int = 10_000
    nBurn::Int = nIter ÷ 5
    nThin::Int = 1
    step::Float64 = 0.5
    seed::Union{Int, Nothing} = nothing
end

s1 = SamplerSettings()
s2 = SamplerSettings(nIter = 2000, step = 0.1, seed = 42)

for f in fieldnames(SamplerSettings)
    println(rpad(f, 6), getfield(s1, f), "  vs  ", getfield(s2, f))
end
```

```text
nIter 10000  vs  2000
nBurn 2000  vs  400
nThin 1  vs  1
step  0.5  vs  0.1
seed  nothing  vs  42
```

Positional construction still works, with all fields in order:

```julia
SamplerSettings(100, 10, 2, 1.0, nothing)
```

```text
Main.Example.SamplerSettings(100, 10, 2, 1.0, nothing)
```

</details>
</div>

<div class="cheatbox jl-blue">

## Inner constructors

Defined inside the struct to enforce invariants; `new` creates the object.

```julia
struct Prob
    p::Float64
    Prob(p) = 0 ≤ p ≤ 1 ? new(p) : error("p ∉ [0,1]")
end
Prob(0.3)               # Prob(0.3)
# Prob(1.5)             # ERROR: p ∉ [0,1]
```

An inner constructor replaces the default one. Outer constructors are plain methods: `Prob() = Prob(0.5)`.

<details class="example">
<summary>Example</summary>

A probability vector that is always valid: the inner constructor checks the values, and an outer constructor normalises positive weights.

```julia
struct ProbVec
    p::Vector{Float64}
    function ProbVec(p::AbstractVector{<:Real})
        all(≥(0), p) || throw(ArgumentError("negative probability"))
        isapprox(sum(p), 1) || throw(ArgumentError("sum is $(sum(p)), not 1"))
        new(collect(Float64, p))
    end
end

# outer constructor: a plain method that ends up calling the inner one
fromweights(w) = ProbVec(w ./ sum(w))

ProbVec([0.2, 0.3, 0.5])
```

```text
Main.Example.ProbVec([0.2, 0.3, 0.5])
```

```julia
fromweights([1, 1, 2])
```

```text
Main.Example.ProbVec([0.25, 0.25, 0.5])
```

```julia
for bad in ([0.5, 0.6], [-0.1, 1.1])
    try
        ProbVec(bad)
    catch err
        println(err.msg)
    end
end
```

```text
sum is 1.1, not 1
negative probability
```

</details>
</div>

<div class="cheatbox jl-blue">

## Parametric types

Type parameters make one definition cover many field types, and keep fields concrete.

```julia
struct Point{T<:Real}
    x::T
    y::T
end
Point(1, 2)             # Point{Int64}(1, 2)
Point(1.0, 2.5)         # Point{Float64}(1.0, 2.5)
Point{Float64}(1, 2)    # converts to Float64
# Point(1, 2.5)         # ERROR: T must be one type
Point{Int} <: Point     # true
```

<details class="example">
<summary>Example</summary>

One definition that works for any real number type. The field type is concrete for each `T`, so the code stays fast.

```julia
struct Gaussian{T<:Real}
    μ::T
    σ::T
end
Gaussian(μ::Real, σ::Real) = Gaussian(promote(μ, σ)...)   # allow mixed input

logpdf(d::Gaussian, x) = -log(d.σ) - log(sqrt(2 * oftype(d.σ, π))) - (x - d.μ)^2 / (2 * d.σ^2)

d64 = Gaussian(0.0, 1.0)
d32 = Gaussian(0.0f0, 1.0f0)
dbig = Gaussian(big(0.0), big(1.0))
dmix = Gaussian(0, 1.5)                 # Int and Float64 promoted

for d in (d64, d32, dbig, dmix)
    println(typeof(d), "  ", logpdf(d, one(d.μ)))
end
```

```text
Main.Example.Gaussian{Float64}  -1.4189385332046727
Main.Example.Gaussian{Float32}  -1.4189385
Main.Example.Gaussian{BigFloat}  -1.418938533204672741780329736405617639861397473637783412817151540482765695927251
Main.Example.Gaussian{Float64}  -1.5466258635350592
```

</details>
</div>

<div class="cheatbox jl-blue">

## Invariance: `Vector{Int}` is not a `Vector{Real}`

Parametric types are invariant in their parameters. Use `<:` inside the braces to cover a family.

```julia
Int <: Real                     # true
Vector{Int} <: Vector{Real}     # false
Vector{Int} <: Vector{<:Real}   # true
Vector{Int} <: AbstractVector{<:Real}  # true
```

So write `f(x::AbstractVector{<:Real})`, not `f(x::Vector{Real})`, which only accepts arrays created as `Real[...]`. Tuples are the exception: they are covariant.

<details class="example">
<summary>Example</summary>

The common mistake, and the fix.

```julia
bad_mean(x::Vector{Real}) = sum(x) / length(x)
good_mean(x::AbstractVector{<:Real}) = sum(x) / length(x)

try
    bad_mean([1, 2, 3])                 # Vector{Int64} is not a Vector{Real}
catch err
    println(typeof(err))
end

bad_mean(Real[1, 2, 3])                 # only works for this element type
```

```text
MethodError
2.0
```

```julia
good_mean([1, 2, 3]), good_mean([1.0, 2.5]), good_mean(1:10), good_mean(view([1, 2, 3, 4], 2:3))
```

```text
(2.0, 1.75, 5.5, 2.5)
```

`Vector{<:Real}` is the set of all `Vector{T}` with `T <: Real`:

```julia
Vector{Float64} <: Vector{<:Real}, Vector{Real} <: Vector{<:Real}, Vector{Any} <: Vector{<:Real}
```

```text
(true, true, false)
```

</details>
</div>

<div class="cheatbox jl-blue">

## Methods with `where`

`where` names a type parameter so the method body can use it.

```julia
mysum(x::AbstractVector{T}) where {T<:Number} =
    reduce(+, x; init = zero(T))
mysum(Int[])            # 0
mysum([1.5, 2.0])       # 3.5

same(a::T, b::T) where {T} = true
same(a, b) = false
same(1, 2), same(1, 2.0)   # (true, false)
```

Dispatch picks the most specific matching method.

<details class="example">
<summary>Example</summary>

Use the parameter `T` in the method body, for example to return the same element type or to pick a numerical tolerance.

```julia
function standardize(x::AbstractVector{T}) where {T<:AbstractFloat}
    m = sum(x) / length(x)
    s = sqrt(sum((x .- m) .^ 2) / (length(x) - 1))
    return (x .- m) ./ s                 # stays in T
end
standardize(x::AbstractVector{<:Integer}) = standardize(float(x))

eltype(standardize([1.0f0, 2.0f0, 4.0f0])), eltype(standardize([1, 2, 4]))
```

```text
(Float32, Float64)
```

```julia
# T in two arguments: both must have the same element type
samelength(a::Vector{T}, b::Vector{T}) where {T} = "both Vector{$T}"
samelength(a::Vector, b::Vector) = "different element types"

samelength([1, 2], [3]), samelength([1, 2], [3.0])
```

```text
("both Vector{Int64}", "different element types")
```

```julia
# T used as a value: a tolerance tied to the precision
isconverged(Δ::T) where {T<:AbstractFloat} = abs(Δ) < sqrt(eps(T))
isconverged(1e-5), isconverged(1.0f-5)
```

```text
(false, true)
```

</details>
</div>

<div class="cheatbox jl-blue">

## `Union`, `Nothing`, `Missing`

`Union{A,B}` is a type whose values are either `A` or `B`. Small unions are handled efficiently by the compiler.

```julia
findfirst(>(5), [1, 2, 3])  # nothing  (type Nothing)
x = Union{Float64, Missing}[1.0, missing, 3.0]
sum(skipmissing(x))         # 4.0
coalesce(missing, 0.0)      # 0.0
something(nothing, 1)       # 1
isnothing(nothing), ismissing(missing)  # (true, true)
```

`nothing` means "no value" (software); `missing` means "unknown data value" (statistics) and propagates: `missing + 1` is `missing`.

<details class="example">
<summary>Example</summary>

`nothing` as the "not found" return value, and `missing` for gaps in data.

```julia
function first_exceedance(x, threshold)::Union{Int, Nothing}
    for i in eachindex(x)
        x[i] > threshold && return i
    end
    return nothing
end

series = [0.2, 0.8, 1.7, 0.4]
for thr in (1.0, 5.0)
    i = first_exceedance(series, thr)
    println(thr, ": ", isnothing(i) ? "never exceeded" : "first at index $i")
end
```

```text
1.0: first at index 3
5.0: never exceeded
```

```julia
using Statistics
temps = [12.1, missing, 13.4, 11.8, missing]

mean(temps)                         # missing propagates
```

```text
missing
```

```julia
mean(skipmissing(temps)),           # ignore missing values
count(ismissing, temps),
coalesce.(temps, 0.0)               # replace missing values
```

```text
(12.433333333333332, 2, [12.1, 0.0, 13.4, 11.8, 0.0])
```

</details>
</div>

<div class="cheatbox jl-blue">

## Conversion and promotion

`convert` changes type when lossless; arithmetic promotes to a common type.

```julia
convert(Float64, 2)          # 2.0
# convert(Int, 2.5)          # ERROR: InexactError
round(Int, 2.5)              # 2   (round to even)
Int(2.0), Float32(1)         # (2, 1.0f0)
parse(Float64, "3.14")       # 3.14   string -> number
string(3.14)                 # "3.14"
promote(1, 2.0)              # (1.0, 2.0)
promote_type(Int, Float32)   # Float32
1 + 2.0                      # 3.0
```

<details class="example">
<summary>Example</summary>

Read numbers from text, get the element type right, and see how promotion picks a common type.

```julia
lines = ["1.5", "2", "-0.25", "NA"]
vals = [something(tryparse(Float64, s), NaN) for s in lines]   # NaN when parsing fails
```

```text
4-element Vector{Float64}:
   1.5
   2.0
  -0.25
 NaN
```

```julia
counts = parse.(Int, ["3", "10", "7"])
counts ./ sum(counts)               # Int / Int gives Float64
```

```text
3-element Vector{Float64}:
 0.15
 0.5
 0.35
```

```julia
# array literals promote to a common element type
typeof([1, 2.0]), typeof([1, 2//3]), typeof([1, "a"])
```

```text
(Vector{Float64}, Vector{Rational{Int64}}, Vector{Any})
```

```julia
# narrow an Any vector back to a concrete type
v = Any[1, 2, 3]
w = identity.(v)
typeof(w), typeof(convert(Vector{Float64}, w))
```

```text
(Vector{Int64}, Vector{Float64})
```

```julia
# float to Int: choose the rounding explicitly
x = 2.7
round(Int, x), floor(Int, x), ceil(Int, x), trunc(Int, x)
```

```text
(3, 2, 3, 2)
```

</details>
</div>

<div class="cheatbox jl-blue">

## Type stability and performance

Code is fast when the compiler can infer concrete types. Abstract field types force boxing and dynamic dispatch.

```julia
struct Slow; x::Real; end         # abstract field: slow
struct Fast{T<:Real}; x::T; end   # concrete after construction
isconcretetype(fieldtype(Slow, :x))           # false
isconcretetype(fieldtype(Fast{Float64}, :x))  # true

unstable(x) = x > 0 ? x : 0       # Int or Float64
stable(x)   = x > 0 ? x : zero(x) # always typeof(x)
```

Check with `@code_warntype f(args)`: red `Any`/`Union` entries mark trouble. Annotating argument types does not speed things up; dispatch and concrete fields do.

<details class="example">
<summary>Example</summary>

Compare a struct with an abstract field type against a parametric one, and ask the compiler what types it infers.

```julia
struct SlowParam
    value::Real
end
struct FastParam{T<:Real}
    value::T
end

total(ps) = sum(p.value for p in ps)

slow = [SlowParam(rand()) for _ in 1:10^6]
fast = [FastParam(rand()) for _ in 1:10^6]
total(slow); total(fast)            # compile first, then time

tslow = @elapsed total(slow)
tfast = @elapsed total(fast)
println("abstract field is ", round(tslow / tfast, digits = 1), "× slower")
```

```text
abstract field is 25.4× slower
```

```julia
unstable(x) = x > 0 ? x : 0
stable(x) = x > 0 ? x : zero(x)

Base.return_types(unstable, (Float64,)), Base.return_types(stable, (Float64,))
```

```text
(Any[Union{Float64, Int64}], Any[Float64])
```

In the REPL, `@code_warntype unstable(1.0)` shows the same thing, with the `Union` highlighted.

</details>
</div>
