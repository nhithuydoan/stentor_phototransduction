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

state_labels = ["No resp", "Bend", "Shorten", "P.contr.", "Contract"]
n_states = 5

# --- Build transition counts for consecutive stimuli ---
# P(state on stim n+1 | state on stim n), pooled across all cells and all consecutive pairs
trans_all = zeros(Int, n_states, n_states)

for c in cells
    crows = sort(subset(df, :cell_id => x -> x .== Ref(c)), :stimulus)
    for i in 1:(nrow(crows)-1)
        from = crows.state[i] + 1
        to   = crows.state[i+1] + 1
        trans_all[from, to] += 1
    end
end

trans_pct_all = zeros(n_states, n_states)
for i in 1:n_states
    rt = sum(trans_all[i, :])
    if rt > 0
        trans_pct_all[i, :] = trans_all[i, :] ./ rt .* 100
    end
end

# --- Split into early (stim 1-10 → 2-11) and late (stim 10-19 → 11-20) ---
trans_early = zeros(Int, n_states, n_states)
trans_late  = zeros(Int, n_states, n_states)

for c in cells
    crows = sort(subset(df, :cell_id => x -> x .== Ref(c)), :stimulus)
    for i in 1:(nrow(crows)-1)
        s = crows.stimulus[i]
        from = crows.state[i] + 1
        to   = crows.state[i+1] + 1
        if s <= 10
            trans_early[from, to] += 1
        else
            trans_late[from, to] += 1
        end
    end
end

trans_pct_early = zeros(n_states, n_states)
trans_pct_late  = zeros(n_states, n_states)
for i in 1:n_states
    re = sum(trans_early[i, :])
    rl = sum(trans_late[i, :])
    if re > 0; trans_pct_early[i, :] = trans_early[i, :] ./ re .* 100; end
    if rl > 0; trans_pct_late[i, :]  = trans_late[i, :]  ./ rl .* 100; end
end

# --- Key transition probabilities over time (sliding window of 4 consecutive pairs) ---
# Track: P(no resp on n+1 | contract on n), P(contract on n+1 | contract on n),
#        P(no resp on n+1 | no resp on n), P(any resp on n+1 | no resp on n)

windows = [(s, s+3) for s in 1:16]
win_labels = ["$(w[1])-$(w[2])" for w in windows]

p_contract_to_norsp = Float64[]
p_contract_to_contract = Float64[]
p_norsp_to_norsp = Float64[]
p_norsp_to_anyresp = Float64[]
p_contract_to_lower = Float64[]

for (lo, hi) in windows
    local tc = zeros(Int, n_states, n_states)
    for c in cells
        crows = sort(subset(df, :cell_id => x -> x .== Ref(c)), :stimulus)
        for i in 1:(nrow(crows)-1)
            s = crows.stimulus[i]
            if s >= lo && s <= hi
                from = crows.state[i] + 1
                to   = crows.state[i+1] + 1
                tc[from, to] += 1
            end
        end
    end

    # Contract (state 5) → no resp (state 1)
    rc = sum(tc[5, :])
    push!(p_contract_to_norsp, rc > 0 ? tc[5, 1] / rc * 100 : NaN)
    push!(p_contract_to_contract, rc > 0 ? tc[5, 5] / rc * 100 : NaN)
    push!(p_contract_to_lower, rc > 0 ? sum(tc[5, 1:4]) / rc * 100 : NaN)

    # No resp (state 1) → no resp
    rn = sum(tc[1, :])
    push!(p_norsp_to_norsp, rn > 0 ? tc[1, 1] / rn * 100 : NaN)
    push!(p_norsp_to_anyresp, rn > 0 ? sum(tc[1, 2:5]) / rn * 100 : NaN)
end

# --- Figure ---
fig = Figure(size = (1400, 1100), fontsize = 13)

function draw_heatmap!(ax, trans, trans_pct, title_str)
    ax.title = title_str
    ax.xlabel = "State on stim n+1"
    ax.ylabel = "State on stim n"
    ax.xticks = (1:n_states, state_labels)
    ax.yticks = (1:n_states, state_labels)
    ax.yreversed = true
    ax.aspect = 1
    ax.xticklabelrotation = π/6

    for i in 1:n_states, j in 1:n_states
        val = trans_pct[i, j]
        poly!(ax, Rect(j - 0.5, i - 0.5, 1, 1),
            color = (:indigo, val / 100 * 0.9))
        count = trans[i, j]
        if count > 0
            text!(ax, j, i, text = "$(count)\n$(round(Int, val))%",
                align = (:center, :center), fontsize = 9,
                color = val > 40 ? :white : :black)
        end
    end
    for i in 1:n_states
        text!(ax, n_states + 0.7, i,
            text = "n=$(sum(trans[i,:]))",
            align = (:left, :center), fontsize = 9, color = :gray40)
    end
    xlims!(ax, 0.5, n_states + 1.3)
end

# Row 1: Three heatmaps
ax1 = Axis(fig[1, 1])
draw_heatmap!(ax1, trans_all, trans_pct_all, "A. All transitions (800fc 30s)")

ax2 = Axis(fig[1, 2])
draw_heatmap!(ax2, trans_early, trans_pct_early, "B. Early transitions (stim 1–10)")

ax3 = Axis(fig[1, 3])
draw_heatmap!(ax3, trans_late, trans_pct_late, "C. Late transitions (stim 11–20)")

