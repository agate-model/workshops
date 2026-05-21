# # [Exercise 05: Size range] (@id size_range_exercise)
#
# !!! info
#     This exercise uses [Oceananigans.jl](https://clima.github.io/OceananigansDocumentation/stable/) and [OceanBioME.jl](https://oceanbiome.github.io/OceanBioME.jl/stable/).
#     We recommend familiarizing yourself with their user interface if you intend to make changes to the physical model setup.
#
# This exercise expands the Agate.jl `size_structure.jl` example.
# We change the number of phytoplankton and zooplankton classes, compare generated and explicit size vectors,
# and add plots that summarize the size structure and the resulting community dynamics.

# ## Loading dependencies
#
# The example uses Agate.jl, Oceananigans.jl, and OceanBioME.jl for the ecosystem simulation.
# CairoMakie.jl is used for plotting.

using Agate
using Agate.Introspection: tracer_names
using Agate.Library.Light
using OceanBioME
using OceanBioME: Biogeochemistry
using Oceananigans
using Oceananigans.Units
using CairoMakie
using Statistics

mkpath("outputs")
mkpath("figures")

nothing #hide

# ## Size-structure helpers
#
# Agate.jl accepts either a generated size range,
#
# ```julia
# (n = 3, min_esd = 1.0, max_esd = 10.0, splitting = :log_splitting)
# ```
#
# or an explicit vector of equivalent spherical diameters,
#
# ```julia
# [1.0, 3.2, 10.0]
# ```
#
# The generated form is concise when you want evenly spaced classes.
# The explicit vector is useful when size classes come from observations, another model, or a hand-picked teaching example.

function generated_diameters(spec)
    if spec.splitting == :log_splitting
        return exp.(range(log(spec.min_esd), log(spec.max_esd); length = spec.n))
    elseif spec.splitting == :linear_splitting
        return collect(range(spec.min_esd, spec.max_esd; length = spec.n))
    else
        error("Unknown splitting method: $(spec.splitting)")
    end
end

size_vector(spec::NamedTuple) = generated_diameters(spec)
size_vector(spec::AbstractVector) = collect(spec)

nothing #hide

# ## Three plankton communities
#
# The first community is the same pattern as the package-level size-structure example:
# three logarithmically spaced phytoplankton classes and three explicitly chosen zooplankton classes.
# The second community increases the number of size classes.
# The third community uses explicit sizes for both phytoplankton and zooplankton.

communities = (
    size_structure = (
        title = "Size-structure example",
        phyto_size_structure = (n = 3, min_esd = 1.0, max_esd = 10.0, splitting = :log_splitting),
        zoo_size_structure = [10.0, 32.0, 100.0],
    ),
    more_classes = (
        title = "More classes",
        phyto_size_structure = (n = 5, min_esd = 0.8, max_esd = 20.0, splitting = :log_splitting),
        zoo_size_structure = (n = 4, min_esd = 8.0, max_esd = 160.0, splitting = :log_splitting),
    ),
    explicit_sizes = (
        title = "Explicit sizes",
        phyto_size_structure = [0.8, 2.0, 5.0, 12.0],
        zoo_size_structure = [15.0, 40.0, 120.0],
    ),
)

nothing #hide

# ## Construct models and inspect tracers
#
# The number of generated plankton tracers follows directly from the size-structure inputs.
# For example, five phytoplankton and four zooplankton classes create `P1`--`P5` and `Z1`--`Z4`.

function construct_bgc(community)
    return Agate.Models.NiPiZD.construct(;
        phyto_size_structure = community.phyto_size_structure,
        zoo_size_structure = community.zoo_size_structure,
    )
end

bgcs = (; (name => construct_bgc(community) for (name, community) in pairs(communities))...)

for (name, bgc) in pairs(bgcs)
    println(communities[name].title)
    println(tracer_names(bgc))
end

nothing #hide

# ## Plot plankton sizes
#
# This plot compares the size classes created by the three community definitions.
# Phytoplankton and zooplankton are shown on the same diameter axis so the trophic size separation is visible.

