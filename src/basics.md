---
title: Basics
toc: true
---

# Basics

<div class="cheatbox jl-navy">

## Numbers and arithmetic

Integer literals are `Int64` and literals with a decimal point are `Float64`. `/` always returns a float, while `÷` is integer division.

```julia
x = 7; y = 2
x / y            # 3.5       always Float64
x ÷ y            # 3         integer division (\div<tab>), same as div(x, y)
x % y            # 1         remainder, same as rem(x, y)
mod(-7, 3)       # 2         mod has the sign of the divisor; rem(-7, 3) is -1
x^y              # 49
2x + 1           # 15        a number before a variable multiplies
1 // 3 + 1 // 6  # 1//2      exact rationals
sqrt(-1 + 0im)   # 0.0 + 1.0im
big(2)^100       # 1267650600228229401496703205376
```

Integers wrap around on overflow without warning: `2^64` is `0`. Use `big(2)^64` or floats when numbers get large.

<details class="example">
<summary>Example</summary>

Integer overflow, the float epsilon and exact rational arithmetic.

```julia
println(typemax(Int), " + 1 = ", typemax(Int) + 1)
println("factorial(20) = ", factorial(20))
println("factorial(big(25)) = ", factorial(big(25)))
println("eps() = ", eps(), ", 0.1 + 0.2 == 0.3 is ", 0.1 + 0.2 == 0.3)
println("0.1 + 0.2 ≈ 0.3 is ", 0.1 + 0.2 ≈ 0.3)

# the harmonic sum 1 + 1/2 + ... + 1/10, exactly and in floating point
h = sum(1 // k for k in 1:10)
println("exact: ", h, " = ", float(h))
```

```text
9223372036854775807 + 1 = -9223372036854775808
factorial(20) = 2432902008176640000
factorial(big(25)) = 15511210043330985984000000
eps() = 2.220446049250313e-16, 0.1 + 0.2 == 0.3 is false
0.1 + 0.2 ≈ 0.3 is true
exact: 7381//2520 = 2.9289682539682538
```

</details>
</div>

<div class="cheatbox jl-navy">

## Variables, Unicode and math functions

Names may use Unicode: type `\alpha` then Tab in the REPL or editor to get `α`. Many maths constants and functions are built in.

```julia
α = 0.05; σ² = 4.0     # \alpha<tab>, \sigma<tab>\^2<tab>
π                      # π = 3.1415926535897...
ℯ                      # ℯ = 2.7182818284590...  (\euler<tab>)
exp(1), log(ℯ), log10(100), log2(8), log(2, 8)   # (2.718281828459045, 1.0, 2.0, 3.0, 3.0)
round(2.567; digits = 2)    # 2.57
round(Int, 2.5)             # 2        rounds half to even
floor(Int, 2.7), ceil(Int, 2.1)   # (2, 3)
abs(-3), sign(-3), hypot(3, 4)    # (3, -1, 5.0)
0.1 + 0.2 ≈ 0.3             # true     isapprox (\approx<tab>)
```

Use `log1p(x)` and `expm1(x)` for small `x`, and `logsumexp`-style code to avoid underflow with log probabilities.

<details class="example">
<summary>Example</summary>

Normalise log weights without underflow by subtracting the maximum before exponentiating.

```julia
logw = [-1000.0, -1001.0, -1002.5]
naive = exp.(logw) ./ sum(exp.(logw))
m = maximum(logw)
w = exp.(logw .- m)
w ./= sum(w)
println("naive:  ", naive)
println("stable: ", round.(w; digits = 4))
println("log of sum: ", m + log(sum(exp.(logw .- m))))
```

```text
naive:  [NaN, NaN, NaN]
stable: [0.6897, 0.2537, 0.0566]
log of sum: -999.6284609681474
```

</details>
</div>

<div class="cheatbox jl-navy">

## Control flow

Blocks end with `end`. Conditions must be `Bool`: `if 1` is an error.

```julia
x = 3
if x > 0
    println("positive")
elseif x == 0
    println("zero")
else
    println("negative")
end
s = x > 0 ? "pos" : "nonpos"   # ternary operator
x > 0 && println("pos")        # run right side only if left is true
x > 0 || error("x must be positive")   # run right side only if left is false
for i in 1:3                   # also: for i = 1:3, for i ∈ 1:3
    i == 2 && continue         # skip to the next iteration
    println(i)
end
while x > 0
    x -= 1                     # x = x - 1
end
```

