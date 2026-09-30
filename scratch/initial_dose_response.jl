using CSV, DataFrames, Plots, Statistics

df = CSV.read("../data/light_variation0814.csv", DataFrame)

initial = filter(r -> r.stimulus == 1 && r.trial == 1 && !isnan(r.response), df)

initial.intensity = first.(split.(initial.condition))
initial.duration = parse.(Int, replace.(last.(split.(initial.condition)), "s" => ""))

intensities = ["300fc", "500fc", "800fc"]
durations = [10, 15, 20, 30]
colors = Dict("300fc" => :blue, "500fc" => :purple, "800fc" => :green)
labels = Dict("300fc" => "300 fc", "500fc" => "500 fc", "800fc" => "800 fc")

p = plot(xlabel="Stimulus duration (s)", ylabel="P(response)",
         title="Initial Dose-Response (Stimulus 1, Trial 1)",
         ylims=(-0.05, 1.05), xticks=durations, legend=:bottomright,
         size=(600, 450), framestyle=:semi, grid=false, foreground_color_legend=nothing)

for intensity in intensities
    rates = Float64[]
    ci = Float64[]
    ns = Int[]
    for dur in durations
        sub = filter(r -> r.intensity == intensity && r.duration == dur, initial)
        n = nrow(sub)
        k = sum(sub.response)
        prob = k / n
        se = sqrt(prob * (1 - prob) / n)
        push!(rates, prob)
        push!(ci, 1.96 * se)
        push!(ns, n)
    end
    plot!(p, durations, rates, ribbon=ci, marker=:circle, markersize=5,
          label=labels[intensity], color=colors[intensity], linewidth=1.5, fillalpha=0.15)
    for (d, r, n) in zip(durations, rates, ns)
        annotate!(p, d + 0.8, r - 0.03, text("n=$n", 7, colors[intensity]))
    end
end

savefig(p, "initial_dose_response.png")
println("Saved to scratch/initial_dose_response.png")
