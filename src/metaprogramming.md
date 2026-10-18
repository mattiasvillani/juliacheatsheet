---
title: Metaprogramming
toc: true
---

# Metaprogramming

<div class="cheatbox jl-pine">

## Symbols and expressions

Julia code is itself a Julia data structure. `:x` is a `Symbol`, and `:( ... )` or `quote ... end` gives an unevaluated `Expr`.

```julia
s = :x                         # Symbol
Symbol("my", "var")            # :myvar
ex = :(a + 2b)                 # Expr, not evaluated
ex.head, ex.args               # (:call, Any[:+, :a, :(2b)])
dump(ex)                       # the full tree
Meta.parse("1 + 2 * 3")        # :(1 + 2 * 3)  string to Expr
a, b = 1, 2; eval(ex)          # 5   evaluates in global scope of the module
Expr(:call, :*, 3, 4)          # :(3 * 4)  build an Expr directly
```

`eval` always works in global scope, so it cannot see the local variables of a function.

<details class="example">
<summary>Example</summary>

Walk an expression tree to collect its variable names, then turn the expression into a function.

```julia
vars(ex::Symbol) = [ex]
vars(ex::Expr) = ex.head == :call ? reduce(vcat, vars.(ex.args[2:end]); init = Symbol[]) : Symbol[]
vars(ex) = Symbol[]               # numbers and other literals

ex = Meta.parse("α * x^2 + β * log(x)")
v = unique(vars(ex))
println("variables: ", v)

f = eval(:(($(v...),) -> $ex))    # (α, x, β) -> α * x^2 + β * log(x)
println(f(2.0, 3.0, 1.0))
```

</details>
</div>

<div class="cheatbox jl-pine">

## Interpolating into expressions

Inside `quote` and `:( )`, `$` splices a value or expression in.

```julia
n = 3
ex = :(x^$n)                   # :(x ^ 3)
args = [:a, :b, :c]
:(f($(args...)))               # :(f(a, b, c))   splat a vector of arguments
body = quote
    y = $ex + 1
    2y
end
name = :square
@eval $name(x) = x^2           # defines square(x); @eval interpolates then evaluates
square(4)                      # 16
```

<details class="example">
<summary>Example</summary>

Generate many similar method definitions in a loop with `@eval`.

```julia
for (name, p) in [(:square, 2), (:cube, 3), (:fourth, 4)]
    @eval $name(x) = x^$p
end
println(square(3), " ", cube(3), " ", fourth(3))

struct Prior; mean::Float64; sd::Float64; end
for op in (:+, :-)
    @eval Base.$op(p::Prior, c::Real) = Prior($op(p.mean, c), p.sd)
end
println(Prior(0, 1) + 2, " ", Prior(0, 1) - 2)
```

</details>
</div>

<div class="cheatbox jl-pine">

## Writing macros

A macro gets expressions, not values, and returns a new expression that replaces the call. It runs when the code is parsed.

```julia
macro twice(ex)
    return quote
        $(esc(ex))
        $(esc(ex))
    end
end
@twice println("hi")           # prints hi twice
@macroexpand @twice f(x)       # the code the macro produces
macro showtype(ex)
    s = string(ex)             # the code as text
    :(println($s, " :: ", typeof($(esc(ex)))))
end
@showtype 1 + 2.0              # 1 + 2.0 :: Float64
```

Wrap user code in `esc(...)`. Otherwise variable names in it are renamed to avoid clashes (macro hygiene) and refer to the wrong scope.

<details class="example">
<summary>Example</summary>

A timing macro that prints a label, and an `@unless` control-flow macro.

```julia
macro timed_as(label, ex)
    quote
        t0 = time_ns()
        val = $(esc(ex))
        println($(esc(label)), ": ", round((time_ns() - t0) / 1e6; digits = 1), " ms")
        val
    end
end

macro unless(cond, block)
    :( $(esc(cond)) || $(esc(block)) )
end

x = @timed_as "sort 10^6" sort(rand(10^6))
@unless issorted(x) error("not sorted")
@unless false println("this runs")
println(@macroexpand @unless a b)
```

</details>
</div>

<div class="cheatbox jl-pine">

## Useful built-in macros

```julia
x = [1.0, 2.0]; y = similar(x); A = rand(3, 3); v = zeros(3)
@show x y                       # print expressions and values
@assert all(x .> 0) "x must be positive"   # error if false
@time sum(x)
@kwdef struct Opts              # keyword constructor with defaults: Opts(n = 10)
    n::Int = 1000
    step::Float64 = 0.5
end
@. y = 2x^2 + 1                 # dot every call and operator
@views s = sum(A[:, 1])         # slices become views
@inbounds for i in eachindex(v) v[i] = 0 end   # skip bounds checks
@which sin(1.0)                 # the method that would run
# @edit sin(1.0)                # open its source in the editor
@doc sin                        # its documentation
```

`@kwdef` is exported from Base since Julia 1.9. In older versions write `Base.@kwdef`.

<details class="example">
<summary>Example</summary>

Settings with `@kwdef` and checks with `@assert`.

```julia
@kwdef struct MCMCOpts
    nsamples::Int = 5000
    burnin::Int = 1000
    step::Float64 = 0.5
    seed::Int = 1
end

function run(opts::MCMCOpts)
    @assert opts.burnin < opts.nsamples "burnin must be shorter than the run"
    println("running ", opts)
end

run(MCMCOpts())
run(MCMCOpts(step = 0.1, seed = 42))
try
    run(MCMCOpts(nsamples = 500))
catch e
    println("error: ", e.msg)
end
```

</details>
</div>

<div class="cheatbox jl-pine">

## Introspection and reflection

Look at a type's fields and a function's methods, and at each compiler stage of a call.

```julia
using InteractiveUtils
fieldnames(Complex)            # (:re, :im)
fieldtypes(Complex{Float64})   # (Float64, Float64)
getfield(1 + 2im, :im)         # 2
hasmethod(sin, (Float64,))     # true
methods(+) |> length           # well over 100
@code_lowered sqrt(2.0)        # lowered code
@code_typed sqrt(2.0)          # after type inference
@code_llvm sqrt(2.0)           # LLVM IR
@code_native sqrt(2.0)         # machine code
```

<details class="example">
<summary>Example</summary>

Print any struct as a table of fields, using only reflection.

```julia
function describe(x)
    T = typeof(x)
    println(T)
    for (name, FT) in zip(fieldnames(T), fieldtypes(T))
        println("  ", rpad(name, 8), rpad(FT, 18), getfield(x, name))
    end
end

struct Model
    name::String
    β::Vector{Float64}
    σ::Float64
end
describe(Model("probit", [0.5, -1.2], 1.0))
describe(3 + 4im)
describe(1:2:9)
```

</details>
</div>