`&&` and `||` short-circuit, so `cond && return x` is a common one-line early return.

<details class="example">
<summary>Example</summary>

The Collatz sequence: halve even numbers, map odd `n` to `3n + 1`, and count the steps until 1.

```julia
function collatz_steps(n)
    steps = 0
    while n != 1
        n = iseven(n) ? n ÷ 2 : 3n + 1
        steps += 1
    end
    return steps
end

best = 0
for n in 1:10_000
    s = collatz_steps(n)
    if s > best
        best = s
        n > 1000 && println("n = $n takes $s steps")
    end
end
```

```text
n = 1161 takes 181 steps
n = 2223 takes 182 steps
n = 2463 takes 208 steps
n = 2919 takes 216 steps
n = 3711 takes 237 steps
n = 6171 takes 261 steps
```

</details>
</div>

<div class="cheatbox jl-navy">

## Ranges, comprehensions and generators

A range is lazy: `1:10^9` uses no memory. `collect` turns it into a `Vector`.

```julia
r = 1:5                         # 1:5          UnitRange, step 1
0:0.25:1                        # 0.0:0.25:1.0 start:step:stop
range(0, 1; length = 5)         # 0.0:0.25:1.0
10:-2:1                         # 10:-2:2      counting down
collect(r)                      # [1, 2, 3, 4, 5]
[i^2 for i in 1:4]              # [1, 4, 9, 16]       comprehension
[i^2 for i in 1:6 if iseven(i)] # [4, 16, 36]         with a filter
[i + 10j for i in 1:2, j in 1:3]   # 2×3 Matrix
sum(i^2 for i in 1:4)           # 30           generator: no array allocated
for (i, x) in enumerate([:a, :b])  end   # (1, :a), (2, :b)
for (x, y) in zip(1:3, "abc")  end      # (1, 'a'), (2, 'b'), (3, 'c')
```

Writing `sum(x^2 for x in v)` without brackets avoids building the temporary array.

<details class="example">
<summary>Example</summary>

A table of the binomial(10, 0.3) probabilities from a comprehension, and the mean from a generator.

```julia
n, p = 10, 0.3
probs = [binomial(n, k) * p^k * (1 - p)^(n - k) for k in 0:n]
for (k, pk) in zip(0:n, probs)
    pk > 0.01 && println(lpad(k, 2), "  ", rpad(round(pk; digits = 4), 7), "*"^round(Int, 100pk))
end
println("sum = ", sum(probs), ", mean = ", sum(k * probs[k+1] for k in 0:n))
```

```text
 0  0.0282 ***
 1  0.1211 ************
 2  0.2335 ***********************
 3  0.2668 ***************************
 4  0.2001 ********************
 5  0.1029 **********
 6  0.0368 ****
sum = 0.9999999999999993, mean = 2.9999999999999987
```

</details>
</div>

<div class="cheatbox jl-navy">

## Indexing and slicing

Indexing starts at 1 and `end` is the last index. Arrays are stored column by column.

```julia
v = [10, 20, 30, 40, 50]
v[1], v[end], v[end-1]   # (10, 50, 40)
v[2:4]                   # [20, 30, 40]   a slice is a copy
v[[1, 3]]                # [10, 30]       index with a vector
v[v .> 25]               # [30, 40, 50]   logical indexing
findall(v .> 25)         # [3, 4, 5]
A = [1 2 3; 4 5 6]       # 2×3 Matrix, rows separated by ;
A[2, 3]                  # 6
A[:, 2]                  # [2, 5]         column 2 (a Vector)
A[1, :]                  # [1, 2, 3]      row 1 (also a Vector)
vec(A)                   # [1, 4, 2, 5, 3, 6]   column-major order
@view A[:, 2]            # no copy; writes go to A
```

`b = a` does not copy: both names refer to the same array. Use `b = copy(a)`.

<details class="example">
<summary>Example</summary>

Slices copy but views do not, and assignment shares the array.

