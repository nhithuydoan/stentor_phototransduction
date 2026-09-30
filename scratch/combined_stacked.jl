using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

# --- Load both datasets ---
df_hab = CSV.read("../data/light_hab0805.csv", DataFrame)
df_hab = subset(df_hab, :response => x -> .!isnan.(x))

df_pkg = CSV.read("../data/PKG_0803.csv", DataFrame)
df_pkg = subset(df_pkg, :response => x -> .!isnan.(x))

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]

groups = [(1,5), (6,10), (11,15), (16,20)]
group_labels = ["1–5", "6–10", "11–15", "16–20"]

pastel    = [(:steelblue, 0.4), (:mediumpurple, 0.4), (:orange, 0.4), (:crimson, 0.4)]
saturated = [(:steelblue, 0.9), (:mediumpurple, 0.9), (:orange, 0.9), (:crimson, 0.9)]

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

hab_t1 = grouped_subtype_rates(subset(df_hab, :trial => x -> x .== 1), groups)
hab_t2 = grouped_subtype_rates(subset(df_hab, :trial => x -> x .== 2), groups)
pkg_w  = grouped_subtype_rates(subset(df_pkg, :condition => x -> x .== "water"), groups)
pkg_p  = grouped_subtype_rates(subset(df_pkg, :condition => x -> x .== "PKG"), groups)

n_hab = length(unique(zip(
    subset(df_hab, :trial => x -> x .== 1).fold_name,
    subset(df_hab, :trial => x -> x .== 1).cell_number)))
n_pkg = length(unique(zip(
    subset(df_pkg, :condition => x -> x .== "water").fold_name,
    subset(df_pkg, :condition => x -> x .== "water").cell_number)))

function draw_stacked_bars!(ax, left_rates, right_rates, bar_w, left_colors, right_colors)
    offset_l = -bar_w/2 - 0.02
    offset_r =  bar_w/2 + 0.02

    for gi in 1:4
        local bottom = 0.0
        for si in 1:4
            h = left_rates[si][gi]
            poly!(ax, Rect(gi + offset_l - bar_w/2, bottom, bar_w, h),
                color = left_colors[si])
            bottom += h
        end

        bottom = 0.0
        for si in 1:4
            h = right_rates[si][gi]
            poly!(ax, Rect(gi + offset_r - bar_w/2, bottom, bar_w, h),
                color = right_colors[si])
            bottom += h
        end
    end
end

# --- Figure ---
fig = Figure(size = (1100, 450), fontsize = 13)

# Left panel: Light habituation Trial 1 vs Trial 2
ax1 = Axis(fig[1, 1],
    xlabel = "Stimulus group",
    ylabel = "P(response)",
    title  = "Light habituation (n = $n_hab cells/trial, ITI = 40 min)",
    xticks = (1:4, group_labels),
    ylabelvisible = true)

draw_stacked_bars!(ax1, hab_t1, hab_t2, 0.35, pastel, saturated)

Legend(fig[1, 2],
    [PolyElement(color = (:gray50, 0.4)), PolyElement(color = (:gray50, 0.9))],
    ["Trial 1", "Trial 2"],
    framevisible = false)

# Right panel: Water vs PKG
ax2 = Axis(fig[1, 3],
    xlabel = "Stimulus group",
    ylabel = "P(response)",
    title  = "PKG inhibition (n = $n_pkg cells/condition)",
    xticks = (1:4, group_labels),
    ylabelvisible = true)

draw_stacked_bars!(ax2, pkg_w, pkg_p, 0.35, pastel, saturated)

Legend(fig[1, 4],
    [PolyElement(color = (:gray50, 0.4)), PolyElement(color = (:gray50, 0.9))],
    ["Water", "PKG"],
    framevisible = false)

# shared y limits
linkyaxes!(ax1, ax2)

# shared subtype legend at bottom
subtype_elems = [PolyElement(color = (colors[i], 0.7)) for i in eachindex(subtypes)]
Legend(fig[2, 1:4], subtype_elems, labels,
    orientation = :horizontal, framevisible = false, tellheight = true)

save("combined_stacked.png", fig, px_per_unit = 3)
println("Saved combined_stacked.png")
