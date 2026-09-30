using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../data/light_variation0814.csv", DataFrame)
sub = subset(df, :trial => x -> x .== 1, :response => x -> .!isnan.(x))
sub = subset(sub, :condition => x -> x .== "800fc 30s")

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "Partial contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]

stimuli = 1:20
n_stim  = length(stimuli)

# --- compute rates per stimulus ---
rates = Dict(s => Float64[] for s in subtypes)
total_rate = Float64[]
ns = Int[]

for s in stimuli
    rows = subset(sub, :stimulus => x -> x .== s)
    n = nrow(rows)
    push!(ns, n)
    push!(total_rate, mean(rows.response))
    for st in subtypes
        push!(rates[st], sum(rows[!, st]) / n)
    end
end

# --- Figure: 3 panels ---
fig = Figure(size = (1000, 900), fontsize = 13)

# Panel A: stacked area — absolute P(subtype) across stimuli
ax1 = Axis(fig[1, 1],
    xlabel = "Stimulus number",
    ylabel = "P(subtype)",
    title  = "800 fc, 30 s — Subtype rates across stimuli",
    xticks = 1:20)

# build cumulative bands for stacking
let cumlow = zeros(n_stim)
    for (i, st) in enumerate(subtypes)
        cumhigh = cumlow .+ rates[st]
        band!(ax1, collect(stimuli), cumlow, cumhigh, color = (colors[i], 0.7))
        cumlow = cumhigh
    end
end

# overlay total response line
lines!(ax1, collect(stimuli), total_rate, color = :black, linewidth = 2,
    linestyle = :dash, label = "P(response)")

# legend entries
poly_elems = [PolyElement(color = (colors[i], 0.7)) for i in eachindex(subtypes)]
line_elem  = [LineElement(color = :black, linewidth = 2, linestyle = :dash)]
Legend(fig[1, 2],
    [poly_elems; line_elem],
    [labels; "P(response)"],
    framevisible = false)

# Panel B: individual subtype curves with SE
ax2 = Axis(fig[2, 1],
    xlabel = "Stimulus number",
    ylabel = "P(subtype)",
    title  = "Individual subtype trajectories",
    xticks = 1:20)

for (i, st) in enumerate(subtypes)
    r = rates[st]
    se = @. sqrt(r * (1 - r) / ns)
    band!(ax2, collect(stimuli), r .- se, r .+ se, color = (colors[i], 0.2))
    lines!(ax2, collect(stimuli), r, color = colors[i], linewidth = 2, label = labels[i])
end

axislegend(ax2, position = :rt, framevisible = false)

# Panel C: normalized to stimulus 1 — fold-change in each subtype
ax3 = Axis(fig[3, 1],
    xlabel = "Stimulus number",
    ylabel = "Rate / rate at stimulus 1",
    title  = "Relative decline (normalized to stimulus 1)",
    xticks = 1:20)

hlines!(ax3, [1.0], color = :gray70, linestyle = :dash, linewidth = 1)

for (i, st) in enumerate(subtypes)
    r = rates[st]
    r0 = r[1]
    if r0 > 0
        normed = r ./ r0
        lines!(ax3, collect(stimuli), normed, color = colors[i], linewidth = 2, label = labels[i])
        scatter!(ax3, collect(stimuli), normed, color = colors[i], markersize = 5)
    end
end

# also show total response normalized
lines!(ax3, collect(stimuli), total_rate ./ total_rate[1],
    color = :black, linewidth = 2, linestyle = :dash, label = "P(response)")

axislegend(ax3, position = :rt, framevisible = false)

save("subtype_dynamics_800fc30s.png", fig, px_per_unit = 3)
println("Saved subtype_dynamics_800fc30s.png")
println("\n--- Rates at stimulus 1 vs 20 ---")
for (i, st) in enumerate(subtypes)
    r1, r20 = rates[st][1], rates[st][end]
    pct = r1 > 0 ? round((1 - r20/r1) * 100, digits=1) : NaN
    println("  $(labels[i]): $(round(r1, digits=3)) → $(round(r20, digits=3))  ($(pct)% decline)")
end
r1, r20 = total_rate[1], total_rate[end]
println("  Total:    $(round(r1, digits=3)) → $(round(r20, digits=3))  ($(round((1-r20/r1)*100, digits=1))% decline)")
println("\n--- Sample sizes ---")
println("  n per stimulus: $(ns[1]) – $(ns[end])")
