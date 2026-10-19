---
title: Linear algebra
toc: true
---

# Linear algebra

Most functions below need `using LinearAlgebra` (a standard library, no install needed).

<div class="cheatbox jl-green">

## Building vectors and matrices

Spaces separate columns, `;` or newlines separate rows. Commas make a vector.

```julia
using LinearAlgebra
x = [1, 2, 3]           # 3-element Vector (a column)
r = [1 2 3]             # 1×3 Matrix (a row)
A = [1 2; 3 4]          # 2×2 Matrix
zeros(2, 3), ones(2), fill(0.5, 2, 2)
Matrix(1.0I, 2, 2)      # [1.0 0.0; 0.0 1.0]
reshape(1:6, 2, 3)      # [1 3 5; 2 4 6]  column-major
[A A]                   # 2×4  same as hcat(A, A)
[A; A]                  # 4×2  same as vcat(A, A)
size(A), size(A, 1)     # ((2, 2), 2)
A'                      # [1 3; 2 4]  adjoint (transpose for reals)
vec(A)                  # [1, 3, 2, 4]
```

`I` is a lazy identity of any size: `A + I` adds 1 to the diagonal.

<details class="example">
<summary>Example</summary>

Build a design matrix for polynomial regression: an intercept column, then powers of `x`.

```julia
x = [0.5, 1.0, 1.5, 2.0, 2.5]
degree = 3

X = [x[i]^p for i in eachindex(x), p in 0:degree]   # rows i, columns p
```

```text
5×4 Matrix{Float64}:
 1.0  0.5  0.25   0.125
 1.0  1.0  1.0    1.0
 1.0  1.5  2.25   3.375
 1.0  2.0  4.0    8.0
 1.0  2.5  6.25  15.625
```

```julia
# the same with hcat and broadcasting
X2 = hcat(ones(length(x)), x, x .^ 2, x .^ 3)
X2 == X, size(X)
```

```text
(true, (5, 4))
```

```julia
# add a dummy variable column and drop the cubic term
group = [0, 0, 1, 1, 1]
Xd = [X[:, 1:3] group]
```

```text
5×4 Matrix{Float64}:
 1.0  0.5  0.25  0.0
 1.0  1.0  1.0   0.0
 1.0  1.5  2.25  1.0
 1.0  2.0  4.0   1.0
 1.0  2.5  6.25  1.0
```

</details>
</div>

<div class="cheatbox jl-green">

## Products and norms

`*` is the matrix product, `.*` is elementwise.

```julia
using LinearAlgebra
x, y = [1, 2, 3], [4, 5, 6]
A = [1 2; 3 4]
dot(x, y)               # 32    also x ⋅ y  (type \cdot<tab>)
x' * y                  # 32    row times column
x * y'                  # 3×3 outer product
A * A                   # [7 10; 15 22]
A .* A                  # [1 4; 9 16]
A^2 == A * A            # true
norm(x)                 # 3.7416...  Euclidean
norm(x, 1), norm(x, Inf)  # (6.0, 3.0)
cross(x, y)             # [-3, 6, -3]
kron(I(2), A)           # 4×4 block diagonal
```

<details class="example">
<summary>Example</summary>

Cosine similarity between the columns of a matrix, and quadratic forms.

```julia
using LinearAlgebra

W = [1.0 0.0 2.0;
     1.0 1.0 2.0;
     0.0 1.0 0.0]

cosine(a, b) = dot(a, b) / (norm(a) * norm(b))

S = [cosine(W[:, i], W[:, j]) for i in 1:3, j in 1:3]
round.(S, digits = 3)
```

```text
3×3 Matrix{Float64}:
 1.0  0.5  1.0
 0.5  1.0  0.5
 1.0  0.5  1.0
```

```julia
# the quadratic form x'Σx, three equivalent ways
Σ = [2.0 0.5; 0.5 1.0]
x = [1.0, -2.0]
x' * Σ * x, dot(x, Σ, x), sum(x .* (Σ * x))
```

```text
(4.0, 4.0, 4.0)
```

</details>
</div>

<div class="cheatbox jl-green">

## Solving linear systems

