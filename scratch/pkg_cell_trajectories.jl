using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../data/PKG_0803.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x))

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]
state_labels = ["No resp.", "Bend", "Shorten", "P.contract", "Contract"]
n_states = 5

function dominant_subtype(rows)
    total_resp = sum(rows.response)
    if total_resp == 0
        return 0
    end
    counts = [sum(rows[!, st]) for st in subtypes]
    _, idx = findmax(counts)
    return idx
end

function build_transitions(sub)
    sub = copy(sub)
    sub.cell_id = collect(zip(sub.fold_name, sub.cell_number))
    cells = unique(sub.cell_id)

    early_dom = Int[]
    late_dom  = Int[]
    for c in cells
        crows = subset(sub, :cell_id => x -> x .== Ref(c))
        e = subset(crows, :stimulus => x -> x .<= 5)
        l = subset(crows, :stimulus => x -> x .>= 16)
        push!(early_dom, dominant_subtype(e))
        push!(late_dom, dominant_subtype(l))
    end

    trans = zeros(Int, n_states, n_states)
    for i in eachindex(cells)
        from = early_dom[i] + 1
        to   = late_dom[i] + 1
        trans[from, to] += 1
    end

    trans_pct = zeros(n_states, n_states)
    for i in 1:n_states
        row_total = sum(trans[i, :])
        if row_total > 0
            trans_pct[i, :] = trans[i, :] ./ row_total .* 100
        end
    end

    return trans, trans_pct
end

function plot_heatmap!(ax, trans, trans_pct)
    for i in 1:n_states, j in 1:n_states
        val = trans_pct[i, j]
        poly!(ax, Rect(j - 0.5, i - 0.5, 1, 1),
            color = (:crimson, val / 100 * 0.9))
        count = trans[i, j]
        if count > 0
            text!(ax, j, i, text = "$(count)\n$(round(Int, val))%",
                align = (:center, :center), fontsize = 10,
                color = val > 50 ? :white : :black)
        end
    end
    for i in 1:n_states
        text!(ax, n_states + 0.8, i,
            text = "n=$(sum(trans[i,:]))",
            align = (:left, :center), fontsize = 9, color = :gray40)
    end
    xlims!(ax, 0.5, n_states + 1.5)
end

water = subset(df, :condition => x -> x .== "water")
pkg   = subset(df, :condition => x -> x .== "PKG")

tw, twp = build_transitions(water)
tp, tpp = build_transitions(pkg)

# --- Figure ---
fig = Figure(size = (1100, 1100), fontsize = 13)

# Row 1: heatmaps side by side
for (col, trans, trans_pct, name) in [(1, tw, twp, "Water"), (2, tp, tpp, "PKG")]
    ax = Axis(fig[1, col],
        title = "$name — cell fate (early → late)",
        xlabel = "Late dominant (stim 16–20)",
        ylabel = "Early dominant (stim 1–5)",
        xticks = (1:n_states, state_labels),
        yticks = (1:n_states, state_labels),
        yreversed = true,
        aspect = 1,
        xticklabelrotation = π/6)
    plot_heatmap!(ax, trans, trans_pct)
end

# Row 2: per-cell heatmap (raster) for water and PKG
function build_cell_matrix(sub)
    sub = copy(sub)
    sub.cell_id = collect(zip(sub.fold_name, sub.cell_number))
    cells = unique(sub.cell_id)

    mat = zeros(Int, length(cells), 20)
    for (ci, c) in enumerate(cells)
        crows = subset(sub, :cell_id => x -> x .== Ref(c))
        for row in eachrow(crows)
            s = row.stimulus
            if row.response == 1.0
                for (si, st) in enumerate(subtypes)
                    if row[st] == 1.0
                        mat[ci, s] = si
                        break
                    end
                end
            end
        end
    end

    total_resp = vec(sum(mat .> 0, dims=2))
    order = sortperm(total_resp, rev=true)
    return mat[order, :]
end

state_colors = [:gray90, :steelblue, :mediumpurple, :orange, :crimson]

for (col, sub_df, name) in [(1, water, "Water"), (2, pkg, "PKG")]
    mat = build_cell_matrix(sub_df)
    n_cells = size(mat, 1)

    ax = Axis(fig[2, col],
        title = "$name — individual cell trajectories",
        xlabel = "Stimulus number",
        ylabel = "Cell (sorted by # responses)",
        xticks = 1:20,
        yticks = ([1, n_cells], ["1", "$n_cells"]))

    for ci in 1:n_cells, si in 1:20
        v = mat[ci, si]
        poly!(ax, Rect(si - 0.45, ci - 0.45, 0.9, 0.9),
            color = state_colors[v + 1])
    end
end

# shared legend for rasters
leg_elems = [PolyElement(color = c) for c in state_colors]
Legend(fig[2, 3],
    leg_elems,
    ["No response", labels...],
    framevisible = false)

save("pkg_cell_trajectories.png", fig, px_per_unit = 3)
println("Saved pkg_cell_trajectories.png")

# --- Print summaries ---
for (name, trans) in [("Water", tw), ("PKG", tp)]
    println("\n--- $name: cells that contracted early ---")
    n_ce = sum(trans[5, :])
    if n_ce > 0
        for j in 1:n_states
            c = trans[5, j]
            println("  → $(state_labels[j]): $c ($(round(c/n_ce*100, digits=1))%)")
        end
    end
end
