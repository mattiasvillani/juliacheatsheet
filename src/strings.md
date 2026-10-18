---
title: Strings and files
toc: true
---

# Strings and files

<div class="cheatbox jl-brown">

## Strings and characters

Strings use double quotes and characters use single quotes. `*` joins strings and `$` interpolates.

```julia
s = "Julia"
'J'                         # a Char
s[1], s[end]                # ('J', 'a')
s * " is fast"              # "Julia is fast"   concatenation
"$s has $(length(s)) letters"   # "Julia has 5 letters"
s^2                         # "JuliaJulia"
"""multi
line"""                     # triple quotes for multiline strings
raw"C:\path"                # no escapes processed
string("x = ", 1.5)         # "x = 1.5"   convert and join anything
uppercase(s), lowercase(s)  # ("JULIA", "julia")
```

Strings are UTF-8, so indices are byte positions: `"αβ"[2]` is an error. Use `collect(s)`, `first(s, n)` or `eachindex(s)` for non-ASCII text.

<details class="example">
<summary>Example</summary>

Iterate over characters, count them, and handle non-ASCII text safely.

```julia
s = "Bayes för alla"
println(length(s), " characters, ", ncodeunits(s), " bytes")
println("first 7: ", first(s, 7))
println("reversed: ", reverse(s))
counts = Dict{Char,Int}()
for c in lowercase(s)
    isletter(c) && (counts[c] = get(counts, c, 0) + 1)
end
println(sort(collect(counts); by = last, rev = true)[1:3])
```

</details>
</div>

<div class="cheatbox jl-brown">

## Searching, splitting and replacing

```julia
s = "a,b,,c"
split(s, ",")                    # ["a", "b", "", "c"]   SubStrings
split("x  y z")                  # ["x", "y", "z"]       on whitespace
join(["a", "b", "c"], "-")       # "a-b-c"
strip("  hi \n")                 # "hi"     also lstrip, rstrip
replace("a-b-c", "-" => "+")     # "a+b+c"
occursin("b,", s)                # true
startswith(s, "a"), endswith(s, "c")   # (true, true)
findfirst("b", s)                # 3:3
parse(Int, "42"), parse(Float64, "2.5")   # (42, 2.5)
tryparse(Int, "x")               # nothing  instead of an error
lpad(7, 3, "0"), rpad("a", 3) * "|"       # ("007", "a  |")
```

<details class="example">
<summary>Example</summary>

Parse lines of `key = value` settings into a dictionary of numbers, skipping comments and bad values.

```julia
config = """
# sampler settings
nsamples = 5000
burnin   = 1000
step     = 0.35
thin     = two     # not a number
"""
settings = Dict{String,Float64}()
for line in split(config, "\n")
    line = strip(split(line, "#")[1])       # drop comments
    isempty(line) && continue
    key, value = strip.(split(line, "="))
    x = tryparse(Float64, value)
    isnothing(x) ? println("skipping $key = $value") : (settings[key] = x)
end
println(settings)
```

</details>
</div>

<div class="cheatbox jl-brown">

## Regular expressions

Regex literals are `r"..."`. Captured groups are in `m.captures` or by name.

```julia
r = r"(\d+)-(\d+)"
occursin(r, "pages 10-20")            # true
m = match(r, "pages 10-20")
m.match, m.captures                   # ("10-20", ["10", "20"])
m = match(r"(?<from>\d+)-(?<to>\d+)", "10-20"); m["to"]   # "20"
[x.match for x in eachmatch(r"\d+", "a1b22c333")]   # ["1", "22", "333"]
replace("2026-10-18", r"(\d+)-(\d+)-(\d+)" => s"\3/\2/\1")   # "18/10/2026"
```

<details class="example">
<summary>Example</summary>

Extract numbers with their units from free text.

```julia
text = "Draws took 12.5 s, the warmup 3 s, and memory peaked at 1.2 GB (0.8 GB after GC)."
for m in eachmatch(r"(?<value>\d+(\.\d+)?)\s*(?<unit>s|GB)\b", text)
    println(rpad(m["unit"], 3), parse(Float64, m["value"]))
end
seconds = sum(parse(Float64, m["v"]) for m in eachmatch(r"(?<v>[\d.]+) s\b", text))
println("total seconds: ", seconds)
```

</details>
</div>

<div class="cheatbox jl-brown">

## Formatting numbers

`round` and `string` are enough for quick output. `@printf` and `@sprintf` from Printf give C-style format control.

```julia
using Printf
round(π; digits = 3)              # 3.142
round(123456; sigdigits = 2)      # 120000
@printf("%.3f\n", π)              # 3.142
@printf("%8.2e|%-6d|%5s\n", 12345.678, 42, "ab")   # 1.23e+04|42    |   ab
s = @sprintf("%5.1f%%", 12.345)   # " 12.3%"
@printf("%d draws, mean %.2f\n", 1000, 0.4567)     # 1000 draws, mean 0.46
```

