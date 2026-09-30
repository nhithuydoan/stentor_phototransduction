using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../../data/light_hab0805.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x))

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]

function magnitude_score(row)
    row.response == 0.0 && return 0
    row.contract == 1.0 && return 4
    row.partial_contract == 1.0 && return 3
    row.shorten == 1.0 && return 2
    row.bend == 1.0 && return 1
    return 0
end

df.mag = [magnitude_score(row) for row in eachrow(df)]
df.cell_id = collect(zip(df.fold_name, df.cell_number))

trial1 = subset(df, :trial => x -> x .== 1)
trial2 = subset(df, :trial => x -> x .== 2)
cells = unique(df.cell_id)
n_cells = length(cells)

# --- Per-cell: trial 1 endpoint vs trial 2 start ---
t1_late_resp  = Float64[]  # response rate in last 5 stim of trial 1
t1_late_mag   = Float64[]  # mean magnitude in last 5 stim of trial 1
t2_early_resp = Float64[]  # response rate in first 5 stim of trial 2
t2_early_mag  = Float64[]  # mean magnitude in first 5 stim of trial 2
t1_early_resp = Float64[]
t1_early_mag  = Float64[]

for c in cells
    c1 = subset(trial1, :cell_id => x -> x .== Ref(c))
    c2 = subset(trial2, :cell_id => x -> x .== Ref(c))

    late1  = subset(c1, :stimulus => x -> x .>= 16)
    early2 = subset(c2, :stimulus => x -> x .<= 5)
    early1 = subset(c1, :stimulus => x -> x .<= 5)

    push!(t1_late_resp,  mean(late1.response))
    push!(t1_late_mag,   mean(late1.mag))
    push!(t2_early_resp, mean(early2.response))
    push!(t2_early_mag,  mean(early2.mag))
    push!(t1_early_resp, mean(early1.response))
    push!(t1_early_mag,  mean(early1.mag))
end

# --- Categorize cells by trial 1 endpoint ---
# "Still responding" = responded to ≥2/5 of last stimuli; "Habituated" = ≤1/5
hab_mask   = t1_late_resp .<= 0.2
still_mask = t1_late_resp .> 0.2

# --- Per-cell dominant subtype transitions ---
function dominant_subtype(rows)
    total_resp = sum(rows.response)
    total_resp == 0 && return 0
    counts = [sum(rows[!, st]) for st in subtypes]
    _, idx = findmax(counts)
    return idx
end

t1_early_dom = Int[]
t1_late_dom  = Int[]
t2_early_dom = Int[]
t2_late_dom  = Int[]

for c in cells
    c1 = subset(trial1, :cell_id => x -> x .== Ref(c))
    c2 = subset(trial2, :cell_id => x -> x .== Ref(c))
    push!(t1_early_dom, dominant_subtype(subset(c1, :stimulus => x -> x .<= 5)))
    push!(t1_late_dom,  dominant_subtype(subset(c1, :stimulus => x -> x .>= 16)))
    push!(t2_early_dom, dominant_subtype(subset(c2, :stimulus => x -> x .<= 5)))
    push!(t2_late_dom,  dominant_subtype(subset(c2, :stimulus => x -> x .>= 16)))
end

# --- Figure ---
fig = Figure(size = (1300, 1000), fontsize = 13)

# Panel A: scatter — trial 1 late response rate vs trial 2 early response rate
ax1 = Axis(fig[1, 1],
    title = "A. Trial 1 endpoint → Trial 2 start (per cell)",
    xlabel = "P(response), trial 1 stim 16–20",
    ylabel = "P(response), trial 2 stim 1–5")

scatter!(ax1, t1_late_resp .+ randn(n_cells) .* 0.015,
    t2_early_resp .+ randn(n_cells) .* 0.015,
    color = (:black, 0.3), markersize = 6)
ablines!(ax1, 0, 1, color = :red, linestyle = :dash, linewidth = 1)
text!(ax1, 0.6, 0.95, text = "n = $n_cells cells\nr = $(round(cor(t1_late_resp, t2_early_resp), digits=2))",
    align = (:left, :top), fontsize = 12)

# Panel B: magnitude version
ax2 = Axis(fig[1, 2],
    title = "B. Magnitude: Trial 1 late → Trial 2 early",
    xlabel = "Mean magnitude, trial 1 stim 16–20",
    ylabel = "Mean magnitude, trial 2 stim 1–5")

