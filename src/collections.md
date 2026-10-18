---
title: Collections
toc: true
---

# Collections

<div class="cheatbox jl-purple">

## Vector as a stack (LIFO)

The end of the vector is the top of the stack.
`push!` and `pop!` are amortized O(1).

```julia
s = Int[]
push!(s, 1); push!(s, 2); push!(s, 3)
last(s)     # 3    peek at top, no removal
pop!(s)     # 3    remove and return top
s           # [1, 2]
```

A `Vector` also allows `s[2]`, so nothing enforces LIFO.

<details class="example">
<summary>Example</summary>

Check that brackets are balanced: push each opening bracket, and on a closing bracket pop and check that it matches.

```julia
function isbalanced(str)
    pairs = Dict(')' => '(', ']' => '[', '}' => '{')
    stack = Char[]
    for c in str
        if c in values(pairs)
            push!(stack, c)
        elseif haskey(pairs, c)
            isempty(stack) && return false
            pop!(stack) == pairs[c] || return false
        end
    end
    return isempty(stack)
end

for str in ("f(x[1], {a, b})", "f(x[1)]", "((")
    println(rpad(str, 16), isbalanced(str))
end
```

```text
f(x[1], {a, b}) true
f(x[1)]         false
((              false
```

</details>
</div>

<div class="cheatbox jl-purple">

## Add / remove at the ends

Mutating functions end in `!`. Adders return the collection, removers return the removed element.

```julia
v = [2, 3]
push!(v, 4)          # [2, 3, 4]    add last
pushfirst!(v, 1)     # [1, 2, 3, 4] add first
pop!(v)              # 4            remove last
popfirst!(v)         # 1            remove first
append!(v, [7, 8])   # [2, 3, 7, 8] add many last
prepend!(v, [0])     # [0, 2, 3, 7, 8]
empty!(v)            # []
```

<details class="example">
<summary>Example</summary>

A FIFO queue: `push!` at the back, `popfirst!` from the front. Here it runs a breadth-first search to get each node's distance from a start node.

```julia
# node => neighbours
graph = Dict(1 => [2, 3], 2 => [4], 3 => [4, 5],
             4 => [6], 5 => [6], 6 => Int[])

function bfs_distances(graph, start)
    dist = Dict(start => 0)
    queue = [start]
    while !isempty(queue)
        node = popfirst!(queue)          # take from the front
        for nb in graph[node]
            haskey(dist, nb) && continue
            dist[nb] = dist[node] + 1
            push!(queue, nb)             # add to the back
        end
    end
    return dist
end

bfs_distances(graph, 1)
```

```text
Dict{Int64, Int64} with 6 entries:
  5 => 2
  4 => 2
  6 => 3
  2 => 1
  3 => 1
  1 => 0
```

The same pattern gives a moving window over a stream, for example the last `k` MCMC draws:

```julia
window = Float64[]
k = 3
for draw in [0.5, 1.2, 0.9, 1.4, 1.1]
    push!(window, draw)
    length(window) > k && popfirst!(window)
    println("window = ", window, "   mean = ", sum(window) / length(window))
end
```

```text
window = [0.5]   mean = 0.5
window = [0.5, 1.2]   mean = 0.85
window = [0.5, 1.2, 0.9]   mean = 0.8666666666666667
window = [1.2, 0.9, 1.4]   mean = 1.1666666666666667
window = [0.9, 1.4, 1.1]   mean = 1.1333333333333333
```

</details>
</div>

<div class="cheatbox jl-purple">

## Remove / insert at a position

`popat!` returns the removed element, `deleteat!` returns the vector. Both are O(n) in the middle.

```julia
v = [10, 20, 30, 40]
popat!(v, 2)         # 20           v is [10, 30, 40]
deleteat!(v, 2)      # [10, 40]     returns v
insert!(v, 2, 99)    # [10, 99, 40]

w = collect(1:10)
deleteat!(w, 3:5)    # range of indices
deleteat!(w, [1, 2]) # sorted indices
filter!(isodd, w)    # keep where true
```

<details class="example">
<summary>Example</summary>

Keep a vector sorted while adding values: `searchsortedfirst` finds the position and `insert!` puts the value there. Then `deleteat!` removes the outliers.

