using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../data/PKG_0803.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x))

water = subset(df, :condition => x -> x .== "water")
pkg   = subset(df, :condition => x -> x .== "PKG")

groups = [(1,5), (6,10), (11,15), (16,20)]
group_labels = ["1–5", "6–10", "11–15", "16–20"]

function grouped_response(sub, groups)
    rates = Float64[]
    ses   = Float64[]
    for (lo, hi) in groups
        rows = subset(sub, :stimulus => x -> x .>= lo .&& x .<= hi)
        p = mean(rows.response)
        n = nrow(rows)
        push!(rates, p)
        push!(ses, sqrt(p * (1 - p) / n))
    end
    return rates, ses
end

wr, wse = grouped_response(water, groups)
pr, pse = grouped_response(pkg, groups)

fig = Figure(size = (600, 450), fontsize = 14)
ax = Axis(fig[1, 1],
    xlabel = "Stimulus group",
    ylabel = "P(response)",
    title  = "Response rate by stimulus group: Water vs PKG",
    xticks = (1:4, group_labels))

xs = collect(1:4)

band!(ax, xs .- 0.01, wr .- wse, wr .+ wse, color = (:black, 0.1))
lines!(ax, xs, wr, color = :black, linewidth = 2)
scatter!(ax, xs, wr, color = :black, markersize = 10, label = "Water")

band!(ax, xs .+ 0.01, pr .- pse, pr .+ pse, color = (:red, 0.1))
lines!(ax, xs, pr, color = :red, linewidth = 2)
scatter!(ax, xs, pr, color = :red, markersize = 10, label = "PKG")

axislegend(ax, position = :rt, framevisible = false)

save("pkg_grouped_response.png", fig, px_per_unit = 3)
println("Saved pkg_grouped_response.png")

println("\n--- Grouped P(response) ± SE ---")
for (i, gl) in enumerate(group_labels)
    println("  $gl:  Water=$(round(wr[i], digits=3))±$(round(wse[i], digits=3))   PKG=$(round(pr[i], digits=3))±$(round(pse[i], digits=3))")
end
