# # [Exercise 10: Irradiance column] (@id irradiance_column_exercise)

# !!! info
#     This example uses [Oceananigans.jl](https://clima.github.io/OceananigansDocumentation/stable/) and [OceanBioME.jl](https://oceanbiome.github.io/OceanBioME.jl/stable/).
#     We recommend familiarizing yourself with their user interface if you intend to make changes to the physical model setup.

# This exercise focuses on constant irradiance forcing with depth-dependent attenuation in a simple 1D water-column model.
# The physical model setup is based on an example provided in the OceanBioME.jl documentation and represents an idealized 200m deep North Atlantic time series.

# ## Loading dependencies
# The example uses Agate.jl, Oceananigans.jl, and OceanBioME.jl for the ocean simulations.
# CairoMakie is used for plotting.

using Agate
using Agate.Introspection: tracer_groups
using Agate.Library.Light
using OceanBioME
using OceanBioME: Biogeochemistry
using Oceananigans
using Oceananigans.Units
using CairoMakie
workshop_script = let dir = @__DIR__
    while !isfile(joinpath(dir, "src", "AgateWorkshop.jl"))
        parent = dirname(dir)
        parent == dir && error("Could not find src/AgateWorkshop.jl")
        dir = parent
    end
    joinpath(dir, "src", "AgateWorkshop.jl")
end
include(workshop_script)

year = years = 365day
nothing #hide

# ## Ecosystem model

# First, we construct our ecosystem model.
# Here, we use a default 2 phytoplankton, 2 zooplankton `Agate.jl-NiPiZD` ecosystem model.

bgc = Agate.Models.NiPiZD.construct()
groups = tracer_groups(bgc)
nothing #hide

# ## Forcings

# Second, we define the model physical forcings. Diffusivity is held high throughout the water column, while PAR is held at a fixed surface value with depth-dependent attenuation.

#diffusivity
@inline diffusivity_profile(x, y, z, t) = 1e-4

#irradiance
@inline function constant_PAR(x, y, z, t)
    PAR⁰ = 80
    attenuation = 0.04
    return PAR⁰ * exp(attenuation * z)
end

#plots

function discrete_ticks(values)
    labels = [v == 0 ? "0" : string(v) for v in values]
    return (collect(1:length(values)), labels)
end

function forcing_heatmap!(fig, row, x, y, values; title, colormap=:viridis)
    ax = Axis(fig[row, 1]; xlabel="Time (days)", ylabel="Depth (m)", title)
    unique_values = sort(unique(vec(Float64.(values))))

    if length(unique_values) <= 2
        indices = map(v -> findfirst(isequal(Float64(v)), unique_values), values)
        discrete_colormap = length(unique_values) == 1 ? [:gray] : cgrad(colormap, length(unique_values); categorical=true)
        hm = CairoMakie.heatmap!(
            ax,
            x,
            y,
            indices;
            colormap=discrete_colormap,
            colorrange=(0.5, length(unique_values) + 0.5),
        )
        Colorbar(fig[row, 2], hm; ticks=discrete_ticks(unique_values))
    else
        hm = CairoMakie.heatmap!(ax, x, y, values; colormap)
        Colorbar(fig[row, 2], hm)
    end

    return ax
end

t_range = 0.0:days:(365.0 * days)  # Time range from 0 to 365 days 
z_range = -200.0:10.0:0.0  # Depth range from -200m to 0m 
x, y, z = 0.0, 0.0, 0.0
κₜ_values = [diffusivity_profile(x, y, z, t) for t in t_range, z in z_range]
PAR_values = [constant_PAR(x, y, z, t) for t in t_range, z in z_range]

fig_forcing = Figure(; size=(800, 600), fontsize=14)
forcing_heatmap!(fig_forcing, 1, t_range ./ days, z_range, PAR_values; title="irradiance")
forcing_heatmap!(fig_forcing, 2, t_range ./ days, z_range, κₜ_values; title="diffusivity")

fig_forcing

# ## Physical model

grid = RectilinearGrid(; size=(1, 1, 20), extent=(20meters, 20meters, 200meters))
nothing #hide