Use `A \ b` to solve `Ax = b`. It picks a suitable factorization and is faster and more accurate than `inv(A) * b`.

```julia
using LinearAlgebra
A = [4.0 1; 1 3]
b = [1.0, 2]
x = A \ b               # [0.0909..., 0.6363...]
A * x ≈ b               # true
inv(A)                  # avoid unless you need the matrix itself
det(A), logdet(A)       # (11.0, 2.397...)
tr(A), rank(A)          # (7.0, 2)
X = [1 1; 1 2; 1 3.0]   # tall: \ gives least squares
X \ [1, 2, 2.0]         # [0.666..., 0.5]
pinv(X)                 # Moore–Penrose pseudo-inverse
```

`≈` is `isapprox` (type `\approx<tab>`). Use it, not `==`, to compare floating-point results.

<details class="example">
<summary>Example</summary>

Ordinary least squares on simulated data: `X \ y` against the normal equations.

```julia
using LinearAlgebra, Random
Random.seed!(3)

n = 100
X = [ones(n) randn(n) randn(n)]
β = [1.0, 2.0, -0.5]
y = X * β + 0.3 * randn(n)

βhat = X \ y                     # QR-based least squares
βnormal = (X'X) \ (X'y)          # normal equations: fine here, less stable in general
[β βhat βnormal]
```

```text
3×3 Matrix{Float64}:
  1.0   1.01635    1.01635
  2.0   2.02566    2.02566
 -0.5  -0.495073  -0.495073
```

```julia
resid = y - X * βhat
σ2 = sum(abs2, resid) / (n - size(X, 2))
se = sqrt.(σ2 * diag(inv(X'X)))
round.([βhat se], digits = 3)    # estimates and standard errors
```

```text
3×2 Matrix{Float64}:
  1.016  0.032
  2.026  0.033
 -0.495  0.033
```

</details>
</div>

<div class="cheatbox jl-green">

## Special matrix types

Tell Julia about structure: storage is smaller and `\`, `*`, `det` use faster methods.

```julia
using LinearAlgebra
D = Diagonal([1.0, 2, 3])       # stores only the diagonal
D \ [1.0, 2, 3]                 # [1.0, 1.0, 1.0], O(n)
S = Symmetric([2.0 1; 0 2])     # uses the upper triangle
S                               # [2.0 1.0; 1.0 2.0]
issymmetric([2.0 1; 1 2])       # true
U = UpperTriangular([1.0 2; 3 4])  # [1.0 2.0; 0.0 4.0]
T = SymTridiagonal([2.0, 2, 2], [-1.0, -1])  # 3×3 tridiagonal
diag(T), diag(T, 1)             # ([2.0, 2.0, 2.0], [-1.0, -1.0])
Diagonal(T)                     # keep only the diagonal
Matrix(T)                       # convert to a dense matrix
```

Wrap a computed covariance matrix in `Symmetric` before `cholesky` so rounding errors do not make it fail the symmetry check.

<details class="example">
<summary>Example</summary>

The precision matrix of a stationary AR(1) process is tridiagonal. Using `SymTridiagonal` makes solves and log determinants O(n) instead of O(n³).

```julia
using LinearAlgebra

function ar1_precision(n, ϕ, σ2)
    d = fill(1 + ϕ^2, n)
    d[1] = d[n] = 1.0
    return SymTridiagonal(d, fill(-ϕ, n - 1)) / σ2
end

Q = ar1_precision(5, 0.8, 1.0)
```

```text
5×5 LinearAlgebra.SymTridiagonal{Float64, Vector{Float64}}:
  1.0  -0.8     ⋅      ⋅      ⋅ 
 -0.8   1.64  -0.8     ⋅      ⋅ 
   ⋅   -0.8    1.64  -0.8     ⋅ 
   ⋅     ⋅    -0.8    1.64  -0.8
   ⋅     ⋅      ⋅    -0.8    1.0
