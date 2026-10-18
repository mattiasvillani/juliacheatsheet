---
title: Data handling
toc: true
---

# Data handling

Read files with [CSV.jl](https://csv.juliadata.org/stable/), hold them in a [DataFrame](https://dataframes.juliadata.org/stable/), and transform them with the macros in [DataFramesMeta.jl](https://juliadata.org/DataFramesMeta.jl/stable/). For Tidyverse-style code, [TidierData.jl](https://tidierorg.github.io/TidierData.jl/latest/) mirrors R's dplyr and tidyr. Install with `] add CSV DataFrames DataFramesMeta TidierData`.

The examples use the `mtcars` data from the [Rdatasets](https://vincentarelbundock.github.io/Rdatasets/) collection, downloaded from GitHub.

<div class="cheatbox jl-gold">

## Downloading files

`Downloads` comes with Julia. `download(url, path)` saves a file and returns its path.

```julia
using Downloads
url = "https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/csv/datasets/mtcars.csv"
path = Downloads.download(url)            # to a temporary file
dir = mktempdir()
file = joinpath(dir, "mtcars.csv")
Downloads.download(url, file)             # to a chosen path
isfile(file), filesize(file)              # (true, 1703)
readlines(file)[1:2]                      # peek at the first lines
```

<details class="example">
<summary>Example</summary>

Download only when the file is not already on disk, so scripts work offline after the first run.

```julia
using Downloads

function cached_download(url, dir = joinpath(homedir(), ".cache", "julia-data"))
    mkpath(dir)
    file = joinpath(dir, basename(url))
    if isfile(file)
        println("using cached ", file)
    else
        println("downloading ", basename(url))
        Downloads.download(url, file)
    end
    return file
end

url = "https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/csv/datasets/mtcars.csv"
dir = mktempdir()                      # a fresh folder, so the first call downloads
file = cached_download(url, dir)
file = cached_download(url, dir)       # second call uses the file on disk
countlines(file)
```

```text
downloading mtcars.csv
using cached /tmp/jl_e5Kay0/mtcars.csv
33
```

</details>
</div>

<div class="cheatbox jl-gold">

## Reading and writing CSV files

`CSV.read(source, DataFrame)` reads a file, a downloaded path or an `IOBuffer`.

```julia
using CSV, DataFrames, Downloads
url = "https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/csv/datasets/mtcars.csv"
df = CSV.read(Downloads.download(url), DataFrame)   # 32×12 DataFrame
CSV.read(Downloads.download(url), DataFrame;
         select = [:mpg, :cyl, :wt],      # only some columns
         limit = 5)                       # only the first rows
txt = "x;y\n1,5;NA\n2,0;3"
CSV.read(IOBuffer(txt), DataFrame;
         delim = ';', decimal = ',',      # European style
         missingstring = "NA")            # x = [1.5, 2.0], y = [missing, 3]
CSV.write(joinpath(mktempdir(), "out.csv"), df)   # write a DataFrame
```

Other useful keywords: `header = false` or `header = 2`, `skipto`, `types = Dict(:id => String)`, `dateformat = "yyyy-mm-dd"`, `normalizenames = true`.

<details class="example">
<summary>Example</summary>

Read a messy file: comment lines at the top, a semicolon delimiter, decimal commas, several codes for missing values and a date column.

```julia
using CSV, DataFrames, Dates

raw = """
# Weather station export
# generated 2026-01-05
date;station;temp;rain
2026-01-01;Uppsala;-3,5;0,0
2026-01-02;Uppsala;-;1,2
2026-01-03;Uppsala;-1,0;NA
2026-01-01;Lund;2,5;0,4
"""

df = CSV.read(IOBuffer(raw), DataFrame;
              comment = "#", delim = ';', decimal = ',',
              missingstring = ["NA", "-"], dateformat = "yyyy-mm-dd")
```

```text
4×4 DataFrame
 Row │ date        station    temp       rain
     │ Date        DataStri…  Float64?   Float64?
─────┼─────────────────────────────────────────────
   1 │ 2026-01-01  Uppsala         -3.5        0.0
   2 │ 2026-01-02  Uppsala    missing          1.2
   3 │ 2026-01-03  Uppsala         -1.0  missing
   4 │ 2026-01-01  Lund             2.5        0.4
```

```julia
eltype.(eachcol(df))
```

```text
4-element Vector{Type}:
 Dates.Date
 DataStrings.DataString
 Union{Missing, Float64}
 Union{Missing, Float64}
```

```julia
# write it back with standard formatting and read it again
file = joinpath(mktempdir(), "weather.csv")
CSV.write(file, df)
print(read(file, String))
```

```text
date,station,temp,rain
2026-01-01,Uppsala,-3.5,0.0
2026-01-02,Uppsala,,1.2
2026-01-03,Uppsala,-1.0,
2026-01-01,Lund,2.5,0.4
```

</details>
</div>

<div class="cheatbox jl-gold">

## DataFrames: the basics

A `DataFrame` is a table of named columns, each a `Vector`.

```julia
using DataFrames
df = DataFrame(name = ["a", "b", "c"], x = [1.0, 2.5, 4.0], g = [1, 2, 1])
size(df), nrow(df), ncol(df)    # ((3, 3), 3, 3)
names(df)                       # ["name", "x", "g"]
df.x                            # [1.0, 2.5, 4.0]  the column itself
df[!, :x]                       # same, no copy
df[:, :x]                       # a copy
df[2, :]                        # a row (DataFrameRow)
df[df.x .> 2, [:name, :x]]      # filter rows, pick columns
df.y = df.x .^ 2                # add a column
push!(df, ("d", 5.0, 2, 25.0))  # add a row
first(df, 2), last(df, 1)
describe(df)                    # summary of each column
```

`df[!, :x]` returns the stored column, so changing it changes `df`. `df[:, :x]` returns a copy.

<details class="example">
<summary>Example</summary>

A first look at the `mtcars` data.

```julia
using CSV, DataFrames, Downloads, Statistics

url = "https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/csv/datasets/mtcars.csv"
cars = CSV.read(Downloads.download(url), DataFrame)
rename!(cars, :rownames => :model)
first(select(cars, :model, :mpg, :cyl, :hp, :wt, :am), 5)
```

```text
5×6 DataFrame
 Row │ model              mpg      cyl    hp     wt       am
     │ DataStri…          Float64  Int64  Int64  Float64  Int64
─────┼──────────────────────────────────────────────────────────
   1 │ Mazda RX4             21.0      6    110    2.62       1
   2 │ Mazda RX4 Wag         21.0      6    110    2.875      1
   3 │ Datsun 710            22.8      4     93    2.32       1
   4 │ Hornet 4 Drive        21.4      6    110    3.215      0
   5 │ Hornet Sportabout     18.7      8    175    3.44       0
```

```julia
describe(cars, :mean, :min, :max, :eltype)[1:6, :]
```

```text
6×5 DataFrame
 Row │ variable  mean     min          max         eltype
     │ Symbol    Union…   Any          Any         DataType
─────┼────────────────────────────────────────────────────────
   1 │ model              AMC Javelin  Volvo 142E  DataString
   2 │ mpg       20.0906  10.4         33.9        Float64
   3 │ cyl       6.1875   4            8           Int64
   4 │ disp      230.722  71.1         472.0       Float64
   5 │ hp        146.688  52           335         Int64
   6 │ drat      3.59656  2.76         4.93        Float64
```

```julia
# columns as vectors work with every Julia function
cor(cars.mpg, cars.wt), mean(cars.mpg[cars.am .== 1]), mean(cars.mpg[cars.am .== 0])
```

```text
(-0.8676593765172281, 24.39230769230769, 17.147368421052633)
```

</details>
</div>

<div class="cheatbox jl-gold">

## DataFramesMeta: filter, select and transform

Macros refer to columns as `:name`. Plain macros work on whole columns; the `r` versions work row by row, so no dots are needed.

```julia
using DataFramesMeta, Statistics
df = DataFrame(x = [1.0, 2.5, 4.0], g = ["a", "b", "a"])
@subset(df, :x .> 2)              # keep rows (vectorized: note the dot)
@rsubset(df, :x > 2)              # the same, row by row
@select(df, :x, :x2 = :x .^ 2)    # pick and create columns
@transform(df, :z = :x .- mean(:x))   # add columns, keep all
@rtransform(df, :lab = :g * "_" * string(:x))
@orderby(df, -:x)                 # sort, descending
@rename(df, :value = :x)
col = :x
@subset(df, $col .> 2)            # column name stored in a variable
```

`@chain` (re-exported from Chain.jl) pipes the result into the first argument of each next line.

<details class="example">
<summary>Example</summary>

A pipeline on the `mtcars` data: filter, create new variables, choose columns and sort.

```julia
using CSV, DataFramesMeta, Downloads, Statistics

url = "https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/csv/datasets/mtcars.csv"
cars = CSV.read(Downloads.download(url), DataFrame)

@chain cars begin
    @rename(:model = :rownames)
    @rsubset(:cyl == 4)
    @rtransform(:kpl = 0.425 * :mpg,               # km per litre
                :transmission = :am == 1 ? "manual" : "automatic")
    @select(:model, :kpl, :hp, :transmission)
    @orderby(-:kpl)
    first(5)
end
```

```text
5×4 DataFrame
 Row │ model           kpl      hp     transmission
     │ DataStri…       Float64  Int64  String
─────┼──────────────────────────────────────────────
   1 │ Toyota Corolla  14.4075     65  manual
   2 │ Fiat 128        13.77       66  manual
   3 │ Honda Civic     12.92       52  manual
   4 │ Lotus Europa    12.92      113  manual
   5 │ Fiat X1-9       11.6025     66  manual
```

```julia
# a vectorized transform: standardize horsepower over all cars
@chain cars begin
    @transform(:hp_z = (:hp .- mean(:hp)) ./ std(:hp))
    @select(:rownames, :hp, :hp_z)
    @orderby(:hp_z)
    last(3)
end
```

```text
3×3 DataFrame
 Row │ rownames        hp     hp_z
     │ DataStri…       Int64  Float64
─────┼────────────────────────────────
   1 │ Camaro Z28        245  1.4339
   2 │ Ford Pantera L    264  1.71102
   3 │ Maserati Bora     335  2.74657
```

</details>
</div>

<div class="cheatbox jl-gold">

## DataFramesMeta: grouping and summaries

`@groupby` splits the rows, `@combine` gives one row per group. `@by` does both at once.

```julia
using DataFramesMeta, Statistics
df = DataFrame(g = ["a", "b", "a", "b"], x = [1.0, 2.0, 3.0, 6.0])
gd = @groupby(df, :g)
@combine(gd, :mean = mean(:x), :n = length(:x))   # 2 rows
@by(df, :g, :mean = mean(:x))                    # same in one step
@combine(gd, $nrow)                              # count rows per group
@transform(gd, :dev = :x .- mean(:x))            # within-group, keeps all rows
@combine(gd, :q = quantile(:x, [0.25, 0.75]))    # several rows per group
```

<details class="example">
<summary>Example</summary>

Fuel economy by number of cylinders and transmission type.

```julia
using CSV, DataFramesMeta, Downloads, Statistics

url = "https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/csv/datasets/mtcars.csv"
cars = CSV.read(Downloads.download(url), DataFrame)

@chain cars begin
    @rtransform(:transmission = :am == 1 ? "manual" : "automatic")
    @groupby(:cyl, :transmission)
    @combine(:n = length(:mpg),
             :mpg_mean = round(mean(:mpg), digits = 1),
             :mpg_sd = round(std(:mpg), digits = 1),
             :hp_max = maximum(:hp))
    @orderby(:cyl, :transmission)
end
```

```text
6×6 DataFrame
 Row │ cyl    transmission  n      mpg_mean  mpg_sd   hp_max
     │ Int64  String        Int64  Float64   Float64  Int64
─────┼───────────────────────────────────────────────────────
   1 │     4  automatic         3      22.9      1.5      97
   2 │     4  manual            8      28.1      4.5     113
   3 │     6  automatic         4      19.1      1.6     123
   4 │     6  manual            3      20.6      0.8     175
   5 │     8  automatic        12      15.1      2.8     245
   6 │     8  manual            2      15.4      0.6     335
```

```julia
# each car's mpg relative to its cylinder group
@chain cars begin
    @groupby(:cyl)
    @transform(:mpg_rel = :mpg ./ mean(:mpg))
    @select(:rownames, :cyl, :mpg, :mpg_rel)
    @orderby(-:mpg_rel)
    first(4)
end
```

```text
4×4 DataFrame
 Row │ rownames           cyl    mpg      mpg_rel
     │ DataStri…          Int64  Float64  Float64
─────┼────────────────────────────────────────────
   1 │ Pontiac Firebird       8     19.2  1.27152
   2 │ Toyota Corolla         4     33.9  1.27139
   3 │ Hornet Sportabout      8     18.7  1.23841
   4 │ Fiat 128               4     32.4  1.21514
```

</details>
</div>

<div class="cheatbox jl-gold">

## Joins, reshaping and missing values

Joins and reshaping come from DataFrames.jl and work alongside the macros.

```julia
using DataFrames
a = DataFrame(id = [1, 2, 3], x = [10, 20, 30])
b = DataFrame(id = [1, 3, 4], y = ["p", "q", "r"])
innerjoin(a, b, on = :id)         # ids 1 and 3
leftjoin(a, b, on = :id)          # all of a; y missing for id 2
outerjoin(a, b, on = :id)         # ids 1 to 4
w = DataFrame(id = [1, 2], t1 = [5, 6], t2 = [7, 8])
long = stack(w, [:t1, :t2])       # wide → long: columns variable, value
unstack(long, :variable, :value)  # long → wide again
m = DataFrame(x = [1, missing, 3])
dropmissing(m)                    # remove rows with missing values
coalesce.(m.x, 0)                 # [1, 0, 3]
```

In DataFramesMeta, `@passmissing` makes a row-wise expression return `missing` instead of failing: `@rtransform(df, @passmissing :y = sqrt(:x))`.

<details class="example">
<summary>Example</summary>

MCMC output from several chains: wide to long, summaries per chain and parameter, and back to wide.

```julia
using DataFramesMeta, Random, Statistics
Random.seed!(1)

draws = DataFrame(chain = repeat(1:3, inner = 1000),
                  iter = repeat(1:1000, 3),
                  μ = randn(3000) .+ 2,
                  σ = exp.(0.1 .* randn(3000)))

long = stack(draws, [:μ, :σ]; variable_name = :param, value_name = :draw)
first(long, 3)
```

```text
3×4 DataFrame
 Row │ chain  iter   param   draw
     │ Int64  Int64  String  Float64
─────┼───────────────────────────────
   1 │     1      1  μ       2.06193
   2 │     1      2  μ       2.27841
   3 │     1      3  μ       1.40418
```

```julia
summ = @chain long begin
    @groupby(:param, :chain)
    @combine(:mean = round(mean(:draw), digits = 3))
end
unstack(summ, :chain, :mean; renamecols = c -> "chain$c")
```

```text
2×4 DataFrame
 Row │ param   chain1    chain2    chain3
     │ String  Float64?  Float64?  Float64?
─────┼──────────────────────────────────────
   1 │ μ          2.032     2.019     2.064
   2 │ σ          1.0       1.004     0.998
```

```julia
# a join that brings in labels, with a missing label for σ
labels = DataFrame(param = ["μ"], label = ["location"])
@chain summ begin
    leftjoin(labels, on = :param)
    @rtransform(@passmissing :label_upper = uppercase(:label))
    @orderby(:param, :chain)
end
```

```text
6×5 DataFrame
 Row │ param   chain  mean     label     label_upper
     │ String  Int64  Float64  String?   String?
─────┼───────────────────────────────────────────────
   1 │ μ           1    2.032  location  LOCATION
   2 │ μ           2    2.019  location  LOCATION
   3 │ μ           3    2.064  location  LOCATION
   4 │ σ           1    1.0    missing   missing
   5 │ σ           2    1.004  missing   missing
   6 │ σ           3    0.998  missing   missing
```

</details>
</div>

<div class="cheatbox jl-gold">

## Plain DataFrames.jl syntax

The macros above translate to functions using `source => function => target` pairs. Both styles are common in code you will read.

```julia
using DataFrames, Statistics
df = DataFrame(g = ["a", "b", "a", "b"], x = [1.0, 2.0, 3.0, 6.0])
subset(df, :x => ByRow(>(2)))             # @rsubset(df, :x > 2)
select(df, :x, :x => (x -> x .^ 2) => :x2)  # @select(df, :x, :x2 = :x .^ 2)
transform(df, :x => ByRow(sqrt) => :r)    # @rtransform(df, :r = sqrt(:x))
sort(df, :x, rev = true)                  # @orderby(df, -:x)
combine(groupby(df, :g), :x => mean => :mean, nrow)   # @by(df, :g, ...)
transform(df, [:x, :g] => ByRow((x, g) -> "$g$x") => :lab)  # several inputs
filter(row -> row.x > 2, df)              # row-wise with a function
```

`ByRow(f)` applies `f` to each element; without it, the function gets the whole column.

<details class="example">
<summary>Example</summary>

The same summary written three ways: DataFramesMeta, DataFrames functions, and a plain loop over groups.

```julia
using CSV, DataFramesMeta, Downloads, Statistics

url = "https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/csv/datasets/mtcars.csv"
cars = CSV.read(Downloads.download(url), DataFrame)

meta = @by(cars, :gear, :mpg = mean(:mpg), :n = length(:mpg))
plain = combine(groupby(cars, :gear), :mpg => mean => :mpg, nrow => :n)
loop = DataFrame(gear = Int[], mpg = Float64[], n = Int[])
for sub in groupby(cars, :gear)
    push!(loop, (sub.gear[1], mean(sub.mpg), nrow(sub)))
end

meta == plain == loop
```

```text
true
```

```julia
meta
```

```text
3×3 DataFrame
 Row │ gear   mpg      n
     │ Int64  Float64  Int64
─────┼───────────────────────
   1 │     3  16.1067     15
   2 │     4  24.5333     12
   3 │     5  21.38        5
```

</details>
</div>

<div class="cheatbox jl-gold">

## Tidyverse in Julia: TidierData

TidierData.jl copies the dplyr verbs. Bare column names, and functions are vectorized automatically, so no dots are needed.

```julia
using TidierData
df = DataFrame(g = ["a", "b", "a", "b"], x = [1.0, 2.0, 3.0, 6.0])
@chain df begin
    @filter(x > 1)
    @mutate(x2 = x^2, big = x > 2.5)
    @group_by(g)
    @summarize(mean_x = mean(x), n = n())
    @arrange(desc(mean_x))
end
@select(df, g, x)                 # also starts_with("x"), -g
@rename(df, value = x)
@slice(df, 1:2)                   # rows by position; also @slice_max(x, n = 1)
@count(df, g)                     # rows per group
@distinct(df, g)
```

Mark an expression with `~` to stop automatic vectorization, for example `@mutate(z = ~f(x))` when `f` takes the whole column.

<details class="example">
<summary>Example</summary>

The `mtcars` summary from the DataFramesMeta box, in dplyr style.

```julia
using CSV, TidierData, Downloads

url = "https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/csv/datasets/mtcars.csv"
cars = CSV.read(Downloads.download(url), DataFrame)

@chain cars begin
    @rename(model = rownames)
    @mutate(transmission = if_else(am == 1, "manual", "automatic"),
            kpl = 0.425 * mpg)
    @group_by(cyl, transmission)
    @summarize(n = n(),
               kpl_mean = round(mean(kpl), digits = 1),
               hp_max = maximum(hp))
    @ungroup
    @arrange(cyl, transmission)
end
```

```text
6×5 DataFrame
 Row │ cyl    transmission  n      kpl_mean  hp_max
     │ Int64  String        Int64  Float64   Int64
─────┼──────────────────────────────────────────────
   1 │     4  automatic         3       9.7      97
   2 │     4  manual            8      11.9     113
   3 │     6  automatic         4       8.1     123
   4 │     6  manual            3       8.7     175
   5 │     8  automatic        12       6.4     245
   6 │     8  manual            2       6.5     335
```

```julia
# the most fuel-efficient car for each number of cylinders
@chain cars begin
    @group_by(cyl)
    @filter(mpg == maximum(mpg))
    @ungroup
    @select(rownames, cyl, mpg)
end
```

```text
3×3 DataFrame
 Row │ rownames          cyl    mpg
     │ DataStri…         Int64  Float64
─────┼──────────────────────────────────
   1 │ Hornet 4 Drive        6     21.4
   2 │ Toyota Corolla        4     33.9
   3 │ Pontiac Firebird      8     19.2
```

</details>
</div>

<div class="cheatbox jl-gold">

## TidierData: reshaping and joins

tidyr's pivots and dplyr's joins.

```julia
using TidierData
w = DataFrame(id = [1, 2], t1 = [5, 6], t2 = [7, 8])
long = @pivot_longer(w, t1:t2, names_to = "time", values_to = "y")
@pivot_wider(long, names_from = time, values_from = y)
a = DataFrame(id = [1, 2, 3], x = [10, 20, 30])
b = DataFrame(id = [1, 3, 4], y = ["p", "q", "r"])
@left_join(a, b, id)              # also @inner_join, @full_join, @anti_join
@mutate(a, x_cat = case_when(x < 15 => "low", x < 25 => "mid", true => "high"))
```

The [Tidier.jl](https://tidierorg.github.io/Tidier.jl/dev/) meta-package also has TidierPlots (ggplot2), TidierStrings (stringr), TidierFiles (readr: `read_csv`) and TidierCats (forcats).

<details class="example">
<summary>Example</summary>

Posterior draws from two chains: pivot to long form, summarize by parameter, and join in a table of true values.

```julia
using TidierData, Random
Random.seed!(2)

draws = DataFrame(chain = repeat([1, 2], inner = 500),
                  α = randn(1000) .+ 1,
                  β = 0.5 .* randn(1000) .- 2)
truth = DataFrame(param = ["α", "β", "γ"], true_value = [1.0, -2.0, 0.0])

@chain draws begin
    @pivot_longer(α:β, names_to = "param", values_to = "draw")
    @group_by(param)
    @summarize(mean = mean(draw), lo = quantile(draw, 0.025), hi = quantile(draw, 0.975))
    @ungroup
    @left_join(truth, param)
    @mutate(covered = lo <= true_value <= hi)
end
```

```text
2×6 DataFrame
 Row │ param   mean      lo         hi        true_value  covered
     │ String  Float64   Float64    Float64   Float64?    Bool
─────┼────────────────────────────────────────────────────────────
   1 │ α        1.00341  -0.980012   2.89578         1.0     true
   2 │ β       -1.97338  -2.89467   -1.03338        -2.0     true
```

```julia
# chain means side by side
@chain draws begin
    @group_by(chain)
    @summarize(α = mean(α), β = mean(β))
    @ungroup
    @pivot_longer(α:β, names_to = "param", values_to = "mean")
    @pivot_wider(names_from = chain, values_from = mean)
end
```

```text
2×3 DataFrame
 Row │ param   1          2
     │ String  Float64?   Float64?
─────┼─────────────────────────────
   1 │ α        0.961113   1.04571
   2 │ β       -1.95816   -1.9886
```

</details>
</div>
