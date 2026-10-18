---
title: Julia cheat sheet
toc: false
---

<div class="hero">
  <h1>Julia cheat sheet</h1>
  <h2>Short reminders of Julia syntax and idioms, one page per topic. Open <b>Example</b> at the bottom of any box for a longer program with its output. Every example runs on its own in a fresh Julia session.</h2>
</div>

<div class="grid grid-cols-3">
  <a href="./collections" class="card hero-card jl-purple">
    <h2>Collections</h2>
    <span>Vectors as stacks and queues, adding and removing elements, <code>Dict</code> and <code>Set</code>, <code>stack</code>.</span>
  </a>
  <a href="./types" class="card hero-card jl-blue">
    <h2>Types</h2>
    <span>The type tree, structs and constructors, parametric types, unions, conversion, type stability.</span>
  </a>
  <a href="./linear-algebra" class="card hero-card jl-green">
    <h2>Linear algebra</h2>
    <span>Matrices, products, solving systems, special matrix types, Cholesky, eigen and SVD, QR, in-place operations.</span>
  </a>
  <a href="./optimization" class="card hero-card jl-red">
    <h2>Optimization</h2>
    <span>Optim.jl with and without gradients, automatic differentiation, constraints, maximum likelihood, root finding.</span>
  </a>
  <a href="./statistics" class="card hero-card jl-teal">
    <h2>Statistics</h2>
    <span>Descriptive statistics, StatsBase, random numbers, and Distributions.jl: densities, fitting, multivariate, mixtures.</span>
  </a>
  <a href="./autodiff" class="card hero-card jl-orange">
    <h2>Automatic differentiation</h2>
    <span>ForwardDiff, Mooncake and DifferentiationInterface: gradients, Jacobians, Hessians, preparation, pitfalls.</span>
  </a>
  <a href="./data" class="card hero-card jl-gold">
    <h2>Data handling</h2>
    <span>Downloading and reading CSV files, DataFrames and DataFramesMeta, and Tidyverse-style code with TidierData.</span>
  </a>
  <a href="./parallel" class="card hero-card jl-slate">
    <h2>Parallel computing</h2>
    <span>Threads, tasks and data races, OhMyThreads, distributed processes, fast serial code, and GPUs with CUDA and KernelAbstractions.</span>
  </a>
</div>

<div class="card getting-started">

## Getting started

The REPL has modes. Type the key at the start of an empty line; backspace returns to `julia>`.

```julia
]          # package mode: add, rm, status, update
] add Distributions Optim     # install packages
] activate .                  # use the project in this folder
?          # help mode: type a function name for its docs
;          # shell mode: run shell commands
using Statistics              # load a package
@time f(x)                    # time a call (run it twice: the first includes compilation)
methods(f)                    # all methods of a function
@which f(1.0)                 # the method that a call dispatches to
```

</div>

<style>

.hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  font-family: var(--sans-serif);
  margin: 1.5rem 0 3rem;
  text-wrap: balance;
  text-align: center;
}

.hero h1 {
  margin: 0.5rem 0 1rem;
  padding: 0.5rem 0 1rem;
  max-width: none;
  font-size: 14vw;
  font-weight: 900;
  line-height: 1;
  /* Julia logo colours */
  background: linear-gradient(30deg, #4063D8, #CB3C33, #389826, #9558B2);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.hero h2 {
  margin: 0;
  max-width: 40em;
  font-size: 18px;
  font-style: initial;
  font-weight: 500;
  line-height: 1.5;
  color: var(--theme-foreground-muted);
}

@media (min-width: 640px) {
  .hero h1 {
    font-size: 64px;
  }
}

.hero-card {
  display: block;
  text-decoration: none;
  color: inherit;
  border-top: 6px solid var(--box);
  transition: transform 0.15s ease, border-color 0.15s ease;
}

.hero-card h2 {
  font-weight: 700;
  color: var(--box);
}

.hero-card span {
  color: var(--theme-foreground-muted);
}

.hero-card:hover {
  transform: translateY(-2px);
  border-color: var(--box);
}

.getting-started {
  margin-top: 2rem;
}

.getting-started h2 {
  margin-top: 0;
  font-size: 20px;
  font-weight: 700;
}

</style>
