using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df_main = CSV.read("../../data/light_variation0814.csv", DataFrame)
df_main = subset(df_main, :response => x -> .!isnan.(x),
                 :trial => x -> x .== 1,
                 :light_level => x -> x .== 13080,
                 :light_duration => x -> x .== 30)

df_pkg = CSV.read("../../data/PKG_0803.csv", DataFrame)
df_pkg = subset(df_pkg, :response => x -> .!isnan.(x))

df_hab = CSV.read("../../data/light_hab0805.csv", DataFrame)
df_hab = subset(df_hab, :response => x -> .!isnan.(x))

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]

function conditional_rates(sub, stim_lo, stim_hi)
    rows = subset(sub, :stimulus => x -> x .>= stim_lo .&& x .<= stim_hi)
    resp = subset(rows, :response => x -> x .== 1.0)
    n_total = nrow(rows)
    n_resp  = nrow(resp)
    p_resp  = n_resp / n_total

    cond = Float64[]
    for st in subtypes
        push!(cond, n_resp > 0 ? sum(resp[!, st]) / n_resp : 0.0)
    end
    return cond, p_resp, n_resp, n_total
end

# --- Compute conditional distributions for all conditions ---
water = subset(df_pkg, :condition => x -> x .== "water")
pkg   = subset(df_pkg, :condition => x -> x .== "PKG")
hab_t1 = subset(df_hab, :trial => x -> x .== 1)
hab_t2 = subset(df_hab, :trial => x -> x .== 2)

conditions = [
    ("800fc 30s\nearly (1–5)",    df_main, 1, 5),
    ("800fc 30s\nlate (16–20)",   df_main, 16, 20),
    ("Water\nearly (1–5)",        water, 1, 5),
    ("Water\nlate (16–20)",       water, 16, 20),
    ("PKG\nearly (1–5)",          pkg, 1, 5),
    ("PKG\nlate (16–20)",         pkg, 16, 20),
    ("Trial 1\nearly (1–5)",      hab_t1, 1, 5),
    ("Trial 1\nlate (16–20)",     hab_t1, 16, 20),
    ("Trial 2\nearly (1–5)",      hab_t2, 1, 5),
    ("Trial 2\nlate (16–20)",     hab_t2, 16, 20),
]

cond_data = []
for (name, sub, lo, hi) in conditions
    cond, p_resp, n_resp, n_total = conditional_rates(sub, lo, hi)
    push!(cond_data, (; name, cond, p_resp, n_resp, n_total))
end

# --- Figure 1: Full comparison ---
fig = Figure(size = (1400, 900), fontsize = 13)

ax1 = Axis(fig[1, 1:3],
    title = "P(subtype | responded) — comparing baselines, habituation, and PKG",
    xlabel = "",
    ylabel = "Fraction of responders",
    xticks = (1:10, [c.name for c in cond_data]),
    xticklabelrotation = π/5)

bar_w = 0.6
for (ci, cd) in enumerate(cond_data)
    local bottom = 0.0
    for si in 1:4
        h = cd.cond[si]
        poly!(ax1, Rect(ci - bar_w/2, bottom, bar_w, h), color = (colors[si], 0.8))
        if h > 0.04
            text!(ax1, ci, bottom + h/2,
                text = "$(round(Int, h*100))%",
                align = (:center, :center), fontsize = 9, color = :white)
        end
        bottom += h
    end
    text!(ax1, ci, -0.06,
        text = "P(r)=$(round(cd.p_resp, digits=2))\nn=$(cd.n_resp)",
        align = (:center, :top), fontsize = 8, color = :gray40)
end

# Vertical separators between experiment groups
vlines!(ax1, [2.5, 6.5], color = :black, linewidth = 1.5)
vlines!(ax1, [4.5, 8.5], color = :gray70, linewidth = 1, linestyle = :dash)

# Group labels
text!(ax1, 1.5, 1.08, text = "Main expt", align = (:center, :bottom), fontsize = 11, font = :bold)
text!(ax1, 4.5, 1.08, text = "PKG expt", align = (:center, :bottom), fontsize = 11, font = :bold)
text!(ax1, 8.5, 1.08, text = "Habituation expt", align = (:center, :bottom), fontsize = 11, font = :bold)

