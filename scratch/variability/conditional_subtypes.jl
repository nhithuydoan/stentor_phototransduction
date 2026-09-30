using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../../data/light_variation0814.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x),
            :trial => x -> x .== 1,
            :light_level => x -> x .== 13080,
            :light_duration => x -> x .== 30)

df_pkg = CSV.read("../../data/PKG_0803.csv", DataFrame)
df_pkg = subset(df_pkg, :response => x -> .!isnan.(x))

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]
stimuli  = 1:20

n_cells = length(unique(collect(zip(df.fold_name, df.cell_number))))

# --- Panel A: Conditional subtype fractions per stimulus (800fc 30s) ---
cond_frac = zeros(4, 20)  # subtypes × stimuli
p_resp    = Float64[]
n_resp    = Int[]

for s in stimuli
    rows = subset(df, :stimulus => x -> x .== s)
    resp = subset(rows, :response => x -> x .== 1.0)
    push!(p_resp, mean(rows.response))
    push!(n_resp, nrow(resp))
    if nrow(resp) > 0
        for (i, st) in enumerate(subtypes)
            cond_frac[i, s] = sum(resp[!, st]) / nrow(resp)
        end
    end
end

# --- Panel B: P(contract | responded) with SE ---
p_contract_given_resp = Float64[]
se_contract = Float64[]
for s in stimuli
    rows = subset(df, :stimulus => x -> x .== s)
    resp = subset(rows, :response => x -> x .== 1.0)
    nr = nrow(resp)
    if nr > 0
        p = sum(resp.contract) / nr
        push!(p_contract_given_resp, p)
        push!(se_contract, sqrt(p * (1 - p) / nr))
    else
        push!(p_contract_given_resp, NaN)
        push!(se_contract, 0.0)
    end
end

# --- Panel C: PKG conditional subtypes by stimulus group ---
groups = [(1,5), (6,10), (11,15), (16,20)]
group_labels = ["1–5", "6–10", "11–15", "16–20"]

function conditional_grouped(sub, groups)
    fracs = zeros(4, 4)  # subtypes × groups
    for (gi, (lo, hi)) in enumerate(groups)
        rows = subset(sub, :stimulus => x -> x .>= lo .&& x .<= hi)
        resp = subset(rows, :response => x -> x .== 1.0)
        if nrow(resp) > 0
            for (i, st) in enumerate(subtypes)
                fracs[i, gi] = sum(resp[!, st]) / nrow(resp)
            end
        end
    end
    return fracs
end

water = subset(df_pkg, :condition => x -> x .== "water")
pkg   = subset(df_pkg, :condition => x -> x .== "PKG")
cond_water = conditional_grouped(water, groups)
cond_pkg   = conditional_grouped(pkg, groups)

# Also compute for 800fc 30s main data
cond_main  = conditional_grouped(df, groups)

# --- Figure ---
fig = Figure(size = (1400, 1000), fontsize = 13)

# Panel A: Stacked bars of conditional subtype fractions
ax1 = Axis(fig[1, 1:2],
    title = "A. P(subtype | responded) across stimuli — 800fc 30s (n=$n_cells cells)",
    xlabel = "Stimulus number",
    ylabel = "Fraction of responders",
    xticks = 1:20)

bar_w = 0.7
for s in 1:20
    local bottom = 0.0
    for si in 1:4
        h = cond_frac[si, s]
        poly!(ax1, Rect(s - bar_w/2, bottom, bar_w, h), color = (colors[si], 0.8))
        bottom += h
    end
end

text!(ax1, 1, -0.08, text = "n responding:", fontsize = 9, color = :gray40, align = (:left, :top))
for s in 1:20
    text!(ax1, s, -0.04, text = "$(n_resp[s])", fontsize = 8, color = :gray50,
        align = (:center, :top))
end

leg_elems = [PolyElement(color = (colors[i], 0.8)) for i in 1:4]
Legend(fig[1, 3], leg_elems, labels, framevisible = false)

# Panel B: P(contract | responded) line + P(response) context
ax2 = Axis(fig[2, 1],
    title = "B. P(contract | responded) vs P(response)",
    xlabel = "Stimulus number",
    ylabel = "Probability",
    xticks = [1, 5, 10, 15, 20])

xs = collect(stimuli)
band!(ax2, xs,
    p_contract_given_resp .- se_contract,
    p_contract_given_resp .+ se_contract,
    color = (:crimson, 0.15))
