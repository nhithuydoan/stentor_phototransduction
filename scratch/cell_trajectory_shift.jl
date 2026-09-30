using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../data/light_variation0814.csv", DataFrame)
sub = subset(df, :trial => x -> x .== 1, :response => x -> .!isnan.(x))
sub = subset(sub, :condition => x -> x .== "800fc 30s")

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "Partial\ncontract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]

sub.cell_id = collect(zip(sub.fold_name, sub.cell_number))
cells = unique(sub.cell_id)

function dominant_subtype(rows)
    total_resp = sum(rows.response)
    if total_resp == 0
        return 0
    end
    counts = [sum(rows[!, st]) for st in subtypes]
    _, idx = findmax(counts)
    return idx
end

function subtype_fractions(rows)
    n = nrow(rows)
    return [sum(rows[!, st]) / n for st in subtypes]
end

# --- Per-cell early vs late ---
early_dom = Int[]
late_dom  = Int[]
early_resp_rate = Float64[]
late_resp_rate  = Float64[]

for c in cells
    crows = subset(sub, :cell_id => x -> x .== Ref(c))
    e = subset(crows, :stimulus => x -> x .<= 5)
    l = subset(crows, :stimulus => x -> x .>= 16)
    push!(early_dom, dominant_subtype(e))
    push!(late_dom, dominant_subtype(l))
    push!(early_resp_rate, mean(e.response))
    push!(late_resp_rate, mean(l.response))
end

# transition matrix
state_labels = ["No resp.", "Bend", "Shorten", "P.contract", "Contract"]
n_states = 5
trans = zeros(Int, n_states, n_states)
for i in eachindex(cells)
    from = early_dom[i] + 1
    to   = late_dom[i] + 1
    trans[from, to] += 1
end

# row-normalized version (proportion of each early type that goes to each late type)
trans_pct = zeros(n_states, n_states)
for i in 1:n_states
    row_total = sum(trans[i, :])
    if row_total > 0
        trans_pct[i, :] = trans[i, :] ./ row_total .* 100
    end
end

# --- Population subtype fractions (absolute, not conditional) ---
early_rows = subset(sub, :stimulus => x -> x .<= 5)
late_rows  = subset(sub, :stimulus => x -> x .>= 16)
early_frac = subtype_fractions(early_rows)
late_frac  = subtype_fractions(late_rows)

# --- Figure ---
fig = Figure(size = (1200, 900), fontsize = 13)

# Panel A: Transition heatmap
ax1 = Axis(fig[1, 1],
    title = "Cell fate: early dominant → late dominant",
    xlabel = "Late dominant subtype (stim 16–20)",
    ylabel = "Early dominant subtype (stim 1–5)",
    xticks = (1:n_states, state_labels),
    yticks = (1:n_states, state_labels),
    yreversed = true,
    aspect = 1)

# draw heatmap cells
for i in 1:n_states, j in 1:n_states
    val = trans_pct[i, j]
    poly!(ax1, Rect(j - 0.5, i - 0.5, 1, 1),
        color = (:crimson, val / 100 * 0.9))
    count = trans[i, j]
    if count > 0
        text!(ax1, j, i, text = "$(count)\n$(round(Int, val))%",
            align = (:center, :center), fontsize = 11,
            color = val > 50 ? :white : :black)
    end
end

# row totals as annotation
for i in 1:n_states
    text!(ax1, n_states + 0.8, i,
        text = "n=$(sum(trans[i,:]))",
        align = (:left, :center), fontsize = 10, color = :gray40)
end

xlims!(ax1, 0.5, n_states + 1.5)

# Panel B: scatter early vs late response rate
ax2 = Axis(fig[2, 1],
    title = "Per-cell response rate: early vs late",
    xlabel = "P(response), stim 1–5",
    ylabel = "P(response), stim 16–20",
    aspect = 1)

lines!(ax2, [0, 1], [0, 1], color = :gray70, linestyle = :dash, linewidth = 1)
scatter!(ax2, early_resp_rate .+ randn(length(early_resp_rate)) .* 0.015,
    late_resp_rate .+ randn(length(late_resp_rate)) .* 0.015,
    color = (:black, 0.3), markersize = 8)

# Panel C: grouped bar — early vs late subtype fractions (absolute P(subtype))
ax3 = Axis(fig[2, 2],
    title = "Population subtype rates: early vs late",
    xlabel = "Subtype",
    ylabel = "P(subtype)",
    xticks = (1:4, labels))

bar_w = 0.3
for (i, (ef, lf)) in enumerate(zip(early_frac, late_frac))
    poly!(ax3, Rect(i - bar_w - 0.02, 0, bar_w, ef),
        color = (:gray55, 0.8))
    poly!(ax3, Rect(i + 0.02, 0, bar_w, lf),
        color = (colors[i], 0.9))
end

# legend for Panel C
Legend(fig[2, 3],
    [PolyElement(color = (:gray55, 0.8)), PolyElement(color = (:crimson, 0.9))],
    ["Early (1–5)", "Late (16–20)"],
    framevisible = false)

save("cell_trajectory_shift.png", fig, px_per_unit = 3)
println("Saved cell_trajectory_shift.png")

# --- Print summary ---
println("\n--- Transition matrix (row = early, col = late, counts) ---")
println("         ", join(lpad.(state_labels, 11)))
for i in 1:n_states
    print(rpad(state_labels[i], 11))
    for j in 1:n_states
        print(lpad("$(trans[i,j])", 11))
    end
    println()
end

println("\n--- Cells that contracted early (N=41) → late fate ---")
contract_early = findall(x -> x == 4, early_dom)
late_of = [late_dom[i] for i in contract_early]
for s in 0:4
    n = count(x -> x == s, late_of)
    lbl = s == 0 ? "No response" : labels[s]
    println("  → $(lbl): $n ($(round(n/41*100, digits=1))%)")
end

println("\n--- Absolute subtype rates ---")
println("  Early (stim 1-5):  ", join(["$(labels[i])=$(round(early_frac[i], digits=3))" for i in 1:4], ", "))
println("  Late  (stim 16-20): ", join(["$(labels[i])=$(round(late_frac[i], digits=3))" for i in 1:4], ", "))
