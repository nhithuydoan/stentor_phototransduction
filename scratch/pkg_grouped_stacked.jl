using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../data/PKG_0803.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x))

water = subset(df, :condition => x -> x .== "water")
pkg   = subset(df, :condition => x -> x .== "PKG")

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]

# water = pastel, PKG = saturated
water_colors = [(:steelblue, 0.4), (:mediumpurple, 0.4), (:orange, 0.4), (:crimson, 0.4)]
pkg_colors   = [(:steelblue, 0.9), (:mediumpurple, 0.9), (:orange, 0.9), (:crimson, 0.9)]

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

wr = grouped_subtype_rates(water, groups)
pr = grouped_subtype_rates(pkg, groups)

fig = Figure(size = (700, 450), fontsize = 14)
ax = Axis(fig[1, 1],
    xlabel = "Stimulus group",
    ylabel = "P(response)",
    title  = "Response composition: Water vs PKG",
    xticks = (1:4, group_labels))

bar_w = 0.35
offset_w = -bar_w/2 - 0.02
offset_p =  bar_w/2 + 0.02

for gi in 1:4
    # water bar (left)
    local bottom = 0.0
    for si in 1:4
        h = wr[si][gi]
        poly!(ax, Rect(gi + offset_w - bar_w/2, bottom, bar_w, h),
            color = water_colors[si])
        bottom += h
    end

    # PKG bar (right)
    bottom = 0.0
    for si in 1:4
        h = pr[si][gi]
        poly!(ax, Rect(gi + offset_p - bar_w/2, bottom, bar_w, h),
            color = pkg_colors[si])
        bottom += h
    end
end

# legend
leg_elems = Vector{Any}()
leg_labels = String[]

for i in 1:4
    push!(leg_elems, [PolyElement(color = water_colors[i]), PolyElement(color = pkg_colors[i])])
    push!(leg_labels, labels[i])
end

# condition markers
push!(leg_elems, PolyElement(color = (:gray50, 0.4)))
push!(leg_labels, "Water")
push!(leg_elems, PolyElement(color = (:gray50, 0.9)))
push!(leg_labels, "PKG")

Legend(fig[1, 2], leg_elems, leg_labels, framevisible = false)

save("pkg_grouped_stacked.png", fig, px_per_unit = 3)
println("Saved pkg_grouped_stacked.png")
