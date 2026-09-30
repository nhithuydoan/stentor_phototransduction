using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../../data/light_variation0814.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x),
            :trial => x -> x .== 1,
            :light_level => x -> x .== 13080,
            :light_duration => x -> x .== 30)

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]

function cell_state(row)
    row.response == 0.0 && return 0
    row.contract == 1.0 && return 4
    row.partial_contract == 1.0 && return 3
    row.shorten == 1.0 && return 2
    row.bend == 1.0 && return 1
    return 0
end

df.state = [cell_state(row) for row in eachrow(df)]
df.cell_id = collect(zip(df.fold_name, df.cell_number))
cells = unique(df.cell_id)
n_cells = length(cells)

function shannon_entropy(counts)
    total = sum(counts)
    total == 0 && return 0.0
    h = 0.0
    for c in counts
        c == 0 && continue
        p = c / total
        h -= p * log2(p)
    end
    return h
end

# --- Per-cell features ---
entropies    = Float64[]
total_resp   = Int[]
dom_subtype  = Int[]
subtype_counts_all = Vector{Vector{Int}}()

for c in cells
    crows = subset(df, :cell_id => x -> x .== Ref(c))
    resp = subset(crows, :response => x -> x .== 1.0)
    nr = nrow(resp)
    push!(total_resp, nr)

    counts = [sum(resp[!, st]) for st in subtypes]
    push!(subtype_counts_all, counts)

    if nr >= 3
        push!(entropies, shannon_entropy(counts))
    else
        push!(entropies, NaN)
    end

    if nr > 0
        _, idx = findmax(counts)
        push!(dom_subtype, idx)
    else
        push!(dom_subtype, 0)
    end
end

valid = .!isnan.(entropies)
n_valid = sum(valid)

# --- Figure ---
fig = Figure(size = (1400, 1000), fontsize = 13)

# Panel A: Histogram of entropy values
ax1 = Axis(fig[1, 1],
    title = "A. Distribution of per-cell response entropy (≥3 responses, n=$n_valid)",
    xlabel = "Shannon entropy (bits)",
    ylabel = "Number of cells")

hist!(ax1, entropies[valid], bins = 0:0.15:2.1, color = (:teal, 0.7))
vlines!(ax1, [mean(entropies[valid])], color = :red, linewidth = 2, linestyle = :dash)
text!(ax1, mean(entropies[valid]) + 0.05, 12,
    text = "mean=$(round(mean(entropies[valid]), digits=2))\nmax possible=2.0",
    align = (:left, :center), fontsize = 11, color = :red)

# Panel B: Scatter — total responses vs entropy, colored by dominant subtype
ax2 = Axis(fig[1, 2],
    title = "B. Total responses vs entropy",
    xlabel = "Total responses (out of 20)",
    ylabel = "Shannon entropy (bits)")

for si in 1:4
    mask = valid .& (dom_subtype .== si)
    if sum(mask) > 0
        scatter!(ax2, total_resp[mask] .+ randn(sum(mask)) .* 0.15,
            entropies[mask],
            color = (colors[si], 0.6), markersize = 7,
            label = "$(labels[si]) dominant (n=$(sum(mask)))")
    end
end
axislegend(ax2, position = :lt, framevisible = false, labelsize = 10)
hlines!(ax2, [1.0], color = :gray50, linestyle = :dash, linewidth = 1)
text!(ax2, 18, 1.05, text = "H=1.0 (two-type mix)", fontsize = 9, color = :gray50,
    align = (:right, :bottom))

# Panel C: Example rasters for representative cells
# Find low, medium, high entropy cells (among those with ≥5 responses for clearer rasters)
valid5 = valid .& (total_resp .>= 5)
ent_sorted = sortperm(entropies)
valid5_idx = findall(valid5)

low_ent_idx  = valid5_idx[argmin(entropies[valid5_idx])]
high_ent_idx = valid5_idx[argmax(entropies[valid5_idx])]
mid_target = median(entropies[valid5_idx])
mid_ent_idx  = valid5_idx[argmin(abs.(entropies[valid5_idx] .- mid_target))]

state_colors = [:gray92, :steelblue, :mediumpurple, :orange, :crimson]
examples = [(low_ent_idx, "Low entropy"), (mid_ent_idx, "Medium entropy"), (high_ent_idx, "High entropy")]

