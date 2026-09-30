using CSV, DataFrames, Plots, Statistics

df = CSV.read("../data/light_variation0814.csv", DataFrame)

hab = filter(r -> r.trial == 1 && !isnan(r.response), df)

hab.intensity = first.(split.(hab.condition))
hab.duration = parse.(Int, replace.(last.(split.(hab.condition)), "s" => ""))

intensities = ["300fc", "500fc", "800fc"]
durations = [10, 15, 20, 30]
intensity_colors = Dict("300fc" => :blue, "500fc" => :purple, "800fc" => :green)
dur_styles = Dict(10 => :solid, 15 => :dash, 20 => :dashdot, 30 => :dot)

subtypes = [:bend, :shorten, :partial_contract, :contract]
subtype_labels = ["Bend", "Shorten", "Partial contract", "Contract"]
subtype_colors = [:steelblue, :mediumpurple, :orange, :crimson]
subtype_styles = [:solid, :dash, :dashdot, :dot]

function compute_rates(sub)
    total = zeros(20)
    se = zeros(20)
    sub_rates = zeros(20, 4)
    ns = zeros(Int, 20)
    for s in 1:20
        rows = filter(r -> r.stimulus == s, sub)
        n = nrow(rows)
        ns[s] = n
        if n > 0
            p = mean(rows.response)
            total[s] = p
            se[s] = sqrt(p * (1 - p) / n)
            for (j, st) in enumerate(subtypes)
                sub_rates[s, j] = sum(rows[!, st]) / n
            end
        end
    end
    return total, se, sub_rates, ns
end

# --- Row 1: Panels C-E, grouped by duration ---
pCE = []
for (ci, dur) in enumerate([10, 15, 20, 30])
    p = plot(title="Duration $(dur)s",
             ylims=(-0.02, 1.0), xlims=(0.5, 20.5), xticks=[1, 5, 10, 15, 20],
             framestyle=:semi, grid=false,
             ylabel=ci == 1 ? "P(response)" : "",
             xlabel="", legend=false, titlefontsize=10)
    for intensity in intensities
        sub = filter(r -> r.intensity == intensity && r.duration == dur, hab)
        total, ses, _, ns = compute_rates(sub)
        col = intensity_colors[intensity]
        plot!(p, 1:20, total, ribbon=ses, color=col, fillalpha=0.15,
              linewidth=2, marker=:circle, markersize=3,
              label="$(intensity) (n=$(ns[1]))")
    end
    plot!(p, legend=:topright, foreground_color_legend=nothing, legendfontsize=7)
    push!(pCE, p)
end

# --- Row 2: Panels F-H, grouped by intensity ---
pFH = []
for (ri, intensity) in enumerate(intensities)
    p = plot(title="$(intensity)",
             ylims=(-0.02, 1.0), xlims=(0.5, 20.5), xticks=[1, 5, 10, 15, 20],
             framestyle=:semi, grid=false,
             ylabel=ri == 1 ? "P(response)" : "",
             xlabel="Stimulus number", legend=false, titlefontsize=10)
    for dur in durations
        sub = filter(r -> r.intensity == intensity && r.duration == dur, hab)
        total, ses, _, ns = compute_rates(sub)
        plot!(p, 1:20, total, ribbon=ses, color=:black, fillalpha=0.1,
              linewidth=1.5, linestyle=dur_styles[dur], marker=:circle, markersize=2,
              label="$(dur)s (n=$(ns[1]))")
    end
    plot!(p, legend=:topright, foreground_color_legend=nothing, legendfontsize=7)
    push!(pFH, p)
end

# --- Row 3: P(subtype | responded), one panel per intensity, all durations pooled ---
function compute_conditional_rates(sub)
    cond_rates = zeros(20, 4)
    n_resp = zeros(Int, 20)
    for s in 1:20
        rows = filter(r -> r.stimulus == s, sub)
        responders = filter(r -> r.response == 1.0, rows)
        n = nrow(responders)
        n_resp[s] = n
        if n > 0
            for (j, st) in enumerate(subtypes)
                cond_rates[s, j] = sum(responders[!, st]) / n
            end
        end
    end
    return cond_rates, n_resp
end

# --- Row 3: Stacked bars of raw P(subtype), normalized so stimulus 1 total = 1.0 ---
pSub = []
for (ri, intensity) in enumerate(intensities)
    sub = filter(r -> r.intensity == intensity, hab)
    _, _, sub_rates, ns = compute_rates(sub)

    total_s1 = sum(sub_rates[1, :])
    norm_rates = total_s1 > 0 ? sub_rates ./ total_s1 : sub_rates
    cumrates = cumsum(norm_rates, dims=2)

    p = plot(title="$(intensity)",
             ylims=(-0.02, 1.15), xlims=(0.25, 20.75), xticks=[1, 5, 10, 15, 20],
             framestyle=:semi, grid=false,
             ylabel=ri == 1 ? "Fraction of initial response" : "",
             xlabel="Stimulus number", legend=false, titlefontsize=10)

    for j in reverse(1:4)
        bottom = j == 1 ? zeros(20) : cumrates[:, j-1]
        bar!(p, 1:20, cumrates[:, j], fillrange=bottom,
             bar_width=0.8, color=subtype_colors[j], linecolor=:white, linewidth=0.5,
             label=subtype_labels[j])
    end

    plot!(p, legend=:right, foreground_color_legend=nothing, legendfontsize=7)
    annotate!(p, 15, 1.08, text("n=$(ns[1])", 7, :gray40))
    push!(pSub, p)
end

l = @layout [a b c d; e f g _; h i j _]
fig = plot(pCE..., pFH..., pSub...,
           layout=l, size=(1000, 750),
           left_margin=5Plots.mm, bottom_margin=4Plots.mm, top_margin=2Plots.mm)

savefig(fig, "habituation_subtypes.png")
println("Saved to scratch/habituation_subtypes.png")

# Top row only as 2x2
fig_top = plot(pCE..., layout=(2, 2), size=(650, 500),
               left_margin=5Plots.mm, bottom_margin=5Plots.mm, top_margin=2Plots.mm)
savefig(fig_top, "habituation_by_duration.png")
println("Saved to scratch/habituation_by_duration.png")

# Row 2 as 2x2 (3 panels + blank)
fig_int = plot(pFH..., plot(framestyle=:none, grid=false, legend=false),
               layout=(2, 2), size=(650, 500),
               left_margin=5Plots.mm, bottom_margin=5Plots.mm, top_margin=2Plots.mm)
savefig(fig_int, "habituation_by_intensity.png")
println("Saved to scratch/habituation_by_intensity.png")

# Row 3 as 2x2
fig_sub = plot(pSub..., plot(framestyle=:none, grid=false, legend=false),
               layout=(2, 2), size=(650, 500),
               left_margin=5Plots.mm, bottom_margin=5Plots.mm, top_margin=2Plots.mm)
savefig(fig_sub, "habituation_conditional_subtypes.png")
println("Saved to scratch/habituation_conditional_subtypes.png")
