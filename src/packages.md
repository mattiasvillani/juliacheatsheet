---
title: Packages and environments
toc: true
---

# Packages and environments

<div class="cheatbox jl-olive">

## Package mode

Press `]` at the start of an empty REPL line. Each command also exists as a function in `Pkg`.

```julia norun
] add Distributions          # install the latest version; Pkg.add("Distributions")
] add Optim@1.9              # a specific version
] add https://github.com/user/Pkg.jl   # from a URL (unregistered package)
] rm Optim                   # remove
] st                         # status: packages in the active environment
] up                         # update all; ] up Distributions for one
] pin Optim                  # do not update it;  ] free Optim to undo
] gc                         # delete package versions no longer used
] compat                     # edit the allowed versions [compat] in Project.toml
```

`using Pkg; Pkg.add(["A", "B"])` installs several packages in scripts.

<details class="example">
<summary>Example</summary>

Run from a script, the same commands look like this.

```julia norun
import Pkg
Pkg.add(["Distributions", "Optim"])
Pkg.status()
Pkg.update("Distributions")
Pkg.rm("Optim")
```

</details>
</div>

<div class="cheatbox jl-olive">

## Project environments

An environment is a folder with `Project.toml` (the direct dependencies) and `Manifest.toml` (the exact versions of everything). Give each project its own environment so its package versions are recorded.

```julia norun
] activate .                 # use the environment in the current folder (created on first add)
] activate                   # back to the default environment @v1.12
] activate --temp            # a throw-away environment
] instantiate                # install exactly what Manifest.toml lists
julia --project=.            # start Julia in the environment in the current folder
Base.active_project()        # path of the active Project.toml
```

Packages in the default environment (`~/.julia/environments/v1.12`) are also visible from a project environment. Keep only tools like Revise and BenchmarkTools there.

<details class="example">
<summary>Example</summary>

Reproduce someone's results: clone their repository, then install the exact versions from their Manifest.

```julia norun
# in a terminal
#   git clone https://github.com/user/paper-code
#   cd paper-code
#   julia --project=.
import Pkg
Pkg.instantiate()          # same package versions as the authors
include("run_analysis.jl")
```

</details>
</div>

<div class="cheatbox jl-olive">

## `using`, `import` and modules

`using M` makes the exported names of `M` available. `import M` only brings in the name `M`.

```julia
using Statistics               # mean, std, ... available directly
using LinearAlgebra: norm, dot # only these names
import Random                  # use as Random.seed!(1)
import Base: show              # needed to add methods to show
module Geometry                # a module is a separate namespace
    export area
    area(r) = π * r^2
    perimeter(r) = 2π * r      # not exported
end
using .Geometry                # the dot: a module defined here, not a package
area(1.0), Geometry.perimeter(1.0)   # (3.141592653589793, 6.283185307179586)
```

`include("file.jl")` runs a file in the current module, as if pasted in. It is the way to split a module across files.

<details class="example">
<summary>Example</summary>

A small module with an exported API, a private helper and a new method for `Base.show`.

```julia
module Coins
export Coin, flip, estimate

struct Coin
    p::Float64
end
Base.show(io::IO, c::Coin) = print(io, "Coin(p = ", c.p, ")")

flip(c::Coin, n) = count(_ -> rand() < c.p, 1:n)
estimate(heads, n; a = 1, b = 1) = posterior_mean(heads + a, n - heads + b)
posterior_mean(α, β) = α / (α + β)           # internal helper
end

using .Coins, Random
Random.seed!(5)
c = Coin(0.3)
h = flip(c, 200)
println(c, ": ", h, " heads, posterior mean ", round(estimate(h, 200); digits = 3))
println(isdefined(Main, :posterior_mean), " ", Coins.posterior_mean(1, 1))
```

</details>
</div>

<div class="cheatbox jl-olive">

## Creating a package

A package is a module in `src/PkgName.jl` with a `Project.toml`. `Pkg.generate` makes the skeleton, and PkgTemplates.jl adds tests, CI and docs.

```julia norun
] generate MyPkg              # MyPkg/Project.toml and MyPkg/src/MyPkg.jl
] dev ./MyPkg                 # use the local folder; edits are picked up
using PkgTemplates            # a fuller skeleton with tests and GitHub Actions
Template(; user = "mattiasvillani", plugins = [Git(), GitHubActions()])("MyPkg")
] activate MyPkg; ] add Distributions   # dependencies go in MyPkg's Project.toml
] test MyPkg                  # runs MyPkg/test/runtests.jl
```