```julia
a = collect(1:5)
b = a              # same array
c = a[1:3]         # copy
d = @view a[1:3]   # view into a
a[1] = 100
println("b = ", b)
println("c = ", c)
println("d = ", d)

A = zeros(Int, 3, 3)
A[2, :] .= 7       # .= writes into the existing row
A[:, 3] = [1, 2, 3]
display(A)
```

```text
b = [100, 2, 3, 4, 5]
c = [1, 2, 3]
d = [100, 2, 3]
3×3 Matrix{Int64}:
 0  0  1
 7  7  2
 0  0  3
```

</details>
</div>

<div class="cheatbox jl-navy">

## Scope

Functions, loops and `let` blocks make new local scopes. Inside a function, loops can update the function's local variables. At the top level of a script a loop that assigns to a global gets a warning.

```julia
function total(v)
    s = 0
    for x in v
        s += x            # fine: s is local to the function
    end
    return s
end
let s = 0                 # let makes a local scope at the top level
    for i in 1:3; s += i; end
    s                     # 6
end
global s = 0              # in a script: for i in 1:3; global s += i; end
```

In the REPL, loops can update globals without `global`. Code that touches globals is slow, so put work in functions.

<details class="example">
<summary>Example</summary>

Closures capture variables, and each loop iteration gets a fresh binding.

```julia
fs = Function[]
for i in 1:3
    push!(fs, () -> i^2)   # each closure captures its own i
end
println([f() for f in fs])

function counter()
    n = 0
    return () -> (n += 1)  # n lives on in the closure
end
c = counter()
c(); c()
println("called ", c(), " times")
```

```text
[1, 4, 9]
called 3 times
```

</details>
</div>

<div class="cheatbox jl-navy">

## `nothing`, `missing` and `NaN`

Three different kinds of "no value".

```julia
nothing                  # no value: what a function returns when there is no result
findfirst(==(9), [1, 2]) # nothing
isnothing(nothing)       # true
missing                  # unknown data value; it propagates
missing + 1              # missing
sum(skipmissing([1, missing, 3]))   # 4
coalesce(missing, 0)     # 0
NaN                      # Float64 "not a number", e.g. 0/0
NaN == NaN               # false     use isnan(x)
isequal(NaN, NaN)        # true
```

`x == missing` is `missing`, not `false`; use `ismissing(x)`.

<details class="example">
<summary>Example</summary>

Statistics on a vector with missing values, and a search that may find nothing.

```julia
using Statistics
x = [2.1, missing, 3.4, 1.8, missing, 2.9]
println("mean(x) = ", mean(x))
println("mean without missing = ", mean(skipmissing(x)))
println("number missing = ", count(ismissing, x))
println("filled = ", coalesce.(x, 0.0))

i = findfirst(v -> !ismissing(v) && v > 5, x)
println(isnothing(i) ? "no value above 5" : "first above 5 at $i")
```

```text
mean(x) = missing
mean without missing = 2.55
number missing = 2
filled = [2.1, 0.0, 3.4, 1.8, 0.0, 2.9]
no value above 5
```

</details>
</div>

<div class="cheatbox jl-navy">

## Printing and inspecting

`println` prints its arguments and a newline. `$` interpolates into strings.

```julia
x = [1.5, 2.0]
println("x = $x, sum = $(sum(x))")   # x = [1.5, 2.0], sum = 3.5
print("no newline"); println()
@show x                    # x = [1.5, 2.0]
display(x)                 # pretty-printed as in the REPL
typeof(x), eltype(x)       # (Vector{Float64}, Float64)
size(x), length(x)         # ((2,), 2)
x isa AbstractVector       # true
```

Inside a function only explicit output is printed. Use `@show` or `display` to see a value.

<details class="example">
<summary>Example</summary>

`@show` prints an expression and its value, which is handy for debugging.

```julia
function roots(a, b, c)
    d = b^2 - 4a*c
    @show d
    d < 0 && return ()
    return ((-b - sqrt(d)) / 2a, (-b + sqrt(d)) / 2a)
end
r = roots(1, -3, 2)
@show r typeof(r)
roots(1, 0, 1)
```

```text
d = 1
r = (1.0, 2.0)
typeof(r) = Tuple{Float64, Float64}
d = -4
()
```

</details>
</div>