# Row 2: Transition probability dynamics
ax4 = Axis(fig[2, 1:2],
    title = "D. Key transition probabilities over time (4-stimulus sliding window)",
    xlabel = "Stimulus window",
    ylabel = "Transition probability (%)",
    xticks = (1:length(windows), win_labels),
    xticklabelrotation = π/4)

xs = collect(1:length(windows))
lines!(ax4, xs, p_contract_to_norsp, color = :crimson, linewidth = 2, linestyle = :dash)
scatter!(ax4, xs, p_contract_to_norsp, color = :crimson, markersize = 6)

lines!(ax4, xs, p_contract_to_contract, color = :crimson, linewidth = 2)
scatter!(ax4, xs, p_contract_to_contract, color = :crimson, markersize = 6)

lines!(ax4, xs, p_norsp_to_norsp, color = :gray40, linewidth = 2)
scatter!(ax4, xs, p_norsp_to_norsp, color = :gray40, markersize = 6)

lines!(ax4, xs, p_norsp_to_anyresp, color = :gray40, linewidth = 2, linestyle = :dash)
scatter!(ax4, xs, p_norsp_to_anyresp, color = :gray40, markersize = 6)

Legend(fig[2, 3],
    [LineElement(color = :crimson, linewidth = 2),
     LineElement(color = :crimson, linewidth = 2, linestyle = :dash),
     LineElement(color = :gray40, linewidth = 2),
     LineElement(color = :gray40, linewidth = 2, linestyle = :dash)],
    ["Contract → Contract",
     "Contract → No resp",
     "No resp → No resp",
     "No resp → Any resp"],
    framevisible = false)

# Row 3: Escalation vs de-escalation over time
p_escalate   = Float64[]  # P(higher state on n+1 | responding on n)
p_deescalate = Float64[]  # P(lower state on n+1 | responding on n)
p_same       = Float64[]

for (lo, hi) in windows
    local esc = 0
    local deesc = 0
    local same = 0
    local total = 0
    for c in cells
        crows = sort(subset(df, :cell_id => x -> x .== Ref(c)), :stimulus)
        for i in 1:(nrow(crows)-1)
            s = crows.stimulus[i]
            if s >= lo && s <= hi && crows.state[i] > 0
                total += 1
                if crows.state[i+1] > crows.state[i]
                    esc += 1
                elseif crows.state[i+1] < crows.state[i]
                    deesc += 1
                else
                    same += 1
                end
            end
        end
    end
    push!(p_escalate, total > 0 ? esc / total * 100 : NaN)
    push!(p_deescalate, total > 0 ? deesc / total * 100 : NaN)
    push!(p_same, total > 0 ? same / total * 100 : NaN)
end

ax5 = Axis(fig[3, 1:2],
    title = "E. Escalation vs de-escalation (among responding cells)",
    xlabel = "Stimulus window",
    ylabel = "Probability (%)",
    xticks = (1:length(windows), win_labels),
    xticklabelrotation = π/4)

lines!(ax5, xs, p_escalate, color = :forestgreen, linewidth = 2)
scatter!(ax5, xs, p_escalate, color = :forestgreen, markersize = 6)
lines!(ax5, xs, p_deescalate, color = :tomato, linewidth = 2)
scatter!(ax5, xs, p_deescalate, color = :tomato, markersize = 6)
lines!(ax5, xs, p_same, color = :gray50, linewidth = 2, linestyle = :dash)
scatter!(ax5, xs, p_same, color = :gray50, markersize = 6)

Legend(fig[3, 3],
    [LineElement(color = :forestgreen, linewidth = 2),
     LineElement(color = :tomato, linewidth = 2),
     LineElement(color = :gray50, linewidth = 2, linestyle = :dash)],
    ["Escalate (→ higher)",
     "De-escalate (→ lower)",
     "Same state"],
    framevisible = false)

Label(fig[0, 1:3],
    "Stimulus-by-stimulus transition analysis — 800 fc, 30 s (n=$n_cells cells)",
    fontsize = 16, font = :bold)

save("transition_probabilities.png", fig, px_per_unit = 3)
println("Saved transition_probabilities.png")

# --- Print key findings ---
println("\n=== Overall transition matrix (row → col) ===")
for i in 1:n_states
    vals = join(["$(state_labels[j]):$(round(Int, trans_pct_all[i,j]))%" for j in 1:n_states], "  ")
    println("  $(state_labels[i]) → $vals  (n=$(sum(trans_all[i,:])))")
end

println("\n=== Key persistence probabilities ===")
println("  P(contract → contract): $(round(trans_pct_all[5,5], digits=1))%")
println("  P(no resp → no resp):   $(round(trans_pct_all[1,1], digits=1))%")
println("  P(contract → no resp):  $(round(trans_pct_all[5,1], digits=1))%")
println("  P(no resp → any resp):  $(round(100 - trans_pct_all[1,1], digits=1))%")

println("\n=== Early vs Late ===")
println("  Early P(contract→contract): $(round(trans_pct_early[5,5], digits=1))%")
println("  Late  P(contract→contract): $(round(trans_pct_late[5,5], digits=1))%")
println("  Early P(no resp→no resp):   $(round(trans_pct_early[1,1], digits=1))%")
println("  Late  P(no resp→no resp):   $(round(trans_pct_late[1,1], digits=1))%")