leg_elems = [PolyElement(color = (colors[i], 0.8)) for i in 1:4]
Legend(fig[1, 4], leg_elems, labels, framevisible = false)

# --- Figure 2: Focused comparison — early baselines vs "habituated" conditions ---
# Compare the conditional profiles of:
# - Water early (baseline)
# - PKG early (drug effect on naive cells)
# - Trial 1 late (behaviorally habituated)
# - Trial 2 early (recovered after habituation)

focus = [
    ("Water\nearly", cond_data[3]),
    ("PKG\nearly", cond_data[5]),
    ("T1 late\n(habituated)", cond_data[8]),
    ("T2 early\n(recovered)", cond_data[9]),
]

ax2 = Axis(fig[2, 1:2],
    title = "Focused: Does PKG mimic the habituation conditional profile?",
    xlabel = "",
    ylabel = "Fraction of responders",
    xticks = (1:4, [f[1] for f in focus]))

for (ci, (name, cd)) in enumerate(focus)
    local bottom = 0.0
    for si in 1:4
        h = cd.cond[si]
        poly!(ax2, Rect(ci - bar_w/2, bottom, bar_w, h), color = (colors[si], 0.8))
        if h > 0.04
            text!(ax2, ci, bottom + h/2,
                text = "$(round(Int, h*100))%",
                align = (:center, :center), fontsize = 10, color = :white)
        end
        bottom += h
    end
    text!(ax2, ci, -0.06,
        text = "P(r)=$(round(cd.p_resp, digits=2)), n=$(cd.n_resp)",
        align = (:center, :top), fontsize = 9, color = :gray40)
end

vlines!(ax2, [2.5], color = :black, linewidth = 1.5)
text!(ax2, 1.5, 1.05, text = "Drug effect", align = (:center, :bottom), fontsize = 11, font = :bold)
text!(ax2, 3.5, 1.05, text = "Behavioral", align = (:center, :bottom), fontsize = 11, font = :bold)

# --- Panel: P(contract | responded) bar comparison ---
ax3 = Axis(fig[2, 3],
    title = "P(contract | responded)",
    xlabel = "",
    ylabel = "P(contract | responded)",
    xticks = (1:4, ["Water\nearly", "PKG\nearly", "T1\nlate", "T2\nearly"]))

p_contract = [f[2].cond[4] for f in focus]
bar_colors = [:gray50, :royalblue, :crimson, :darkorange]
for i in 1:4
    barplot!(ax3, [i], [p_contract[i]], color = bar_colors[i])
    text!(ax3, i, p_contract[i] + 0.01,
        text = "$(round(Int, p_contract[i]*100))%",
        align = (:center, :bottom), fontsize = 11)
end

save("pkg_vs_habituation_conditional.png", fig, px_per_unit = 3)
println("Saved pkg_vs_habituation_conditional.png")

# --- Stats ---
println("\n=== Conditional subtype distributions ===")
for cd in cond_data
    vals = join(["$(labels[i])=$(round(Int, cd.cond[i]*100))%" for i in 1:4], "  ")
    println("  $(replace(cd.name, '\n' => ' ')): $vals  [P(r)=$(round(cd.p_resp, digits=3)), n_resp=$(cd.n_resp)]")
end

println("\n=== Key comparison: P(contract | responded) ===")
println("  Water early:     $(round(Int, cond_data[3].cond[4]*100))%")
println("  PKG early:       $(round(Int, cond_data[5].cond[4]*100))%")
println("  Trial 1 late:    $(round(Int, cond_data[8].cond[4]*100))%")
println("  Trial 2 early:   $(round(Int, cond_data[9].cond[4]*100))%")

println("\n=== P(bend+shorten | responded) — sensory stage intact? ===")
for (name, cd) in focus
    low = cd.cond[1] + cd.cond[2]
    println("  $(replace(name, '\n' => ' ')): $(round(Int, low*100))%")
end