fig_sizes = Figure(; size = (900, 600), fontsize = 16)
ax_sizes = Axis(fig_sizes[1, 1]; xlabel = "Diameter (μm ESD)", ylabel = "Community", title = "Plankton size classes", xscale = log10)

for (row, (name, community)) in enumerate(pairs(communities))
    P_sizes = size_vector(community.phyto_size_structure)
    Z_sizes = size_vector(community.zoo_size_structure)

    scatter!(ax_sizes, P_sizes, fill(row - 0.12, length(P_sizes)); marker = :circle, markersize = 18, label = row == 1 ? "Phytoplankton" : nothing)
    scatter!(ax_sizes, Z_sizes, fill(row + 0.12, length(Z_sizes)); marker = :rect, markersize = 18, label = row == 1 ? "Zooplankton" : nothing)
end

ax_sizes.yticks = (1:length(communities), [community.title for community in communities])
axislegend(ax_sizes; position = :rb)
save(joinpath("figures", "04_size_classes.png"), fig_sizes)
fig_sizes

# ## Run zero-dimensional ecosystem simulations
#
# We next run each community in a well-mixed box model.
# Initial plankton biomass is distributed evenly within phytoplankton and zooplankton so that changing `n` does not automatically change total initial biomass.

function initial_conditions(bgc; total_P = 0.12, total_Z = 0.03)
    tracers = tracer_names(bgc)
    P_tracers = filter(tracer -> startswith(String(tracer), "P"), tracers)
    Z_tracers = filter(tracer -> startswith(String(tracer), "Z"), tracers)

    values = Dict{Symbol, Float64}(:N => 8.0, :D => 0.01)

    for tracer in P_tracers
        values[tracer] = total_P / length(P_tracers)
    end

    for tracer in Z_tracers
        values[tracer] = total_Z / length(Z_tracers)
    end

    return (; (tracer => values[tracer] for tracer in tracers)...)
end

function run_box_model(bgc; filename)
    light_attenuation = FunctionFieldPAR(; grid = BoxModelGrid())
    bgc_model = Biogeochemistry(bgc; light_attenuation)
    full_model = BoxModel(; biogeochemistry = bgc_model)

    set!(full_model; initial_conditions(bgc)...)

    simulation = Simulation(full_model; Δt = 240minutes, stop_time = 1095days)

    simulation.output_writers[:fields] = JLD2Writer(
        full_model,
        full_model.fields;
        filename,
        schedule = TimeInterval(1day),
        overwrite_existing = true,
    )

    run!(simulation)
    return (; filename, tracer_syms = tracer_names(bgc))
end

outputs = (; (
    name => run_box_model(bgc; filename = joinpath("outputs", "04_$(name).jld2"))
    for (name, bgc) in pairs(bgcs)
)...)

nothing #hide

# ## Median and mean plankton size through time
#
# The workshop diagnostics include plots of community size structure.
# Here we calculate two related summaries from each simulation:
#
# - the biomass-weighted mean size, which responds smoothly to biomass shifts;
# - the biomass-weighted median size, which is the size at which half the living plankton biomass is smaller and half is larger.

function weighted_median_size(sizes, biomass)
    valid = isfinite.(sizes) .& isfinite.(biomass) .& (biomass .> 0)
    any(valid) || return NaN

    valid_sizes = sizes[valid]
    valid_biomass = biomass[valid]
    total = sum(valid_biomass)
    total <= 0 && return NaN

    order = sortperm(valid_sizes)
    sorted_sizes = valid_sizes[order]
    sorted_biomass = valid_biomass[order]
    cumulative = cumsum(sorted_biomass) ./ total

    idx = findfirst(c -> c >= 0.5, cumulative)
    isnothing(idx) && return sorted_sizes[end]
    return sorted_sizes[idx]
end

function weighted_mean_size(sizes, biomass)
    valid = isfinite.(sizes) .& isfinite.(biomass) .& (biomass .> 0)
    any(valid) || return NaN

    valid_sizes = sizes[valid]
    valid_biomass = biomass[valid]
    total = sum(valid_biomass)
    total <= 0 && return NaN

    return sum(valid_sizes .* valid_biomass) / total
end