```

```julia
# its inverse is the AR(1) covariance: σ²ϕ^|i-j| / (1-ϕ²)
Σ = inv(Matrix(Q))
round.(Σ * (1 - 0.8^2), digits = 3)
```

```text
5×5 Matrix{Float64}:
 1.0    0.8    0.64  0.512  0.41
 0.8    1.0    0.8   0.64   0.512
 0.64   0.8    1.0   0.8    0.64
 0.512  0.64   0.8   1.0    0.8
 0.41   0.512  0.64  0.8    1.0
```

```julia
n = 2000
Qbig = ar1_precision(n, 0.8, 1.0)
Qdense = Matrix(Qbig)
b = ones(n)
Qbig \ b ≈ Qdense \ b                   # same answer...
tstruct = minimum(@elapsed(Qbig \ b) for _ in 1:5)     # best of 5 runs
tdense = minimum(@elapsed(Qdense \ b) for _ in 1:5)
println("tridiagonal solve is ", round(Int, tdense / tstruct), "× faster")  # ...much faster
```

```text
tridiagonal solve is 1311× faster
```

</details>
</div>

<div class="cheatbox jl-green">

## Cholesky factorization

For a symmetric positive definite `Σ`, `cholesky` gives `Σ = LL'`. The factorization object solves systems and gives the log determinant cheaply.

```julia
using LinearAlgebra
Σ = [4.0 2; 2 3]
C = cholesky(Σ)
C.L                     # [2.0 0.0; 1.0 1.414...]
C.L * C.U ≈ Σ           # true    C.U == C.L'
C \ [1.0, 1]            # solves Σx = b using the factor
logdet(C)               # 2.0794...  = log(8)
isposdef(Σ)             # true
cholesky(Symmetric(Σ))  # safe for nearly symmetric input
```

`cholesky` throws `PosDefException` if the matrix is not positive definite. `cholesky(Σ, check = false)` and `issuccess(C)` let you test instead.

<details class="example">
<summary>Example</summary>

Draw from a multivariate normal and evaluate its log density with a single Cholesky factorization.

```julia
using LinearAlgebra, Random, Statistics
Random.seed!(4)

μ = [1.0, -1.0, 0.0]
Σ = [1.0 0.8 0.3;
     0.8 2.0 0.5;
     0.3 0.5 1.5]
C = cholesky(Σ)

# x = μ + Lz with z ~ N(0, I) gives x ~ N(μ, Σ)
draws = μ .+ C.L * randn(3, 100_000)

round.(mean(draws, dims = 2), digits = 2), round.(cov(draws, dims = 2), digits = 2)
```

```text
([1.0; -0.99; 0.0;;], [1.0 0.8 0.31; 0.8 2.0 0.51; 0.31 0.51 1.51])
```

```julia
function mvnormal_logpdf(x, μ, C::Cholesky)
    z = C.L \ (x - μ)                  # whitened residual
    return -0.5 * (length(x) * log(2π) + logdet(C) + dot(z, z))
end

mvnormal_logpdf([1.0, -1.0, 0.0], μ, C)
```

```text
-3.0644084191591348
```

```julia
# check against the textbook formula with inv and det
x = [1.0, -1.0, 0.0]
-0.5 * (3 * log(2π) + log(det(Σ)) + (x - μ)' * inv(Σ) * (x - μ))
```

```text
-3.0644084191591348
```

</details>
</div>

<div class="cheatbox jl-green">

## Eigenvalues and SVD

`eigen` for square matrices, `svd` for any matrix. Results are factorization objects with named fields.

```julia
using LinearAlgebra
A = [2.0 1; 1 2]
E = eigen(A)
E.values                # [1.0, 3.0]  ascending for symmetric
E.vectors               # columns are eigenvectors
eigvals(A)              # [1.0, 3.0]
A * E.vectors ≈ E.vectors * Diagonal(E.values)  # true

M = [1.0 2; 3 4; 5 6]
F = svd(M)              # F.U, F.S, F.V (also F.Vt)
F.S                     # [9.525..., 0.514...]
F.U * Diagonal(F.S) * F.V' ≈ M   # true
cond(M)                 # 18.52...  ratio of largest/smallest singular value
```

Non-symmetric matrices can have complex eigenvalues: `eigvals([0 -1; 1 0])` is `[0.0 - 1.0im, 0.0 + 1.0im]`.

