using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../../data/light_variation0814.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x), :trial => x -> x .== 1)

subtypes = [:bend, :shorten, :partial_contract, :contract]

function magnitude_score(row)
    row.response == 0.0 && return 0
    row.contract == 1.0 && return 4
    row.partial_contract == 1.0 && return 3
    row.shorten == 1.0 && return 2
    row.bend == 1.0 && return 1
    return 0
end

df.mag = [magnitude_score(row) for row in eachrow(df)]

intensities = [300, 500, 800]
durations   = [10, 15, 20, 30]
int_levels  = [1930, 5900, 13080]
int_labels  = ["300 fc", "500 fc", "800 fc"]
dur_labels  = ["10 s", "15 s", "20 s", "30 s"]

# --- Panel A: Initial magnitude heatmap (stimulus 1) ---
init_mag = zeros(3, 4)
init_n   = zeros(Int, 3, 4)
for (ii, il) in enumerate(int_levels), (di, d) in enumerate(durations)
    rows = subset(df, :light_level => x -> x .== il, :light_duration => x -> x .== d,
                  :stimulus => x -> x .== 1)
    init_mag[ii, di] = mean(rows.mag)
    init_n[ii, di] = nrow(rows)
end

# --- Panel B: Magnitude curves grouped by intensity ---
stimuli = 1:20
colors_int = [:steelblue, :mediumpurple, :forestgreen]
dur_styles = [nothing, :dash, :dot, :dashdot]

# --- Panel C: Magnitude heatmap across stimuli × conditions ---
# Organize as: rows = conditions (grouped by intensity), cols = stimuli
conditions = []
for il in int_levels, d in durations
    push!(conditions, (il, d))
end

mag_matrix = zeros(length(conditions), 20)
n_cells = Int[]
for (ci, (il, d)) in enumerate(conditions)
    cond_df = subset(df, :light_level => x -> x .== il, :light_duration => x -> x .== d)
    push!(n_cells, length(unique(collect(zip(cond_df.fold_name, cond_df.cell_number)))))
    for s in stimuli
        rows = subset(cond_df, :stimulus => x -> x .== s)
        mag_matrix[ci, s] = mean(rows.mag)
    end
end

# --- Figure ---
fig = Figure(size = (1300, 1000), fontsize = 13)

# Panel A: Initial magnitude (stim 1) — 3×4 heatmap
ax1 = Axis(fig[1, 1],
    title = "A. Mean response magnitude — stimulus 1",
    xlabel = "Duration",
    ylabel = "Intensity",
    xticks = (1:4, dur_labels),
    yticks = (1:3, int_labels),
    yreversed = false)

for i in 1:3, j in 1:4
    val = init_mag[i, j]
    poly!(ax1, Rect(j - 0.5, i - 0.5, 1, 1),
        color = (:darkorange, val / 4.0))
    text!(ax1, j, i,
        text = "$(round(val, digits=2))\nn=$(init_n[i,j])",
        align = (:center, :center), fontsize = 11,
        color = val > 2.5 ? :white : :black)
end

# Panel B: Magnitude decline curves — one subplot per intensity
for (ii, (il, int_lbl)) in enumerate(zip(int_levels, int_labels))
    ax = Axis(fig[1, ii + 1],
        title = "B$(ii). Magnitude decline — $int_lbl",
        xlabel = "Stimulus number",
        ylabel = ii == 1 ? "Mean magnitude (0–4)" : "",
        xticks = [1, 5, 10, 15, 20],
        ylabelvisible = ii == 1)

    for (di, d) in enumerate(durations)
        cond_df = subset(df, :light_level => x -> x .== il, :light_duration => x -> x .== d)
        mag_curve = [mean(subset(cond_df, :stimulus => x -> x .== s).mag) for s in stimuli]
        lines!(ax, collect(stimuli), mag_curve, linewidth = 2,
            color = (colors_int[ii], 0.3 + 0.2 * di),
            label = "$(d) s")
    end
    ylims!(ax, -0.1, 4.1)
    if ii == 3
        axislegend(ax, position = :rt, framevisible = false, labelsize = 11)
    end
end

# Panel C: Full heatmap — conditions × stimuli
cond_labels = String[]
for (il, il_lbl) in zip(int_levels, int_labels)
    for d in durations
        ci = findfirst(c -> c == (il, d), conditions)
        push!(cond_labels, "$il_lbl, $(d)s (n=$(n_cells[ci]))")
    end
end

ax3 = Axis(fig[2, 1:4],
    title = "C. Response magnitude surface — all conditions × stimuli",
    xlabel = "Stimulus number",
    ylabel = "Condition",
    xticks = 1:20,
    yticks = (1:12, cond_labels))

for ci in 1:12, s in 1:20
    val = mag_matrix[ci, s]
    poly!(ax3, Rect(s - 0.5, ci - 0.5, 1, 1),
        color = (:darkorange, val / 4.0))
end

# Add intensity group separators
hlines!(ax3, [4.5, 8.5], color = :black, linewidth = 1.5)

Colorbar(fig[2, 5], limits = (0, 4), colormap = cgrad([:white, :darkorange]),
    label = "Mean magnitude",
    ticks = (0:4, ["0\nNo resp", "1\nBend", "2\nShorten", "3\nP.contract", "4\nContract"]))

save("response_magnitude.png", fig, px_per_unit = 3)
println("Saved response_magnitude.png")

# --- Print key stats ---
println("\n=== Initial magnitude (stimulus 1) ===")
for (ii, il_lbl) in enumerate(int_labels)
    for (di, d) in enumerate(durations)
        println("  $il_lbl, $(d)s: mag=$(round(init_mag[ii,di], digits=2)), n=$(init_n[ii,di])")
    end
end

println("\n=== Magnitude at stimulus 20 ===")
for (ci, (il, d)) in enumerate(conditions)
    ii = findfirst(x -> x == il, int_levels)
    println("  $(int_labels[ii]), $(d)s: mag=$(round(mag_matrix[ci, 20], digits=2))")
end

println("\n=== Magnitude drop (stim 1 → stim 20) ===")
for (ci, (il, d)) in enumerate(conditions)
    ii = findfirst(x -> x == il, int_levels)
    drop = mag_matrix[ci, 1] - mag_matrix[ci, 20]
    pct = mag_matrix[ci, 1] > 0 ? round(drop / mag_matrix[ci, 1] * 100, digits=1) : 0.0
    println("  $(int_labels[ii]), $(d)s: Δ=$(round(drop, digits=2)) ($(pct)% decline)")
end
