using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../data/light_hab0805.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x))

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]
stimuli  = 1:20

trial1 = subset(df, :trial => x -> x .== 1)
trial2 = subset(df, :trial => x -> x .== 2)

function compute_rates(sub)
    total = Float64[]
    se    = Float64[]
    srates = Dict(st => Float64[] for st in subtypes)
    ns    = Int[]
    for s in stimuli
        rows = subset(sub, :stimulus => x -> x .== s)
        n = nrow(rows)
        push!(ns, n)
        p = mean(rows.response)
        push!(total, p)
        push!(se, sqrt(p * (1 - p) / n))
        for st in subtypes
            push!(srates[st], sum(rows[!, st]) / n)
        end
    end
    return (; total, se, srates, ns)
end

r1 = compute_rates(trial1)
r2 = compute_rates(trial2)

# ===== Figure 1: P(response) by stimulus, broken down by trial =====
fig1 = Figure(size = (700, 450), fontsize = 14)
ax1 = Axis(fig1[1, 1],
    xlabel = "Stimulus number",
    ylabel = "P(response)",
    title  = "Light habituation — P(response) across two trials (ITI = 40 min, n = $(r1.ns[1]) cells)",
    xticks = 1:20)

band!(ax1, collect(stimuli), r1.total .- r1.se, r1.total .+ r1.se, color = (:black, 0.1))
lines!(ax1, collect(stimuli), r1.total, color = :black, linewidth = 2)
scatter!(ax1, collect(stimuli), r1.total, color = :black, markersize = 8, label = "Trial 1")

band!(ax1, collect(stimuli), r2.total .- r2.se, r2.total .+ r2.se, color = (:red, 0.1))
lines!(ax1, collect(stimuli), r2.total, color = :red, linewidth = 2)
scatter!(ax1, collect(stimuli), r2.total, color = :red, markersize = 8, label = "Trial 2")

axislegend(ax1, position = :rt, framevisible = false)

save("light_hab_response.png", fig1, px_per_unit = 3)
println("Saved light_hab_response.png")

# ===== Figure 2: Grouped stacked bars — trial 1 vs trial 2 =====
groups = [(1,5), (6,10), (11,15), (16,20)]
group_labels = ["1–5", "6–10", "11–15", "16–20"]

function grouped_subtype_rates(sub, groups)
    rates = [Float64[] for _ in subtypes]
    for (lo, hi) in groups
        rows = subset(sub, :stimulus => x -> x .>= lo .&& x .<= hi)
        n = nrow(rows)
        for (i, st) in enumerate(subtypes)
            push!(rates[i], sum(rows[!, st]) / n)
        end
    end
    return rates
end

sr1 = grouped_subtype_rates(trial1, groups)
sr2 = grouped_subtype_rates(trial2, groups)

# pastel = trial 1, saturated = trial 2
t1_colors = [(:steelblue, 0.4), (:mediumpurple, 0.4), (:orange, 0.4), (:crimson, 0.4)]
t2_colors = [(:steelblue, 0.9), (:mediumpurple, 0.9), (:orange, 0.9), (:crimson, 0.9)]

fig2 = Figure(size = (700, 450), fontsize = 14)
ax2 = Axis(fig2[1, 1],
    xlabel = "Stimulus group",
    ylabel = "P(response)",
    title  = "Response composition: Trial 1 vs Trial 2 (ITI = 40 min, n = $(r1.ns[1]) cells)",
    xticks = (1:4, group_labels))

bar_w = 0.35
offset_1 = -bar_w/2 - 0.02
offset_2 =  bar_w/2 + 0.02

for gi in 1:4
    # trial 1 bar (left, pastel)
    local bottom = 0.0
    for si in 1:4
        h = sr1[si][gi]
        poly!(ax2, Rect(gi + offset_1 - bar_w/2, bottom, bar_w, h),
            color = t1_colors[si])
        bottom += h
    end

    # trial 2 bar (right, saturated)
    bottom = 0.0
    for si in 1:4
        h = sr2[si][gi]
        poly!(ax2, Rect(gi + offset_2 - bar_w/2, bottom, bar_w, h),
            color = t2_colors[si])
        bottom += h
    end
end

leg_elems = Vector{Any}([PolyElement(color = (colors[i], 0.7)) for i in eachindex(subtypes)])
push!(leg_elems, PolyElement(color = (:gray50, 0.4)))
push!(leg_elems, PolyElement(color = (:gray50, 0.9)))
Legend(fig2[1, 2], leg_elems,
    [labels; "Trial 1"; "Trial 2"],
    framevisible = false)

save("light_hab_stacked.png", fig2, px_per_unit = 3)
println("Saved light_hab_stacked.png")

# ===== Print stats =====
println("\n--- P(response) stimulus 1 ---")
println("  Trial 1: $(round(r1.total[1], digits=3))  (n=$(r1.ns[1]))")
println("  Trial 2: $(round(r2.total[1], digits=3))  (n=$(r2.ns[1]))")

println("\n--- P(response) stimulus 20 ---")
println("  Trial 1: $(round(r1.total[end], digits=3))")
println("  Trial 2: $(round(r2.total[end], digits=3))")

println("\n--- Grouped subtype rates ---")
for (ti, sr, name) in [(1, sr1, "Trial 1"), (2, sr2, "Trial 2")]
    println("\n$name:")
    for (gi, gl) in enumerate(group_labels)
        vals = join(["$(labels[i])=$(round(sr[i][gi], digits=3))" for i in 1:4], ", ")
        total = sum(sr[i][gi] for i in 1:4)
        println("  $gl: $vals  (total=$(round(total, digits=3)))")
    end
end