```julia
sorted = Float64[]
for x in [3.2, -1.0, 7.5, 0.4, 12.0, 2.2]
    insert!(sorted, searchsortedfirst(sorted, x), x)
end
println("sorted   ", sorted)

# remove values outside [0, 10]; deleteat! needs sorted, unique indices
bad = findall(x -> x < 0 || x > 10, sorted)
deleteat!(sorted, bad)
println("trimmed  ", sorted)

# remove the 2nd element and keep it
removed = popat!(sorted, 2)
println("removed ", removed, ", left ", sorted)

# filter! is often simpler than finding indices yourself
v = collect(1:10)
filter!(x -> x % 3 != 0, v)
```

```text
sorted   [-1.0, 0.4, 2.2, 3.2, 7.5, 12.0]
trimmed  [0.4, 2.2, 3.2, 7.5]
removed 2.2, left [0.4, 3.2, 7.5]
7-element Vector{Int64}:
  1
  2
  4
  5
  7
  8
 10
```

</details>
</div>

<div class="cheatbox jl-purple">

## `pop!` on Dict and Set

Without positions, `pop!` takes the key or element to remove.

```julia
d = Dict(:a => 1, :b => 2)
pop!(d, :a)          # 1    removes key, returns value
pop!(d, :z, 0)       # 0    default if key missing

s = Set([1, 2, 3])
pop!(s, 2)           # 2    removes that element
```

<details class="example">
<summary>Example</summary>

Use `pop!` to take out options you handle yourself before passing the remaining keyword arguments on.

```julia
function fit(data; kwargs...)
    opts = Dict{Symbol,Any}(kwargs)
    nIter = pop!(opts, :nIter, 1000)     # default if not given
    verbose = pop!(opts, :verbose, false)
    isempty(opts) || println("ignoring unused options: ", join(keys(opts), ", "))
    return (nIter = nIter, verbose = verbose)
end

println(fit([1, 2]; nIter = 500))
println(fit([1, 2]; verbose = true, thin = 2))   # `thin` is ignored
```

```text
(nIter = 500, verbose = false)
ignoring unused options: thin
(nIter = 1000, verbose = true)
```

A `Set` of unvisited items, emptied one by one:

```julia
todo = Set(["chain1", "chain2", "chain3"])
pop!(todo, "chain2")             # finished chain2
println(sort(collect(todo)))
while !isempty(todo)
    println("running ", pop!(todo))   # pop! without a key: some element
end
```

```text
["chain1", "chain3"]
running chain3
running chain1
```

</details>
</div>

<div class="cheatbox jl-purple">

## `stack` (Base, Julia 1.9+)

Joins an iterable of arrays into one higher-dimensional array.

```julia
v = [[1, 2, 3], [4, 5, 6]]
stack(v)              # 3×2, vectors as columns
stack(v, dims=1)      # 2×3, vectors as rows
stack(x -> x .^ 2, v) # map, then stack
```

Replaces `reduce(hcat, v)`. Handy for turning posterior draws (a vector of parameter vectors) into a matrix.

<details class="example">
<summary>Example</summary>

A random-walk Metropolis sampler stores each draw as a vector. `stack` then turns the draws into a matrix for summaries.

```julia
using Random, Statistics
Random.seed!(1)

logpost(θ) = -0.5 * (θ[1]^2 + (θ[2] - 1)^2 / 4)   # N(0,1) × N(1,4)

function rwm(logpost, θ0, nIter; step = 1.0)
    draws = Vector{Vector{Float64}}()
    θ = copy(θ0)
    for _ in 1:nIter
        prop = θ .+ step .* randn(length(θ))
        if log(rand()) < logpost(prop) - logpost(θ)
            θ = prop
        end
        push!(draws, copy(θ))
    end
    return draws
end

draws = rwm(logpost, [0.0, 0.0], 10_000)
D = stack(draws, dims = 1)        # 10000 × 2, one row per draw
size(D)
```

```text
(10000, 2)
```

```julia
println("posterior means ", mean(D, dims = 1))   # ≈ (0, 1)
println("posterior sds   ", std(D, dims = 1))    # ≈ (1, 2)
```

```text
posterior means [-0.001924490830116062 0.9191160936094673]
posterior sds   [1.0237510603891709 2.011004535645152]
```

</details>
</div>