<details class="example">
<summary>Example</summary>

Principal component analysis via the SVD of the centred data matrix.

```julia
using LinearAlgebra, Random, Statistics
Random.seed!(5)

n = 500
z = randn(n)
X = [z + 0.1randn(n)  2z + 0.1randn(n)  randn(n)]   # first two columns correlated

Xc = X .- mean(X, dims = 1)
F = svd(Xc)

explained = F.S .^ 2 / sum(F.S .^ 2)
round.(explained, digits = 3)            # share of variance per component
```

```text
3-element Vector{Float64}:
 0.854
 0.144
 0.001
```

```julia
round.(F.V[:, 1], digits = 3)            # loadings of the first component
```

```text
3-element Vector{Float64}:
 -0.448
 -0.894
  0.005
```

```julia
# the same from the eigen decomposition of the covariance matrix
E = eigen(Symmetric(cov(X)))
round.(reverse(E.values) / sum(E.values), digits = 3)
```

```text
3-element Vector{Float64}:
 0.854
 0.144
 0.001
```

```julia
# a symmetric matrix square root: A^(1/2) = V Λ^(1/2) V'
Σ = [2.0 0.5; 0.5 1.0]
E = eigen(Symmetric(Σ))
Σhalf = E.vectors * Diagonal(sqrt.(E.values)) * E.vectors'
Σhalf * Σhalf ≈ Σ, sqrt(Σ) ≈ Σhalf      # Base sqrt does the same for matrices
```

```text
(true, true)
```

</details>
</div>

<div class="cheatbox jl-green">

## QR and LU factorizations

`qr` is the stable way to do least squares. `lu` is what `\` uses for general square matrices. Factorize once, solve many times.

```julia
using LinearAlgebra
X = [1.0 1; 1 2; 1 3]
Q, R = qr(X)            # destructuring works for factorizations
R                       # 2×2 upper triangular
Matrix(Q)               # thin Q: 3×2 with orthonormal columns
Matrix(Q)' * Matrix(Q) ≈ I   # true

A = [4.0 3; 6 3]
F = lu(A)               # F.L, F.U, F.p (row permutation)
F \ [1.0, 2]            # reuse for many right-hand sides
factorize(A)            # picks a factorization from the structure
```

<details class="example">
<summary>Example</summary>

Least squares via QR, and reusing one factorization for many right-hand sides.

```julia
using LinearAlgebra, Random
Random.seed!(6)

n = 50
X = [ones(n) range(0, 1, length = n)]
y = 2 .+ 3 .* X[:, 2] .+ 0.2 .* randn(n)

F = qr(X)
βhat = F \ y                         # same as X \ y
R = F.R
XtXinv = inv(R) * inv(R)'            # (X'X)⁻¹ = R⁻¹R⁻ᵀ, without forming X'X
βhat, diag(XtXinv)
```

```text
([1.9627527329615029, 3.046441968232609], [0.07764705882352939, 0.23058823529411765])
```

```julia
# many responses, one factorization
Y = [2 .+ 3 .* X[:, 2] .+ 0.2 .* randn(n) for _ in 1:1000]
B = stack(F \ yk for yk in Y)        # 2 × 1000 matrix of estimates
round.(sum(B, dims = 2) / 1000, digits = 3)   # ≈ [2, 3]
```

```text
2×1 Matrix{Float64}:
 2.003
 2.996
```

</details>
</div>

<div class="cheatbox jl-green">

## Broadcasting and reductions over matrices

Add a dot to apply any function elementwise. Functions without a dot act on the whole matrix.

```julia
A = [1.0 2; 3 4]
A .+ 1                  # [2.0 3.0; 4.0 5.0]
A .+ [10, 20]           # add a column vector to each column
A .+ [10 20]            # add a row vector to each row
exp.(A)                 # elementwise exp
exp(A)                  # matrix exponential, different!
sum(A), sum(A, dims = 1)   # (10.0, [4.0 6.0])  column sums
sum(A, dims = 2)        # [3.0; 7.0;;]  row sums, 2×1 matrix
maximum(A, dims = 1)    # [3.0 4.0]
[sum(r) for r in eachrow(A)]  # [3.0, 7.0]
mapslices(sort, [3 1; 2 4], dims = 2)  # sort each row
```

`dims = 1` works down the columns and returns a row. Use `vec(...)` to turn the result into a vector.

<details class="example">
<summary>Example</summary>

Standardize the columns of a data matrix, and compute a numerically stable row-wise softmax.

```julia
using Statistics

