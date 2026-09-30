using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../data/PKG_0803.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x))

water = subset(df, :condition => x -> x .== "water")
pkg   = subset(df, :condition => x -> x .== "PKG")

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]

groups = [(1,5), (6,10), (11,15), (16,20)]
group_labels = ["1–5", "6–10", "11–15", "16–20"]

function grouped_subtype_rates(sub, groups)
    rates = Dict(st => Float64[] for st in subtypes)
    for (lo, hi) in groups
        rows = subset(sub, :stimulus => x -> x .>= lo .&& x .<= hi)
        n = nrow(rows)
        for st in subtypes
            push!(rates[st], sum(rows[!, st]) / n)
        end
    end
    return rates
end

wr = grouped_subtype_rates(water, groups)
pr = grouped_subtype_rates(pkg, groups)

fig = Figure(size = (900, 700), fontsize = 13)

for (idx, (st, lbl)) in enumerate(zip(subtypes, labels))
    row = idx <= 2 ? 1 : 2
    col = idx <= 2 ? idx : idx - 2

    ax = Axis(fig[row, col],
        title = lbl,
        xlabel = "Stimulus group",
        ylabel = "P($lbl)",
        xticks = (1:4, group_labels))

    xs = collect(1:4)
    lines!(ax, xs, wr[st], color = :black, linewidth = 2)
    scatter!(ax, xs, wr[st], color = :black, markersize = 10, label = "Water")
    lines!(ax, xs, pr[st], color = colors[idx], linewidth = 2)
    scatter!(ax, xs, pr[st], color = colors[idx], markersize = 10, label = "PKG")

    if idx == 1
        axislegend(ax, position = :rt, framevisible = false)
    end
end

Label(fig[0, 1:2], "Subtype rates by stimulus group: Water vs PKG",
    fontsize = 16, font = :bold)

save("pkg_grouped_subtypes.png", fig, px_per_unit = 3)
println("Saved pkg_grouped_subtypes.png")

println("\n--- Subtype rates by group ---")
for (i, gl) in enumerate(group_labels)
    println("\nGroup $gl:")
    for (j, st) in enumerate(subtypes)
        w = round(wr[st][i], digits=3)
        p = round(pr[st][i], digits=3)
        diff = round(p - w, digits=3)
        println("  $(labels[j]):  Water=$w  PKG=$p  (Δ=$diff)")
    end
end
