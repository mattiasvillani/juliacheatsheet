# Julia cheat sheet

A Julia cheat sheet website built with [Observable Framework](https://observablehq.com/framework/), served at <https://mattiasvillani.com/juliacheatsheet/>.

Each topic page has boxes of short commands with their results as comments. Below the commands, a folded **Example** has a longer runnable program and its output.

## Develop

```bash
npm install
npm run dev                          # live preview at http://localhost:3000
julia scripts/check.jl               # run every Julia block on the site, report errors
julia scripts/check.jl --update      # also rewrite the output shown under each example
```

Pushing to `main` builds the site and deploys it to GitHub Pages (`.github/workflows/deploy.yml`).

## Layout

```
observablehq.config.js   site title, sidebar pages, theme toggle, footer
src/index.md             home page with a card per topic
src/<topic>.md           one page per topic (collections.md, types.md, ...)
src/styles.css           theme, box colours and layout
scripts/check.jl         runs the Julia code and writes example outputs
scripts/Project.toml     Julia packages used on the site (check.jl activates it; add new ones with julia --project=scripts)
```

## Adding a topic

1. Create `src/<topic>.md` (copy the structure of an existing page).
2. Add it to `pages` in `observablehq.config.js` and add a card in `src/index.md`.
3. Run `julia scripts/check.jl --update` to check the code and fill in the example outputs.

## Box conventions

````markdown
<div class="cheatbox jl-purple">

## Short title, `code` allowed

One or two lines of purpose.

```julia
x = f(1)     # result as a trailing comment
```

Optional gotcha line.

<details class="example">
<summary>Example</summary>

What the example does.

```julia
# a longer program that runs on its own in a fresh Julia session
```

</details>
</div>
````

- Colour: `jl-purple`, `jl-blue`, `jl-green`, `jl-red` (the Julia logo colours), `jl-teal` or `jl-orange`. All boxes on a page share one colour, and each page has its own. Add a new `.jl-<name>` rule in `src/styles.css` for further pages.
- Keep the blank lines around the `<div>`, `<details>` and fenced code, or the Markdown inside will not render.
- In the commands, write results as trailing `# comments`. Under examples, do not write output by hand: `check.jl --update` adds a ```` ```text ```` block after each example code block.
- `check.jl` runs the commands and the example of each box in separate fresh modules, so every example must load its own packages.
- No Markdown tables inside boxes. Use aligned code comments or a short list.
- State the Julia version when a function is newer than 1.6 (for example "Julia 1.9+").