<details class="example">
<summary>Example</summary>

A posterior summary table with aligned columns.

```julia
using Printf, Random, Statistics
rng = Xoshiro(2)
draws = Dict("μ" => 2 .+ 0.1 .* randn(rng, 4000),
             "σ" => exp.(0.5 .+ 0.05 .* randn(rng, 4000)),
             "β₁" => -1.5 .+ 0.8 .* randn(rng, 4000))
@printf("%-4s %8s %8s %8s %8s\n", "par", "mean", "sd", "q2.5", "q97.5")
for name in sort(collect(keys(draws)))
    x = draws[name]
    @printf("%-4s %8.3f %8.3f %8.3f %8.3f\n", name, mean(x), std(x), quantile(x, 0.025), quantile(x, 0.975))
end
```

</details>
</div>

<div class="cheatbox jl-brown">

## Reading and writing text files

`open` with a `do` block closes the file for you. `read`, `write` and `readlines` handle whole files at once.

```julia
write("notes.txt", "line 1\nline 2\n")   # create or overwrite, returns bytes written
read("notes.txt", String)                # "line 1\nline 2\n"
readlines("notes.txt")                   # ["line 1", "line 2"]
open("notes.txt", "a") do io             # "w" write, "a" append, "r" read (default)
    println(io, "line 3")
end
for line in eachline("notes.txt")        # one line at a time, for big files
    println(line)
end
isfile("notes.txt"), filesize("notes.txt")   # (true, 21)
```

<details class="example">
<summary>Example</summary>

Write a log during a simulation and summarise it afterwards by reading it back line by line.

```julia
using Random
cd(mktempdir()) do
    rng = Xoshiro(3)
    open("log.txt", "w") do io
        for iter in 1:1000
            accepted = rand(rng) < 0.3
            println(io, iter, " ", accepted)
        end
    end
    nacc = 0
    for line in eachline("log.txt")
        _, acc = split(line)
        nacc += parse(Bool, acc)
    end
    println("acceptance rate = ", nacc / countlines("log.txt"))
end
```

</details>
</div>

<div class="cheatbox jl-brown">

## Paths and directories

Build paths with `joinpath` so the code works on Windows too.

```julia
p = joinpath("data", "raw", "y.csv")   # "data/raw/y.csv"
dirname(p), basename(p)                # ("data/raw", "y.csv")
splitext(p)                            # ("data/raw/y", ".csv")
pwd()                                  # current directory;  cd("path") to change
homedir(), tempdir()
@__DIR__                               # directory of the current file
mkpath("data/raw")                     # make directory and parents
readdir("data")                        # ["raw"]
isdir("data"), ispath(p)               # (true, false)
rm("data"; recursive = true)
```

In a script, `joinpath(@__DIR__, "data.csv")` finds files next to the script whatever the current directory is.

<details class="example">
<summary>Example</summary>

Find all files with a given extension below a directory with `walkdir`.

```julia
root = mktempdir()
for f in ("a.csv", "b.txt", joinpath("sub", "c.csv"), joinpath("sub", "deep", "d.csv"))
    mkpath(dirname(joinpath(root, f)))
    write(joinpath(root, f), "x\n")
end
csvs = String[]
for (dir, _, files) in walkdir(root)
    for f in files
        endswith(f, ".csv") && push!(csvs, relpath(joinpath(dir, f), root))
    end
end
println(sort(csvs))
```

</details>
</div>

<div class="cheatbox jl-brown">

## Saving Julia objects

Serialization (built in) saves any Julia value; JLD2.jl writes HDF5-compatible files that are better for long-term storage. DelimitedFiles reads and writes plain numeric matrices.

```julia
using Serialization, JLD2, DelimitedFiles
draws = randn(1000, 3)
serialize("draws.jls", draws); deserialize("draws.jls")   # any value; same Julia version
jldsave("res.jld2"; draws, info = "run 1")    # named variables
load("res.jld2", "draws")                     # one variable;  load("res.jld2") gives a Dict
writedlm("draws.txt", draws)                  # tab separated text
readdlm("draws.txt")                          # 1000×3 Matrix{Float64}
```

Files from `serialize` may not load in another Julia version, so use JLD2 or CSV for results you want to keep.

<details class="example">
<summary>Example</summary>

Save MCMC output with its settings in one JLD2 file and load it back.

```julia
using JLD2, Random
cd(mktempdir()) do
    rng = Xoshiro(4)
    draws = cumsum(randn(rng, 2000, 2); dims = 1) ./ 50
    settings = (sampler = "RWM", step = 0.4, seed = 4)
    jldsave("chain.jld2"; draws, settings)

    f = load("chain.jld2")
    println(keys(f))
    println(f["settings"])
    println(size(f["draws"]), " ", f["draws"] == draws)
end
```

</details>
</div>
