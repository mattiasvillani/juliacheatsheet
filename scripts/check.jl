# Runs every ```julia block on the site and (re)writes example outputs.
#
#   julia scripts/check.jl            run all blocks, report errors
#   julia scripts/check.jl --update   also rewrite the ```text output block after each example block
#
# Only code inside boxes runs (so the home page's REPL-mode lines are skipped).
# Each box (<div class="cheatbox ...">) runs in two fresh modules: one for the cheat-sheet
# code and one for the folded example, so every example must run on its own.
# Boxes using Distributed's @everywhere run in Main instead, as in the REPL, because
# @everywhere defines things in Main. Blocks marked ```julia norun are not run.

import Pkg, REPL
Pkg.activate(@__DIR__; io = devnull)   # packages used on the site: scripts/Project.toml
Pkg.instantiate()

const SRC = joinpath(@__DIR__, "..", "src")
const FIGS = joinpath(SRC, "figures")   # images saved by examples, as <page>-<file>
const UPDATE = "--update" in ARGS
ENV["GKSwstype"] = "100"                # Plots.jl (GR) without a display

# Blocks run in an empty temporary folder. Images an example saves there are moved to
# src/figures/<page>-<name>, where the page shows them; other files are deleted.
function collect_files(page, keep)
    for f in readdir(pwd())
        if keep && any(endswith(f, e) for e in (".png", ".svg", ".gif"))
            UPDATE && (mkpath(FIGS); mv(f, joinpath(FIGS, "$page-$f"); force = true))
        end
        rm(f; force = true, recursive = true)
    end
end

# A fresh module set up like Main in the REPL: with eval, include and InteractiveUtils.
function replmodule(name)
    m = Module(name)
    Core.eval(m, :(eval(x) = Core.eval($m, x); include(p) = Base.include($m, p); using InteractiveUtils))
    return m
end

# Run code in mod and return what the REPL would show: printed output plus the last value.
function run_block(mod, code, label)
    path, io = mktemp()
    value = nothing
    pushdisplay(TextDisplay(IOContext(io, :limit => true, :displaysize => (24, 100))))   # capture display(x)
    try
        redirect_stdout(io) do
            redirect_stderr(io) do
                value = Base.include_string(REPL.softscope, mod, code, label)   # loops update globals as in the REPL
            end
        end
    finally
        popdisplay()
        close(io)
    end
    out = read(path, String)
    rm(path)
    if value !== nothing && !endswith(rstrip(code), ";")
        buf = IOBuffer()
        Base.invokelatest(show, IOContext(buf, :limit => true, :displaysize => (24, 100)), MIME"text/plain"(), value)
        out *= String(take!(buf)) * "\n"
    end
    # types defined in an example print as in the REPL, without the module prefix
    return rstrip(replace(out, r"Main\.(Sheet|Example)\." => ""))
end

# Index of the line after the fenced block that starts at line i.
function fence_end(lines, i)
    j = i + 1
    while !startswith(lines[j], "```")
        j += 1
    end
    return j + 1
end

function check_file(file)
    file = abspath(file)
    cd(mktempdir())
    page = splitext(basename(file))[1]
    lines = readlines(file)
    out = String[]
    nerr = 0
    sheet = example = Module()
    inexample = inbox = false
    i = 1
    while i <= length(lines)
        line = lines[i]
        if startswith(line, "<div class=\"cheatbox")
            boxend = something(findnext(==("</details>"), lines, i), length(lines))
            if any(occursin("@everywhere", l) for l in lines[i:boxend])
                sheet = example = Main
            else
                sheet, example = replmodule(:Sheet), replmodule(:Example)
            end
            inbox = true
        elseif startswith(line, "<details")
            inexample = true
        elseif startswith(line, "</details>")
            inexample = false
        elseif line == "</div>" && !inexample
            inbox = false
        end
        if line == "```text"            # outputs are consumed below, so this one is stale
            j = fence_end(lines, i)
            println(UPDATE ? "removed" : "WARNING:", " stale output block at $(basename(file)):$i")
            UPDATE || append!(out, lines[i:j-1])
            UPDATE && !isempty(out) && isempty(strip(out[end])) && pop!(out)
            i = j
            continue
        end
        if line != "```julia" || !inbox
            push!(out, line)
            i += 1
            continue
        end

        j = fence_end(lines, i)
        append!(out, lines[i:j-1])
        code = join(lines[i+1:j-2], "\n")
        label = "$(basename(file)):$(i + 1)"
        result = try
            run_block(inexample ? example : sheet, code, label)
        catch err
            nerr += 1
            println("ERROR in ", label, "\n  ", sprint(showerror, err))
            nothing
        end
        collect_files(page, inexample)
        i = j

        # an existing ```text block right after an example block is its output
        k = i
        while k <= length(lines) && isempty(strip(lines[k]))
            k += 1
        end
        hasoutput = k <= length(lines) && lines[k] == "```text"
        if !inexample || !UPDATE || result === nothing
            continue
        end
        hasoutput && (i = fence_end(lines, k))
        isempty(result) && continue
        append!(out, ["", "```text", split(result, "\n")..., "```"])
    end
    UPDATE && write(file, join(out, "\n") * "\n")
    return nerr
end

# Each page runs in its own Julia process, so packages loaded by one page
# do not change the output of another (for example subtypes(Real)).
if length(ARGS) >= 2 && ARGS[1] == "--file"
    exit(check_file(ARGS[2]) == 0 ? 0 : 1)
end

failed = String[]
for file in sort(filter(endswith(".md"), readdir(SRC; join = true)))
    println("checking ", basename(file))
    cmd = `$(Base.julia_cmd()) --startup-file=no --threads=4 $(@__FILE__) --file $file $(UPDATE ? ["--update"] : [])`
    success(pipeline(cmd; stdout, stderr)) || push!(failed, basename(file))
end
println(isempty(failed) ? "all blocks ran" : "errors in: " * join(failed, ", "))
exit(isempty(failed) ? 0 : 1)