bgc_model = Biogeochemistry(
    bgc; light_attenuation=FunctionFieldPAR(; grid, PAR_f=constant_PAR)
)
nothing #hide

full_model = NonhydrostaticModel(;
    grid,
    clock=Clock(; time=0.0),
    timestepper=:QuasiAdamsBashforth2,
    closure=ScalarDiffusivity(
        VerticallyImplicitTimeDiscretization(); ν=diffusivity_profile, κ=diffusivity_profile
    ),
    biogeochemistry=bgc_model,
)
nothing #hide

# ## Initial conditions

set!(full_model; default_initial_conditions(bgc; detritus = 0.0, total_plankton_biomass = 0.12)...) # mmol N / m³

# ## Simulation
filename = "10_irradiance_column.jld2"

simulation = Simulation(full_model; Δt=1hours, stop_time=1year)

simulation.output_writers[:profiles] = JLD2Writer(
    full_model,
    full_model.tracers;
    filename=filename,
    schedule=TimeInterval(1day),
    overwrite_existing=true,
)

run!(simulation)
nothing #hide

# ## Plotting

#Load time series data
timeseries = NamedTuple{keys(full_model.tracers)}(
    FieldTimeSeries(filename, "$field") for field in keys(full_model.tracers)
)

# Use Agate's introspection helpers to recover the structural tracer layout
all_keys = [groups.plankton..., groups.nonplankton...]
nothing #hide

#Create figure with appropriate size
fig = Figure(; size=(800, 1200), fontsize=16)

#Plot all fields
for (i, key) in enumerate(all_keys)
    x_nodes, y_nodes, z_nodes = nodes(timeseries[key])
    z_vals = collect(z_nodes)
    times = collect(timeseries[key].times / days)

    ax = Axis(
        fig[i, 1];
        title="$(key) concentration (mmol N / m³)",
        xlabel="Time (days)",
        ylabel="z (m)",
        limits=((0, 365), (-200, 0)),
    )
    hm = heatmap!(
        ax,
        times,
        z_vals,
        Float32.(interior(timeseries[key],1,1,:,:)');
        colormap=:viridis,
        rasterize=true,
    )  # Rasterize for smaller output
    Colorbar(fig[i, 2], hm)
end

#Save figure
save("10_irradiance_column.png", fig)

fig  # Display the figure

# Plot the final-time depth-bin value of every tracer as horizontal bars.
n_profiles = length(all_keys)
n_columns = min(3, n_profiles)
n_rows = cld(n_profiles, n_columns)
fig_profiles = Figure(; size=(350 * n_columns, 300 * n_rows), fontsize=16)

profile_axes = Axis[]
for (i, key) in enumerate(all_keys)
    row = cld(i, n_columns)
    column = mod1(i, n_columns)
    x_nodes, y_nodes, z_nodes = nodes(timeseries[key])
    z_centers = collect(z_nodes)
    final_profile = vec(interior(timeseries[key], 1, 1, :, length(timeseries[key].times)))

    z_edges = similar(z_centers, length(z_centers) + 1)
    z_edges[2:end-1] .= (z_centers[1:end-1] .+ z_centers[2:end]) ./ 2
    z_edges[1] = z_centers[1] - (z_centers[2] - z_centers[1]) / 2
    z_edges[end] = z_centers[end] + (z_centers[end] - z_centers[end-1]) / 2

    ax = Axis(
        fig_profiles[row, column];
        title=String(key),
        xlabel="Concentration (mmol N / m³)",
        ylabel=column == 1 ? "z (m)" : "",
        limits=(nothing, (-200, 0)),
    )

    for j in eachindex(final_profile)
        y0 = z_edges[j]
        y1 = z_edges[j + 1]
        x0 = min(0, final_profile[j])
        width = abs(final_profile[j])
        poly!(ax, Rect(x0, y0, width, y1 - y0); color=:dodgerblue, strokecolor=:dodgerblue)
    end

    push!(profile_axes, ax)
end

linkyaxes!(profile_axes...)
for (i, ax) in enumerate(profile_axes)
    column = mod1(i, n_columns)

    if column > 1
        hideydecorations!(ax; grid=false)
    end
end
save("10_irradiance_column_final_profiles.png", fig_profiles)

fig_profiles