for (row_i, (ci, label)) in enumerate(examples)
    c = cells[ci]
    crows = sort(subset(df, :cell_id => x -> x .== Ref(c)), :stimulus)
    h = entropies[ci]
    nr = total_resp[ci]
    counts = subtype_counts_all[ci]
    dist_str = join(["$(labels[i]):$(counts[i])" for i in 1:4 if counts[i] > 0], ", ")

    ax = Axis(fig[2, row_i],
        title = "$label (H=$(round(h, digits=2)), n_resp=$nr)\n$dist_str",
        xlabel = "Stimulus number",
        ylabel = "",
        xticks = [1, 5, 10, 15, 20],
        yticks = ([1], ["Cell"]))

    for row in eachrow(crows)
        v = row.state
        poly!(ax, Rect(row.stimulus - 0.4, 0.6, 0.8, 0.8), color = state_colors[v + 1])
    end
    ylims!(ax, 0.2, 1.8)
end

leg_elems = [PolyElement(color = c) for c in state_colors]
Legend(fig[2, 4], leg_elems, ["No response", labels...], framevisible = false)

# Panel D: What fraction of cells are "consistent" (H < 0.5) vs "variable" (H > 1.0)?
ax4 = Axis(fig[3, 1:2],
    title = "D. Response type consistency spectrum",
    xlabel = "",
    ylabel = "Number of cells",
    xticks = (1:3, ["Consistent\n(H < 0.5)", "Moderate\n(0.5 ≤ H < 1.0)", "Variable\n(H ≥ 1.0)"]))

n_consistent = sum(entropies[valid] .< 0.5)
n_moderate   = sum(0.5 .<= entropies[valid] .< 1.0)
n_variable   = sum(entropies[valid] .>= 1.0)

barplot!(ax4, [1, 2, 3], [n_consistent, n_moderate, n_variable],
    color = [:forestgreen, :goldenrod, :tomato])

for (i, n) in enumerate([n_consistent, n_moderate, n_variable])
    pct = round(n / n_valid * 100, digits=1)
    text!(ax4, i, n + 0.5, text = "$n ($pct%)", align = (:center, :bottom), fontsize = 12)
end

# Panel E: Entropy by phenotype — do contractors have lower entropy?
ax5 = Axis(fig[3, 3],
    title = "E. Entropy by dominant subtype",
    xlabel = "Dominant subtype",
    ylabel = "Shannon entropy",
    xticks = (1:4, labels))

for si in 1:4
    mask = valid .& (dom_subtype .== si)
    vals = entropies[mask]
    if length(vals) >= 3
        scatter!(ax5, fill(si, length(vals)) .+ randn(length(vals)) .* 0.08,
            vals, color = (colors[si], 0.4), markersize = 5)
        hlines_y = mean(vals)
        lines!(ax5, [si - 0.3, si + 0.3], [hlines_y, hlines_y],
            color = colors[si], linewidth = 3)
    end
end

Label(fig[0, 1:4],
    "Within-cell entropy analysis — 800 fc, 30 s (n=$n_cells cells)",
    fontsize = 16, font = :bold)

save("within_cell_entropy.png", fig, px_per_unit = 3)
println("Saved within_cell_entropy.png")

# --- Stats ---
println("\n=== Entropy stats (cells with ≥3 responses, n=$n_valid) ===")
println("  Mean: $(round(mean(entropies[valid]), digits=3))")
println("  Median: $(round(median(entropies[valid]), digits=3))")
println("  Std: $(round(std(entropies[valid]), digits=3))")
println("  Min: $(round(minimum(entropies[valid]), digits=3))")
println("  Max: $(round(maximum(entropies[valid]), digits=3))")

println("\n=== Consistency categories ===")
println("  Consistent (H < 0.5): $n_consistent ($(round(n_consistent/n_valid*100, digits=1))%)")
println("  Moderate (0.5–1.0):   $n_moderate ($(round(n_moderate/n_valid*100, digits=1))%)")
println("  Variable (H ≥ 1.0):   $n_variable ($(round(n_variable/n_valid*100, digits=1))%)")

println("\n=== Mean entropy by dominant subtype ===")
for si in 1:4
    mask = valid .& (dom_subtype .== si)
    vals = entropies[mask]
    if length(vals) > 0
        println("  $(labels[si]): $(round(mean(vals), digits=3)) (n=$(length(vals)))")
    end
end
