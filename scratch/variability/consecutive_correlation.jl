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

# --- Build conditional transition matrix (both responded) ---
# 4×4: subtype on n → subtype on n+1, ONLY counting pairs where cell responded on both
trans_all   = zeros(Int, 4, 4)
trans_early = zeros(Int, 4, 4)
trans_late  = zeros(Int, 4, 4)

for c in cells
    crows = sort(subset(df, :cell_id => x -> x .== Ref(c)), :stimulus)
    for i in 1:(nrow(crows)-1)
        s_n  = crows.state[i]
        s_n1 = crows.state[i+1]
        s_n > 0 && s_n1 > 0 || continue

        trans_all[s_n, s_n1] += 1
        if crows.stimulus[i] <= 10
            trans_early[s_n, s_n1] += 1
        else
            trans_late[s_n, s_n1] += 1
        end
    end
end

function to_pct(trans)
    pct = zeros(4, 4)
    for i in 1:4
        rt = sum(trans[i, :])
        if rt > 0
            pct[i, :] = trans[i, :] ./ rt .* 100
        end
    end
    return pct
end

pct_all   = to_pct(trans_all)
pct_early = to_pct(trans_early)
pct_late  = to_pct(trans_late)

# --- Persistence probability per subtype ---
persist_all   = [pct_all[i, i] for i in 1:4]
persist_early = [pct_early[i, i] for i in 1:4]
persist_late  = [pct_late[i, i] for i in 1:4]

# --- Expected if independent (marginal distribution of n+1) ---
marginal_all = Float64[]
total_pairs = sum(trans_all)
for j in 1:4
    push!(marginal_all, sum(trans_all[:, j]) / total_pairs * 100)
end

# --- Figure ---
fig = Figure(size = (1400, 1000), fontsize = 13)

# Panel A: Overall conditional transition heatmap
function draw_subtype_heatmap!(ax, trans, pct, title_str)
    ax.title = title_str
    ax.xlabel = "Subtype on stim n+1"
    ax.ylabel = "Subtype on stim n"
    ax.xticks = (1:4, labels)
    ax.yticks = (1:4, labels)
    ax.yreversed = true
    ax.aspect = 1
    ax.xticklabelrotation = π/6

    for i in 1:4, j in 1:4
        val = pct[i, j]
        poly!(ax, Rect(j - 0.5, i - 0.5, 1, 1),
            color = (:indigo, val / 100 * 1.5))
        count = trans[i, j]
        if count > 0
            text!(ax, j, i, text = "$(count)\n$(round(Int, val))%",
                align = (:center, :center), fontsize = 10,
                color = val > 35 ? :white : :black)
        end
    end
    for i in 1:4
        text!(ax, 4.7, i,
            text = "n=$(sum(trans[i,:]))",
            align = (:left, :center), fontsize = 9, color = :gray40)
    end
    xlims!(ax, 0.5, 5.2)
end

ax1 = Axis(fig[1, 1])
draw_subtype_heatmap!(ax1, trans_all, pct_all,
    "A. Subtype transition (both responded)\nAll stimuli")

ax2 = Axis(fig[1, 2])
draw_subtype_heatmap!(ax2, trans_early, pct_early,
    "B. Early (stim 1–10)")

ax3 = Axis(fig[1, 3])
draw_subtype_heatmap!(ax3, trans_late, pct_late,
    "C. Late (stim 11–20)")

# Panel D: Persistence probability — observed vs expected if independent
ax4 = Axis(fig[2, 1:2],
    title = "D. Persistence: P(same subtype on n+1) — observed vs chance",
    xlabel = "Subtype",
    ylabel = "P(same subtype | responded both)",
    xticks = (1:4, labels))

bar_w = 0.3
for si in 1:4
    poly!(ax4, Rect(si - bar_w - 0.02, 0, bar_w, persist_all[si]),
        color = (colors[si], 0.8))
    poly!(ax4, Rect(si + 0.02, 0, bar_w, marginal_all[si]),
        color = (:gray50, 0.5))

    text!(ax4, si - bar_w/2 - 0.02, persist_all[si] + 0.5,
        text = "$(round(Int, persist_all[si]))%",
        align = (:center, :bottom), fontsize = 10, color = colors[si])
    text!(ax4, si + bar_w/2 + 0.02, marginal_all[si] + 0.5,
        text = "$(round(Int, marginal_all[si]))%",
        align = (:center, :bottom), fontsize = 10, color = :gray50)
end

Legend(fig[2, 3],
    [PolyElement(color = (:steelblue, 0.8)), PolyElement(color = (:gray50, 0.5))],
    ["Observed P(persist)", "Expected if independent\n(marginal rate)"],
    framevisible = false)

# Panel E: Persistence early vs late
ax5 = Axis(fig[3, 1:2],
    title = "E. Persistence probability: early vs late stimuli",
    xlabel = "Subtype",
    ylabel = "P(same subtype | responded both)",
    xticks = (1:4, labels))

for si in 1:4
    poly!(ax5, Rect(si - bar_w - 0.02, 0, bar_w, persist_early[si]),
        color = (colors[si], 0.5))
    poly!(ax5, Rect(si + 0.02, 0, bar_w, persist_late[si]),
        color = (colors[si], 0.9))

    text!(ax5, si - bar_w/2 - 0.02, persist_early[si] + 0.5,
        text = "$(round(Int, persist_early[si]))%",
        align = (:center, :bottom), fontsize = 10)
    text!(ax5, si + bar_w/2 + 0.02, persist_late[si] + 0.5,
        text = "$(round(Int, persist_late[si]))%",
        align = (:center, :bottom), fontsize = 10)
end

Legend(fig[3, 3],
    [PolyElement(color = (:gray50, 0.5)), PolyElement(color = (:gray50, 0.9))],
    ["Early (stim 1–10)", "Late (stim 11–20)"],
    framevisible = false)

Label(fig[0, 1:3],
    "Consecutive response correlation — 800 fc, 30 s (conditional on responding both stimuli)",
    fontsize = 15, font = :bold)

save("consecutive_correlation.png", fig, px_per_unit = 3)
println("Saved consecutive_correlation.png")

# --- Stats ---
println("\n=== Overall conditional transition matrix ===")
println("  (Row = subtype on n, Col = subtype on n+1, given responded both)")
for i in 1:4
    vals = join(["$(labels[j]):$(round(Int, pct_all[i,j]))%" for j in 1:4], "  ")
    println("  $(labels[i]) → $vals  (n=$(sum(trans_all[i,:])))")
end

println("\n=== Persistence probabilities ===")
for si in 1:4
    println("  $(labels[si]): observed=$(round(Int, persist_all[si]))%  chance=$(round(Int, marginal_all[si]))%  ratio=$(round(persist_all[si]/marginal_all[si], digits=2))x")
end

println("\n=== Early vs Late persistence ===")
for si in 1:4
    println("  $(labels[si]): early=$(round(Int, persist_early[si]))%  late=$(round(Int, persist_late[si]))%")
end

println("\n=== Total consecutive-response pairs ===")
println("  All: $(sum(trans_all))")
println("  Early: $(sum(trans_early))")
println("  Late: $(sum(trans_late))")