scatter!(ax2, t1_late_mag .+ randn(n_cells) .* 0.03,
    t2_early_mag .+ randn(n_cells) .* 0.03,
    color = (:black, 0.3), markersize = 6)
ablines!(ax2, 0, 1, color = :red, linestyle = :dash, linewidth = 1)
text!(ax2, 2.5, 3.8, text = "r = $(round(cor(t1_late_mag, t2_early_mag), digits=2))",
    align = (:left, :top), fontsize = 12)

# Panel C: grouped bars — trial 1 early, trial 1 late, trial 2 early, trial 2 late
phases = ["T1 early\n(1–5)", "T1 late\n(16–20)", "T2 early\n(1–5)", "T2 late\n(16–20)"]
phase_colors = [:gray30, :gray60, :royalblue, :cornflowerblue]

function pop_subtype_rates(sub, stim_range)
    rows = subset(sub, :stimulus => x -> x .>= stim_range[1] .&& x .<= stim_range[2])
    n = nrow(rows)
    return [sum(rows[!, st]) / n for st in subtypes]
end

sr_t1e = pop_subtype_rates(trial1, (1, 5))
sr_t1l = pop_subtype_rates(trial1, (16, 20))
sr_t2e = pop_subtype_rates(trial2, (1, 5))
sr_t2l = pop_subtype_rates(trial2, (16, 20))
all_rates = [sr_t1e, sr_t1l, sr_t2e, sr_t2l]

ax3 = Axis(fig[1, 3],
    title = "C. Population subtype profile across phases",
    xlabel = "",
    ylabel = "P(subtype)",
    xticks = (1:4, phases))

bar_w = 0.6
for (pi, rates) in enumerate(all_rates)
    local bottom = 0.0
    for si in 1:4
        h = rates[si]
        poly!(ax3, Rect(pi - bar_w/2, bottom, bar_w, h), color = (colors[si], 0.8))
        if h > 0.02
            text!(ax3, pi, bottom + h/2,
                text = "$(round(h, digits=2))",
                align = (:center, :center), fontsize = 9, color = :white)
        end
        bottom += h
    end
end

leg_elems = [PolyElement(color = (colors[i], 0.8)) for i in 1:4]
Legend(fig[1, 4], leg_elems, labels, framevisible = false)

# Panel D: Recovery by trial 1 endpoint — habituated vs still responding
ax4 = Axis(fig[2, 1:2],
    title = "D. Recovery depends on trial 1 endpoint — magnitude over both trials (n=$n_cells cells, same cells)",
    xlabel = "Stimulus number",
    ylabel = "Mean magnitude (0–4)",
    xticks = ([1,5,10,15,20,21,25,30,35,40], ["T1:1","5","10","15","20","T2:1","5","10","15","20"]))

stimuli = 1:20

# Habituated cells
mag_hab_t1 = Float64[]
mag_hab_t2 = Float64[]
hab_cells = cells[hab_mask]
for s in stimuli
    rows1 = subset(trial1, :cell_id => x -> x .∈ Ref(Set(hab_cells)), :stimulus => x -> x .== s)
    rows2 = subset(trial2, :cell_id => x -> x .∈ Ref(Set(hab_cells)), :stimulus => x -> x .== s)
    push!(mag_hab_t1, mean(rows1.mag))
    push!(mag_hab_t2, mean(rows2.mag))
end

# Still responding cells
mag_still_t1 = Float64[]
mag_still_t2 = Float64[]
still_cells = cells[still_mask]
for s in stimuli
    rows1 = subset(trial1, :cell_id => x -> x .∈ Ref(Set(still_cells)), :stimulus => x -> x .== s)
    rows2 = subset(trial2, :cell_id => x -> x .∈ Ref(Set(still_cells)), :stimulus => x -> x .== s)
    push!(mag_still_t1, mean(rows1.mag))
    push!(mag_still_t2, mean(rows2.mag))
end

x_t1 = collect(1:20)
x_t2 = collect(21:40)

lines!(ax4, x_t1, mag_hab_t1, color = :crimson, linewidth = 2)
lines!(ax4, x_t2, mag_hab_t2, color = :crimson, linewidth = 2, linestyle = :dash)
scatter!(ax4, x_t1, mag_hab_t1, color = :crimson, markersize = 5)
scatter!(ax4, x_t2, mag_hab_t2, color = :crimson, markersize = 5)