<details class="example">
<summary>Example</summary>

Generate a package in a temporary folder, add a function, and load it.

```julia
import Pkg
dir = mktempdir()
cd(dir) do
    Pkg.generate("Shrink"; io = devnull)
    write(joinpath("Shrink", "src", "Shrink.jl"), """
    module Shrink
    export shrink
    \"\"\"
        shrink(x, λ)
    Shrink each element of `x` towards its mean by the factor `λ`.
    \"\"\"
    shrink(x, λ) = (m = sum(x) / length(x); m .+ (1 - λ) .* (x .- m))
    end
    """)
    for (root, _, files) in walkdir("Shrink"), f in files
        println(joinpath(root, f))
    end
end
push!(LOAD_PATH, dir)            # instead of Pkg.dev, to keep this example self-contained
using Shrink
println(shrink([1.0, 2.0, 6.0], 0.5))
```

</details>
</div>

<div class="cheatbox jl-olive">

## Testing

The Test standard library gives `@test`, `@testset` and friends. A package's tests live in `test/runtests.jl`.

```julia
using Test
@test 1 + 1 == 2
@test sqrt(2)^2 ≈ 2                  # isapprox
@test 0.1 + 0.2 ≈ 0.3 atol = 1e-12
@test_throws DomainError sqrt(-1)
@testset "mean" begin                # groups tests and prints a summary
    @test sum([1, 2, 3]) / 3 == 2
    @test isempty(Int[])
end
@inferred sum([1, 2])                # error if the return type is not inferred
```

<details class="example">
<summary>Example</summary>

Test a function against known values, edge cases and an error, with tests grouped by `@testset`.

```julia
using Test

function softmax(x)
    isempty(x) && throw(ArgumentError("empty input"))
    e = exp.(x .- maximum(x))
    return e ./ sum(e)
end

@testset "softmax" begin
    @test softmax([0.0, 0.0]) == [0.5, 0.5]
    @test sum(softmax(randn(10))) ≈ 1
    @test softmax([1000.0, 1000.0]) ≈ [0.5, 0.5]      # no overflow
    @test softmax([1.0, 2.0]) ≈ softmax([101.0, 102.0])
    @test_throws ArgumentError softmax(Float64[])
    @test eltype(@inferred softmax([1f0, 2f0])) == Float32
end;
```

</details>
</div>

<div class="cheatbox jl-olive">

## Docstrings and help

A string just before a definition is its docstring. `?name` in the REPL shows it.

````julia
"""
    logit(p)

Log odds of the probability `p`. See also [`logistic`](@ref).

# Examples
```jldoctest
julia> logit(0.5)
0.0
```
"""
logit(p) = log(p / (1 - p))
@doc logit                       # the docstring, same as ?logit
````

The first line, indented by four spaces, shows how to call the function.

<details class="example">
<summary>Example</summary>

Docstrings can be read from code, here to list the documented functions of a module.

```julia
module Tools
"Log odds of `p`."
logit(p) = log(p / (1 - p))
"Inverse of `logit`."
logistic(x) = 1 / (1 + exp(-x))
helper(x) = x
end

for name in names(Tools; all = true)
    f = getfield(Tools, name)
    f isa Function || continue
    doc = Base.Docs.doc(Base.Docs.Binding(Tools, name))
    s = strip(string(doc))
    startswith(s, "No documentation") || println(rpad(name, 10), s)
end
```

</details>
</div>

<div class="cheatbox jl-olive">

## Revise and the REPL workflow

Revise.jl reloads changed code without restarting Julia. Load it first in every session.

```julia norun
] add Revise                 # in the default environment
using Revise                 # before loading your own code
includet("analysis.jl")      # track a script: edits to its functions are picked up
using MyPkg                  # packages under ] dev are tracked automatically
# ~/.julia/config/startup.jl: put `using Revise` here to load it automatically
```

Revise cannot pick up changes to a `struct` definition. Restart Julia, or rename the struct while you experiment.

<details class="example">
<summary>Example</summary>

A typical `~/.julia/config/startup.jl`.

```julia norun
try
    using Revise
catch e
    @warn "Revise not available" exception = e
end
ENV["JULIA_EDITOR"] = "code"     # @edit f(x) opens VS Code at the method
```

</details>
</div>