lines!(ax2, xs, p_contract_given_resp, color = :crimson, linewidth = 2)
scatter!(ax2, xs, p_contract_given_resp, color = :crimson, markersize = 6)

lines!(ax2, xs, p_resp, color = :gray40, linewidth = 2, linestyle = :dash)
scatter!(ax2, xs, p_resp, color = :gray40, markersize = 6)

Legend(fig[2, 2],
    [LineElement(color = :crimson, linewidth = 2),
     LineElement(color = :gray40, linewidth = 2, linestyle = :dash)],
    ["P(contract | responded)", "P(response)"],
    framevisible = false, labelsize = 11)

# Also compute P(bend | responded) and P(shorten | responded)
ax2b = Axis(fig[2, 3],
    title = "B2. All P(subtype | responded)",
    xlabel = "Stimulus number",
    ylabel = "P(subtype | responded)",
    xticks = [1, 5, 10, 15, 20])

for si in 1:4
    lines!(ax2b, xs, cond_frac[si, :], color = colors[si], linewidth = 2, label = labels[si])
    scatter!(ax2b, xs, cond_frac[si, :], color = colors[si], markersize = 5)
end
axislegend(ax2b, position = :rt, framevisible = false, labelsize = 10)

# Panel C: PKG comparison — conditional subtypes by group
pastel    = [(:steelblue, 0.4), (:mediumpurple, 0.4), (:orange, 0.4), (:crimson, 0.4)]
saturated = [(:steelblue, 0.9), (:mediumpurple, 0.9), (:orange, 0.9), (:crimson, 0.9)]

function draw_cond_stacked!(ax, left_fracs, right_fracs, left_colors, right_colors)
    bw = 0.35
    off_l = -bw/2 - 0.02
    off_r =  bw/2 + 0.02
    for gi in 1:4
        local bottom = 0.0
        for si in 1:4
            h = left_fracs[si, gi]
            poly!(ax, Rect(gi + off_l - bw/2, bottom, bw, h), color = left_colors[si])
            bottom += h
        end
        bottom = 0.0
        for si in 1:4
            h = right_fracs[si, gi]
            poly!(ax, Rect(gi + off_r - bw/2, bottom, bw, h), color = right_colors[si])
            bottom += h
        end
    end
end

ax3 = Axis(fig[3, 1:2],
    title = "C. P(subtype | responded): Water vs PKG",
    xlabel = "Stimulus group",
    ylabel = "Fraction of responders",
    xticks = (1:4, group_labels))

draw_cond_stacked!(ax3, cond_water, cond_pkg, pastel, saturated)

Legend(fig[3, 3],
    [PolyElement(color = (:gray50, 0.4)), PolyElement(color = (:gray50, 0.9)),
     [PolyElement(color = (colors[i], 0.7)) for i in 1:4]...],
    ["Water", "PKG", labels...],
    framevisible = false)

Label(fig[0, 1:3],
    "Conditional subtype analysis: Where does response variability arise?",
    fontsize = 16, font = :bold)

save("conditional_subtypes.png", fig, px_per_unit = 3)
println("Saved conditional_subtypes.png")

# --- Stats ---
println("\n=== P(contract | responded) by stimulus ===")
for s in stimuli
    println("  Stim $s: $(round(p_contract_given_resp[s], digits=3))  (n_resp=$(n_resp[s]))")
end

println("\n=== Grouped conditional fractions (800fc 30s) ===")
for (gi, gl) in enumerate(group_labels)
    vals = join(["$(labels[i])=$(round(cond_main[i,gi], digits=3))" for i in 1:4], ", ")
    println("  $gl: $vals")
end

println("\n=== Water vs PKG conditional fractions ===")
for (gi, gl) in enumerate(group_labels)
    w = join(["$(round(cond_water[i,gi], digits=2))" for i in 1:4], "/")
    p = join(["$(round(cond_pkg[i,gi], digits=2))" for i in 1:4], "/")
    println("  $gl: Water=[$w]  PKG=[$p]")
end

println("\n=== Key test: Does P(contract|responded) change? ===")
early_p = mean(p_contract_given_resp[1:5])
late_p  = mean(filter(!isnan, p_contract_given_resp[16:20]))
println("  Early (stim 1-5):  $(round(early_p, digits=3))")
println("  Late (stim 16-20): $(round(late_p, digits=3))")
if late_p < early_p
    println("  → Shifts toward lower subtypes: consistent with DOWNSTREAM variability component")
else
    println("  → Stable or increases: consistent with UPSTREAM variability")
end