lines!(ax4, x_t1, mag_still_t1, color = :forestgreen, linewidth = 2)
lines!(ax4, x_t2, mag_still_t2, color = :forestgreen, linewidth = 2, linestyle = :dash)
scatter!(ax4, x_t1, mag_still_t1, color = :forestgreen, markersize = 5)
scatter!(ax4, x_t2, mag_still_t2, color = :forestgreen, markersize = 5)

vlines!(ax4, [20.5], color = :gray50, linestyle = :dash)
text!(ax4, 20.5, 3.5, text = "ITI = 40 min", align = (:center, :bottom), fontsize = 11, color = :gray50)

Legend(fig[2, 3],
    [LineElement(color = :crimson, linewidth = 2),
     LineElement(color = :forestgreen, linewidth = 2),
     LineElement(color = :black, linestyle = :dash)],
    ["Habituated (n=$(sum(hab_mask)))\nT1 late resp ≤ 0.2",
     "Still responding (n=$(sum(still_mask)))\nT1 late resp > 0.2",
     "Trial 2"],
    framevisible = false)

# Panel E: transition matrix — trial 1 late → trial 2 early
state_labels = ["No resp", "Bend", "Shorten", "P.contr.", "Contract"]
n_states = 5

trans = zeros(Int, n_states, n_states)
for i in eachindex(cells)
    from = t1_late_dom[i] + 1
    to   = t2_early_dom[i] + 1
    trans[from, to] += 1
end

trans_pct = zeros(n_states, n_states)
for i in 1:n_states
    row_total = sum(trans[i, :])
    if row_total > 0
        trans_pct[i, :] = trans[i, :] ./ row_total .* 100
    end
end

ax5 = Axis(fig[2, 4],
    title = "E. Recovery: T1 late → T2 early",
    xlabel = "Trial 2 early dominant",
    ylabel = "Trial 1 late dominant",
    xticks = (1:n_states, state_labels),
    yticks = (1:n_states, state_labels),
    yreversed = true,
    aspect = 1,
    xticklabelrotation = π/6)

for i in 1:n_states, j in 1:n_states
    val = trans_pct[i, j]
    poly!(ax5, Rect(j - 0.5, i - 0.5, 1, 1),
        color = (:teal, val / 100 * 0.9))
    count = trans[i, j]
    if count > 0
        text!(ax5, j, i, text = "$(count)\n$(round(Int, val))%",
            align = (:center, :center), fontsize = 9,
            color = val > 50 ? :white : :black)
    end
end

for i in 1:n_states
    text!(ax5, n_states + 0.7, i,
        text = "n=$(sum(trans[i,:]))",
        align = (:left, :center), fontsize = 9, color = :gray40)
end
xlims!(ax5, 0.5, n_states + 1.3)

save("spontaneous_recovery.png", fig, px_per_unit = 3)
println("Saved spontaneous_recovery.png")

# --- Stats ---
println("\n=== Correlation: T1 late → T2 early ===")
println("  Response rate: r = $(round(cor(t1_late_resp, t2_early_resp), digits=3))")
println("  Magnitude:     r = $(round(cor(t1_late_mag, t2_early_mag), digits=3))")

println("\n=== Population subtype rates ===")
for (name, sr) in [("T1 early", sr_t1e), ("T1 late", sr_t1l), ("T2 early", sr_t2e), ("T2 late", sr_t2l)]
    vals = join(["$(labels[i])=$(round(sr[i], digits=3))" for i in 1:4], ", ")
    println("  $name: $vals  (total=$(round(sum(sr), digits=3)))")
end

println("\n=== Recovery by group ===")
println("  Habituated cells (n=$(sum(hab_mask))):")
println("    T1 stim 1 mag:  $(round(mag_hab_t1[1], digits=2))")
println("    T1 stim 20 mag: $(round(mag_hab_t1[20], digits=2))")
println("    T2 stim 1 mag:  $(round(mag_hab_t2[1], digits=2))")
println("    T2 stim 20 mag: $(round(mag_hab_t2[20], digits=2))")
println("  Still responding (n=$(sum(still_mask))):")
println("    T1 stim 1 mag:  $(round(mag_still_t1[1], digits=2))")
println("    T1 stim 20 mag: $(round(mag_still_t1[20], digits=2))")
println("    T2 stim 1 mag:  $(round(mag_still_t2[1], digits=2))")
println("    T2 stim 20 mag: $(round(mag_still_t2[20], digits=2))")
