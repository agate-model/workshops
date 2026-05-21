# # [Exercise 07: Irradiance] (@id irradiance_exercise)

# !!! info
#     This example uses [Oceananigans.jl](https://clima.github.io/OceananigansDocumentation/stable/) and [OceanBioME.jl](https://oceanbiome.github.io/OceanBioME.jl/stable/).
#     We recommend familiarizing yourself with their user interface if you intend to make changes to the physical model setup.

# This exercise focuses on irradiance forcing in a simple 1D water-column model.
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
@inline diffusivity_profile(x, y, z, t) = 1e-2

#irradiance
@inline function constant_PAR(x, y, z, t)
    PAR⁰ = 80
    return PAR⁰ * exp(0.2 * z)
end

#plots
t_range = 0.0:days:(365.0 * days)  # Time range from 0 to 365 days 
z_range = -200.0:10.0:0.0  # Depth range from -200m to 0m 
x, y, z = 0.0, 0.0, 0.0
κₜ_values = [diffusivity_profile(x, y, z, t) for t in t_range, z in z_range]
PAR_values = [constant_PAR(x, y, z, t) for t in t_range, z in z_range]

fig_forcing = Figure(; size=(800, 600), fontsize=14)
ax1 = Axis(fig_forcing[1, 1]; xlabel="Time (days)", ylabel="Depth (m)", title="irradiance")
hm1 = CairoMakie.heatmap!(ax1, t_range ./ days, z_range, PAR_values; colormap=:viridis)
Colorbar(fig_forcing[1, 2], hm1)

ax2 = Axis(fig_forcing[2, 1]; xlabel="Time (days)", ylabel="Depth (m)", title="diffusivity")
hm2 = CairoMakie.heatmap!(ax2, t_range ./ days, z_range, κₜ_values; colormap=:viridis)
Colorbar(fig_forcing[2, 2], hm2)

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

set!(full_model; N=7.0, P1=0.01, P2=0.01, Z1=0.05, Z2=0.05, D=0.0) # mmol N / m³

# ## Simulation
filename = "N2P2ZD_column.jld2"

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
save("N2P2ZD_column.png", fig)

fig  # Display the figure
