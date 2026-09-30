using CSV, DataFrames, Statistics, GLMakie

GLMakie.activate!(visible = false)

df = CSV.read("../../data/light_variation0814.csv", DataFrame)
df = subset(df, :response => x -> .!isnan.(x),
            :trial => x -> x .== 1,
            :light_level => x -> x .== 13080,
            :light_duration => x -> x .== 30)

subtypes = [:bend, :shorten, :partial_contract, :contract]
labels   = ["Bend", "Shorten", "P.contract", "Contract"]
colors   = [:steelblue, :mediumpurple, :orange, :crimson]

function cell_state(row)
    row.response == 0.0 && return 0
    row.contract == 1.0 && return 4
    row.partial_contract == 1.0 && return 3
    row.shorten == 1.0 && return 2
    row.bend == 1.0 && return 1
    return 0
end

df.state = [cell_state(row) for row in eachrow(df)]
df.cell_id = collect(zip(df.fold_name, df.cell_number))
cells = unique(df.cell_id)
n_cells = length(cells)

# --- Per-cell features ---
total_resp    = Float64[]
total_contract = Float64[]
total_bend    = Float64[]
total_shorten = Float64[]
mean_mag      = Float64[]
first_resp    = Int[]      # first stimulus with a response
last_resp     = Int[]      # last stimulus with a response
resp_span     = Float64[]  # how long the cell stays responsive

for c in cells
    crows = sort(subset(df, :cell_id => x -> x .== Ref(c)), :stimulus)
    push!(total_resp, sum(crows.response))
    push!(total_contract, sum(crows.contract))
    push!(total_bend, sum(crows.bend))
    push!(total_shorten, sum(crows.shorten))
    push!(mean_mag, mean(crows.state))

    resp_stim = crows.stimulus[crows.response .== 1.0]
    if length(resp_stim) > 0
        push!(first_resp, minimum(resp_stim))
        push!(last_resp, maximum(resp_stim))
        push!(resp_span, maximum(resp_stim) - minimum(resp_stim) + 1)
    else
        push!(first_resp, 0)
        push!(last_resp, 0)
        push!(resp_span, 0.0)
    end
end

# --- Classify cells into behavioral phenotypes ---
# Based on total responses and dominant subtype
phenotype = String[]
for i in eachindex(cells)
    if total_resp[i] == 0
        push!(phenotype, "Silent")
    elseif total_resp[i] <= 3
        push!(phenotype, "Low responder")
    elseif total_contract[i] >= total_resp[i] * 0.5
        push!(phenotype, "Contractor")
    elseif total_shorten[i] + total_bend[i] >= total_resp[i] * 0.7
        push!(phenotype, "Partial responder")
    else
        push!(phenotype, "Mixed")
    end
end

phen_order = ["Silent", "Low responder", "Partial responder", "Mixed", "Contractor"]
phen_colors = [:gray70, :gray40, :steelblue, :mediumpurple, :crimson]

# --- Figure ---
fig = Figure(size = (1400, 1100), fontsize = 13)

# Panel A: Distribution of total responses per cell
ax1 = Axis(fig[1, 1],
    title = "A. Distribution of total responses (out of 20)",
    xlabel = "Total responses",
    ylabel = "Number of cells")

hist!(ax1, total_resp, bins = 0:1:21, color = (:steelblue, 0.7))
vlines!(ax1, [mean(total_resp)], color = :red, linewidth = 2, linestyle = :dash)
text!(ax1, mean(total_resp) + 0.3, 20,
    text = "mean=$(round(mean(total_resp), digits=1))\nmed=$(round(median(total_resp), digits=1))",
    align = (:left, :center), fontsize = 11, color = :red)

# Panel B: Scatter — total responses vs proportion that are contractions
ax2 = Axis(fig[1, 2],
    title = "B. Response count vs contraction fraction",
    xlabel = "Total responses (out of 20)",
    ylabel = "Fraction that are contractions")

for (pi, pname) in enumerate(phen_order)
    mask = phenotype .== pname
    if sum(mask) > 0
        frac = total_contract[mask] ./ max.(total_resp[mask], 1)
        scatter!(ax2, total_resp[mask] .+ randn(sum(mask)) .* 0.15,
            frac .+ randn(sum(mask)) .* 0.01,
            color = (phen_colors[pi], 0.6), markersize = 7, label = "$pname (n=$(sum(mask)))")
    end
end
axislegend(ax2, position = :rt, framevisible = false, labelsize = 10)

# Panel C: Phenotype composition pie-like bar chart
ax3 = Axis(fig[1, 3],
    title = "C. Cell phenotype distribution (n=$n_cells)",
    xlabel = "",
    ylabel = "Number of cells",
    xticks = (1:5, phen_order),
    xticklabelrotation = π/6)