function read_size_summary(output, community)
    filename = output.filename
    tracer_syms = output.tracer_syms
    times = FieldTimeSeries(filename, string(first(tracer_syms))).times ./ day

    P_sizes = size_vector(community.phyto_size_structure)
    Z_sizes = size_vector(community.zoo_size_structure)
    sizes = [P_sizes..., Z_sizes...]
    plankton = [filter(tracer -> startswith(String(tracer), "P"), tracer_syms)...,
                filter(tracer -> startswith(String(tracer), "Z"), tracer_syms)...]

    biomass = reduce(hcat, [collect(FieldTimeSeries(filename, string(tracer))[1, 1, 1, :]) for tracer in plankton])
    total_biomass = vec(sum(biomass; dims = 2))

    mean_size = [weighted_mean_size(sizes, biomass[i, :]) for i in axes(biomass, 1)]
    median_size = [weighted_median_size(sizes, biomass[i, :]) for i in axes(biomass, 1)]

    final_biomass = biomass[end, :]

    return (; times = collect(times), sizes, plankton, biomass, final_biomass, mean_size, median_size, total_biomass)
end

summaries = (; (name => read_size_summary(outputs[name], community) for (name, community) in pairs(communities))...)

nothing #hide

# ## Plot size summaries
#
# The top panel compares the final biomass across size classes.
# The lower panels show the community mean and median size over time.

fig_summary = Figure(; size = (1000, 850), fontsize = 16)

ax_final = Axis(fig_summary[1, 1:2]; xlabel = "Diameter (μm ESD)", ylabel = "Final biomass (mmol N m⁻³)", title = "Final plankton biomass by size", xscale = log10)
ax_mean = Axis(fig_summary[2, 1]; xlabel = "Time (days)", ylabel = "Mean diameter (μm)", title = "Biomass-weighted mean size")
ax_median = Axis(fig_summary[2, 2]; xlabel = "Time (days)", ylabel = "Median diameter (μm)", title = "Biomass-weighted median size")

for (name, summary) in pairs(summaries)
    label = communities[name].title

    scatter!(ax_final, summary.sizes, summary.final_biomass; markersize = 16, label)
    lines!(ax_mean, summary.times, summary.mean_size; label)
    lines!(ax_median, summary.times, summary.median_size; label)
end

axislegend(ax_final; position = :rt)
save(joinpath("figures", "04_size_dynamics.png"), fig_summary)
fig_summary

# ## Compare linear and logarithmic splitting
#
# Linear splitting places equal distance between diameters.
# Logarithmic splitting places equal distance between the logarithms of diameters.
# The latter is often more useful when size spans orders of magnitude.

linear_phyto = (n = 5, min_esd = 0.8, max_esd = 20.0, splitting = :linear_splitting)
log_phyto = (n = 5, min_esd = 0.8, max_esd = 20.0, splitting = :log_splitting)

fig_splitting = Figure(; size = (800, 420), fontsize = 16)
ax_split = Axis(fig_splitting[1, 1]; xlabel = "Class index", ylabel = "Diameter (μm ESD)", title = "Linear versus logarithmic splitting", yscale = log10)

lines!(ax_split, 1:linear_phyto.n, size_vector(linear_phyto); label = "linear_splitting")
scatter!(ax_split, 1:linear_phyto.n, size_vector(linear_phyto))

lines!(ax_split, 1:log_phyto.n, size_vector(log_phyto); label = "log_splitting")
scatter!(ax_split, 1:log_phyto.n, size_vector(log_phyto))

axislegend(ax_split; position = :lt)
save(joinpath("figures", "04_linear_vs_log_splitting.png"), fig_splitting)
fig_splitting

# ## Exercises
#
# 1. Change `n` for phytoplankton from 3 to 6 in the `size_structure` community.
#    How do the tracer names and initial conditions change?
# 2. Change `min_esd` and `max_esd` for zooplankton.
#    How does the final biomass distribution move across the size axis?
# 3. Compare `:linear_splitting` and `:log_splitting` over the same size range.
#    Which one gives more resolution to small plankton?
# 4. Replace one generated size structure with an explicit vector.
#    When would explicit sizes be preferable to a generated range?
