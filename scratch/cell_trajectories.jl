using CSV, DataFrames, Plots, Statistics

df = CSV.read("../data/light_variation0814.csv", DataFrame)
sub = filter(r -> r.trial == 1 && r.condition == "800fc 30s" && !isnan(r.response), df)

subtypes = [:bend, :shorten, :partial_contract, :contract]
subtype_names = Dict(:bend => "Bend", :shorten => "Shorten",
                     :partial_contract => "P.contract", :contract => "Contract")
subtype_code = Dict(:bend => 1, :shorten => 2, :partial_contract => 3, :contract => 4)
code_colors = Dict(0 => :gray90, 1 => :steelblue, 2 => :mediumpurple,
                   3 => :orange, 4 => :crimson)
code_labels = Dict(0 => "No response", 1 => "Bend", 2 => "Shorten",
                   3 => "P.contract", 4 => "Contract")

cells = sort(unique(zip(sub.fold_name, sub.cell_number) |> collect))

# Build a matrix: rows = cells, cols = stimuli, values = subtype code (0=no response)
mat = zeros(Int, length(cells), 20)
for (i, (fold, cell)) in enumerate(cells)
    for s in 1:20
        row = filter(r -> r.fold_name == fold && r.cell_number == cell && r.stimulus == s, sub)
        if nrow(row) == 1
            r = row[1, :]
            if r.response == 0.0
                mat[i, s] = 0
            else
                for st in subtypes
                    if r[st] == 1.0
                        mat[i, s] = subtype_code[st]
                        break
                    end
                end
            end
        end
    end
end

# Sort cells by total number of responses (most responsive at top)
resp_count = [count(>(0), mat[i, :]) for i in 1:size(mat, 1)]
order = sortperm(resp_count, rev=true)
mat = mat[order, :]
cells_sorted = cells[order]

# Heatmap-style plot
ncells = size(mat, 1)
p = plot(size=(750, 650), xlabel="Stimulus number", ylabel="Cell (sorted by # responses)",
         title="800fc 30s — Individual Cell Trajectories (n=$ncells)",
         xticks=1:20, yticks=[], framestyle=:semi, grid=false, legend=false)

# Plot legend entries first (hidden points) so they appear in order
for code in [4, 3, 2, 1, 0]
    scatter!(p, [-10], [-10], color=code_colors[code], label=code_labels[code],
             markersize=8, markerstrokewidth=0, marker=:square)
end

# Plot actual data
for i in 1:ncells
    for s in 1:20
        scatter!(p, [s], [i], color=code_colors[mat[i, s]],
                 markersize=4, markerstrokewidth=0, marker=:square, label="")
    end
end

plot!(p, legend=:bottomright, foreground_color_legend=nothing,
     background_color_legend=:white, legendfontsize=8)
plot!(p, ylims=(0, ncells + 1), xlims=(0.5, 20.5))

savefig(p, "cell_trajectories.png")
println("Saved to scratch/cell_trajectories.png")

# Print transition stats
println("\n--- Transition analysis ---")
transitions = Dict{Tuple{Int,Int}, Int}()
for i in 1:size(mat, 1)
    responding = [(s, mat[i, s]) for s in 1:20 if mat[i, s] > 0]
    for k in 1:length(responding)-1
        from = responding[k][2]
        to = responding[k+1][2]
        key = (from, to)
        transitions[key] = get(transitions, key, 0) + 1
    end
end

println("Transitions between consecutive responses (same cell):")
total_trans = sum(values(transitions))
for ((f, t), count) in sort(collect(transitions), by=x -> -x[2])
    fl = code_labels[f]
    tl = code_labels[t]
    println("  $fl → $tl: $count ($(round(count/total_trans*100, digits=1))%)")
end

# How many cells keep the same subtype vs switch?
println("\n--- Cell consistency ---")
for i in 1:size(mat, 1)
    responses = [mat[i, s] for s in 1:20 if mat[i, s] > 0]
    if length(responses) >= 2
        same = all(==(responses[1]), responses)
        types_used = length(unique(responses))
        println("  Cell $(cells_sorted[i]): $(length(responses)) responses, $types_used types used, consistent=$(same)")
    end
end