for (pi, pname) in enumerate(phen_order)
    n = sum(phenotype .== pname)
    barplot!(ax3, [pi], [n], color = phen_colors[pi])
    text!(ax3, pi, n + 0.5, text = "$n\n($(round(Int, n/n_cells*100))%)",
        align = (:center, :bottom), fontsize = 11)
end

# Panel D: Per-cell raster sorted by phenotype, then total responses
order_idx = Int[]
for pname in phen_order
    mask_idx = findall(phenotype .== pname)
    sorted = mask_idx[sortperm(total_resp[mask_idx], rev=true)]
    append!(order_idx, sorted)
end

state_colors = [:gray92, :steelblue, :mediumpurple, :orange, :crimson]

ax4 = Axis(fig[2, 1:2],
    title = "D. Individual cell rasters — sorted by phenotype and activity",
    xlabel = "Stimulus number",
    ylabel = "Cell (sorted)",
    xticks = 1:20)

for (yi, ci) in enumerate(order_idx)
    c = cells[ci]
    crows = sort(subset(df, :cell_id => x -> x .== Ref(c)), :stimulus)
    for row in eachrow(crows)
        v = row.state
        poly!(ax4, Rect(row.stimulus - 0.45, yi - 0.45, 0.9, 0.9),
            color = state_colors[v + 1])
    end
end

# Add phenotype group boundaries
let cumulative = 0
    for (pi, pname) in enumerate(phen_order)
        n = sum(phenotype .== pname)
        if n > 0 && pi < 5
            cumulative += n
            hlines!(ax4, [cumulative + 0.5], color = :black, linewidth = 1)
        end
        mid_y = cumulative - n/2 + (pi < length(phen_order) ? 0 : n)
    end
end

leg_elems = [PolyElement(color = c) for c in state_colors]
Legend(fig[2, 3],
    leg_elems,
    ["No response", labels...],
    framevisible = false)

# Panel E: Mean magnitude trajectory by phenotype
ax5 = Axis(fig[3, 1:2],
    title = "E. Mean magnitude trajectory by phenotype",
    xlabel = "Stimulus number",
    ylabel = "Mean magnitude (0–4)",
    xticks = 1:20)

for (pi, pname) in enumerate(phen_order)
    mask = phenotype .== pname
    phen_cells = cells[mask]
    if length(phen_cells) < 3
        continue
    end

    mag_curve = Float64[]
    se_curve  = Float64[]
    for s in 1:20
        vals = Float64[]
        for c in phen_cells
            crows = subset(df, :cell_id => x -> x .== Ref(c), :stimulus => x -> x .== s)
            if nrow(crows) > 0
                push!(vals, crows.state[1])
            end
        end
        push!(mag_curve, mean(vals))
        push!(se_curve, std(vals) / sqrt(length(vals)))
    end

    xs = collect(1:20)
    band!(ax5, xs, mag_curve .- se_curve, mag_curve .+ se_curve,
        color = (phen_colors[pi], 0.15))
    lines!(ax5, xs, mag_curve, color = phen_colors[pi], linewidth = 2, label = pname)
    scatter!(ax5, xs, mag_curve, color = phen_colors[pi], markersize = 5)
end

axislegend(ax5, position = :rt, framevisible = false, labelsize = 11)

# Panel F: When do cells stop? Distribution of last response stimulus
ax6 = Axis(fig[3, 3],
    title = "F. Last response stimulus",
    xlabel = "Last stimulus with a response",
    ylabel = "Number of cells")

responding_mask = total_resp .> 0
hist!(ax6, last_resp[responding_mask], bins = 0.5:1:20.5, color = (:darkorange, 0.7))

Label(fig[0, 1:3],
    "Cell heterogeneity analysis — 800 fc, 30 s (n=$n_cells cells)",
    fontsize = 16, font = :bold)

save("cell_heterogeneity.png", fig, px_per_unit = 3)
println("Saved cell_heterogeneity.png")

# --- Print stats ---
println("\n=== Phenotype counts ===")
for pname in phen_order
    n = sum(phenotype .== pname)
    println("  $pname: $n ($(round(n/n_cells*100, digits=1))%)")
end

println("\n=== Response statistics ===")
println("  Mean total responses: $(round(mean(total_resp), digits=1)) / 20")
println("  Median: $(round(median(total_resp), digits=1))")
println("  Cells with 0 responses: $(sum(total_resp .== 0))")
println("  Cells with ≥10 responses: $(sum(total_resp .>= 10))")

println("\n=== First/last response ===")
responding = total_resp .> 0
println("  Mean first response stim: $(round(mean(first_resp[responding]), digits=1))")
println("  Mean last response stim:  $(round(mean(last_resp[responding]), digits=1))")
println("  Cells still responding at stim 20: $(sum(last_resp .== 20))")
