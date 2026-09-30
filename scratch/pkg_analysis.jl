using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../data/PKG_0803.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x))

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]
stimuli  = 1:20

function compute_rates(sub)
    total = Float64[]
    se    = Float64[]
    srates = Dict(s => Float64[] for s in subtypes)
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

water = subset(df, :condition => x -> x .== "water")
pkg   = subset(df, :condition => x -> x .== "PKG")
rw = compute_rates(water)
rp = compute_rates(pkg)

df2 = CSV.read("../data/light_variation0814.csv", DataFrame)
ctrl = subset(df2, :trial => x -> x .== 1, :response => x -> .!isnan.(x),
              :condition => x -> x .== "800fc 30s")
rc = compute_rates(ctrl)

function subtype_fracs(rows)
    n = nrow(rows)
    return [sum(rows[!, st]) / n for st in subtypes]
end

# --- Figure: 4 rows ---
fig = Figure(size = (1000, 1200), fontsize = 13)

# Row 1: P(response) across stimuli — water vs PKG vs 800fc30s
ax1 = Axis(fig[1, 1],
    title = "P(response) across stimuli",
    xlabel = "Stimulus number", ylabel = "P(response)",
    xticks = 1:20)

band!(ax1, collect(stimuli), rw.total .- rw.se, rw.total .+ rw.se, color = (:black, 0.1))
lines!(ax1, collect(stimuli), rw.total, color = :black, linewidth = 2, label = "Water (PKG expt)")
band!(ax1, collect(stimuli), rp.total .- rp.se, rp.total .+ rp.se, color = (:red, 0.1))
lines!(ax1, collect(stimuli), rp.total, color = :red, linewidth = 2, label = "PKG")
lines!(ax1, collect(stimuli), rc.total, color = :gray50, linewidth = 1.5, linestyle = :dash,
    label = "800fc 30s (main expt)")
axislegend(ax1, position = :rt, framevisible = false)

# Row 2: stacked subtype areas side by side
for (col, cond_data, cond_name) in [(1, rw, "Water — subtype rates"), (2, rp, "PKG — subtype rates")]
    ax = Axis(fig[2, col],
        title = cond_name,
        xlabel = "Stimulus number", ylabel = "P(subtype)",
        xticks = (1:4:20, string.(1:4:20)))

    let cumlow = zeros(length(stimuli))
        for (i, st) in enumerate(subtypes)
            cumhigh = cumlow .+ cond_data.srates[st]
            band!(ax, collect(stimuli), cumlow, cumhigh, color = (colors[i], 0.7))
            cumlow = cumhigh
        end
    end
    lines!(ax, collect(stimuli), cond_data.total, color = :black, linewidth = 2, linestyle = :dash)
end

leg_elems = Vector{Any}([PolyElement(color = (colors[i], 0.7)) for i in eachindex(subtypes)])
push!(leg_elems, LineElement(color = :black, linewidth = 2, linestyle = :dash))
Legend(fig[2, 3], leg_elems, [labels; "P(response)"], framevisible = false)

# Row 3: Water vs PKG mean subtype rates
ax3 = Axis(fig[3, 1:2],
    title = "Mean subtype rate across all 20 stimuli: Water vs PKG",
    xlabel = "Subtype", ylabel = "Mean P(subtype)",
    xticks = (1:4, labels))

water_means = [mean(rw.srates[st]) for st in subtypes]
pkg_means   = [mean(rp.srates[st]) for st in subtypes]
bar_w = 0.3

for i in 1:4
    poly!(ax3, Rect(i - bar_w - 0.02, 0, bar_w, water_means[i]),
        color = (:gray55, 0.8))
    poly!(ax3, Rect(i + 0.02, 0, bar_w, pkg_means[i]),
        color = (colors[i], 0.9))
end

Legend(fig[3, 3],
    [PolyElement(color = (:gray55, 0.8)), PolyElement(color = (:crimson, 0.9))],
    ["Water", "PKG"],
    framevisible = false)

# Row 4: early vs late within each condition
for (col, cond_sub, cond_name) in [(1, water, "Water"), (2, pkg, "PKG")]
    ax = Axis(fig[4, col],
        title = "$cond_name — early vs late subtype rates",
        xlabel = "Subtype", ylabel = "P(subtype)",
        xticks = (1:4, labels))

    ef = subtype_fracs(subset(cond_sub, :stimulus => x -> x .<= 5))
    lf = subtype_fracs(subset(cond_sub, :stimulus => x -> x .>= 16))

    for i in 1:4
        poly!(ax, Rect(i - bar_w - 0.02, 0, bar_w, ef[i]),
            color = (:gray55, 0.8))
        poly!(ax, Rect(i + 0.02, 0, bar_w, lf[i]),
            color = (colors[i], 0.9))
    end
end

Legend(fig[4, 3],
    [PolyElement(color = (:gray55, 0.8)), PolyElement(color = (:crimson, 0.9))],
    ["Early (1–5)", "Late (16–20)"],
    framevisible = false)

save("pkg_analysis.png", fig, px_per_unit = 3)
println("Saved pkg_analysis.png")

# --- Print stats ---
println("\n--- P(response) stimulus 1 ---")
println("  Water: $(round(rw.total[1], digits=3))  (n=$(rw.ns[1]))")
println("  PKG:   $(round(rp.total[1], digits=3))  (n=$(rp.ns[1]))")
println("  800fc 30s (main): $(round(rc.total[1], digits=3))  (n=$(rc.ns[1]))")

println("\n--- P(response) stimulus 20 ---")
println("  Water: $(round(rw.total[end], digits=3))")
println("  PKG:   $(round(rp.total[end], digits=3))")

println("\n--- Mean subtype rates (all 20 stim) ---")
println("         ", join(lpad.(labels, 12)))
print("  Water: ")
println(join([lpad(round(water_means[i], digits=3), 12) for i in 1:4]))
print("  PKG:   ")
println(join([lpad(round(pkg_means[i], digits=3), 12) for i in 1:4]))

println("\n--- Early vs late subtype rates ---")
for (cond_sub, name) in [(water, "Water"), (pkg, "PKG")]
    ef = subtype_fracs(subset(cond_sub, :stimulus => x -> x .<= 5))
    lf = subtype_fracs(subset(cond_sub, :stimulus => x -> x .>= 16))
    println("  $name early: ", join(["$(labels[i])=$(round(ef[i], digits=3))" for i in 1:4], ", "))
    println("  $name late:  ", join(["$(labels[i])=$(round(lf[i], digits=3))" for i in 1:4], ", "))
end