X = [1.0 100 0.5;
     2.0 150 0.7;
     3.0 130 0.2;
     4.0 120 0.9]

Z = (X .- mean(X, dims = 1)) ./ std(X, dims = 1)
round.(Z, digits = 3)
```

```text
4×3 Matrix{Float64}:
 -1.162  -1.201  -0.251
 -0.387   1.201   0.419
  0.387   0.24   -1.256
  1.162  -0.24    1.088
```

```julia
round.(mean(Z, dims = 1), digits = 10), std(Z, dims = 1)
```

```text
([0.0 0.0 0.0], [1.0 1.0 1.0])
```

```julia
# softmax of each row: subtract the row maximum before exp to avoid overflow
function softmax_rows(S)
    E = exp.(S .- maximum(S, dims = 2))
    return E ./ sum(E, dims = 2)
end

scores = [1.0 2.0 3.0;
          1000.0 1000.0 1001.0]      # naive exp would overflow here
P = softmax_rows(scores)
round.(P, digits = 4), vec(sum(P, dims = 2))
```

```text
([0.09 0.2447 0.6652; 0.2119 0.2119 0.5761], [0.9999999999999999, 1.0])
```

</details>
</div>

<div class="cheatbox jl-green">

## In-place operations and views

In loops, avoid allocating new arrays: write into preallocated ones with `!` functions, and use views instead of copies of slices.

```julia
using LinearAlgebra
A, x = rand(3, 3), rand(3)
y = similar(x)          # uninitialized, same type and size
mul!(y, A, x)           # y = A * x, no allocation
y .= A * x .+ 1         # .= writes into y (A * x still allocates)
v = @view A[:, 1]       # no copy; changes to v change A
v .= 0                  # first column of A is now zeros
C = cholesky(Symmetric(A'A + I))
ldiv!(C, y)             # y = C \ y, overwriting y
copyto!(y, [1, 2, 3])   # overwrite y with other values
```

`A[:, 1]` on the right-hand side makes a copy. Put `@views` in front of a whole expression or function to make every slice in it a view.

<details class="example">
<summary>Example</summary>

A loop that updates a vector many times, with and without allocations.

```julia
using LinearAlgebra, Random
Random.seed!(7)

n = 200
A = randn(n, n) / sqrt(n)
x0 = randn(n)

function iterate_alloc(A, x, k)
    for _ in 1:k
        x = A * x               # new vector every iteration
        x = x / norm(x)
    end
    return x
end

function iterate_inplace!(x, A, k)
    y = similar(x)
    for _ in 1:k
        mul!(y, A, x)           # write into y
        x .= y ./ norm(y)       # write back into x
    end
    return x
end

r1 = iterate_alloc(A, copy(x0), 100)
r2 = iterate_inplace!(copy(x0), A, 100)
r1 ≈ r2
```

```text
true
```

```julia
x = copy(x0)
iterate_alloc(A, x, 1); iterate_inplace!(x, A, 1)        # compile first
println("allocating: ", @allocated(iterate_alloc(A, x, 100)), " bytes")
println("in place:   ", @allocated(iterate_inplace!(x, A, 100)), " bytes")
```

```text
allocating: 332800 bytes
in place:   1664 bytes
```

```julia
# views: column sums without copying columns
B = rand(1000, 1000)
colsum_copy(B) = [sum(B[:, j]) for j in axes(B, 2)]
colsum_view(B) = [sum(@view B[:, j]) for j in axes(B, 2)]
colsum_copy(B) ≈ colsum_view(B)
```

```text
true
```

```julia
colsum_copy(B); colsum_view(B)
@allocated(colsum_copy(B)), @allocated(colsum_view(B))
```

```text
(8080072, 8072)
```

</details>
</div>
