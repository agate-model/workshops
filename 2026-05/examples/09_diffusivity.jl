# # [Exercise 09: Diffusivity] (@id diffusivity_exercise)

# This exercise introduces vertical diffusivity in a simple two-layer water-column model.

# ## Loading dependencies
# The example uses Agate.jl, Oceananigans.jl, and OceanBioME.jl for the ocean simulations.
# CairoMakie.jl is used for plotting.

using Agate
using Agate.Library.Light
using OceanBioME
using OceanBioME: Biogeochemistry
using Oceananigans
using Oceananigans.Units
using CairoMakie
using AgateWorkshop

stop_time = 3*365day # simulate for 3 years
nothing #hide

# ## Forcings

# Second, we define the model physical forcings. Diffusivity is split across a 100 m interface on a two-level vertical grid, and PAR is held at its maximum surface value with a fixed attenuation coefficient.
#diffusivity
@inline function diffusivity(x, y, z, t)
    κ_max = 1e-5
    layer_interface = -100meters

    if z >= layer_interface
        return κ_max
    else
        return 0.0
    end
end

#irradiance
function irradiance(x, y, z, t)
    PAR_surface_max = 80
    layer_interface = -100meters

    return ifelse(z >= layer_interface, PAR_surface_max, 0.0)
end

#plots
t_range = 0.0:days:(365.0 * days)  # Time range from 0 to 365 days 
z_range = [-150.0, -50.0]  # Two 100 m layer centers 
x, y, z = 0.0, 0.0, 0.0
κₜ_values = [diffusivity(x, y, z, t) for t in t_range, z in z_range]
PAR_values = [irradiance(x, y, z, t) for t in t_range, z in z_range]

fig_forcing = Figure(; size=(800, 600), fontsize=14)
ax1 = Axis(fig_forcing[1, 1]; xlabel="Time (days)", ylabel="Depth (m)", title="irradiance")
hm1 = CairoMakie.heatmap!(ax1, t_range ./ days, z_range, PAR_values; colormap=:viridis)
Colorbar(fig_forcing[1, 2], hm1)

ax2 = Axis(fig_forcing[2, 1]; xlabel="Time (days)", ylabel="Depth (m)", title="diffusivity")
hm2 = CairoMakie.heatmap!(ax2, t_range ./ days, z_range, κₜ_values; colormap=:viridis)
Colorbar(fig_forcing[2, 2], hm2)

fig_forcing

# ## Physical model

grid = RectilinearGrid(; size=(1, 1, 2), extent=(20meters, 20meters, 200meters))
nothing #hide

# ## Ecosystem model

# First, we construct our ecosystem model.
# Here, we use a default 2 phytoplankton, 2 zooplankton `Agate.jl-NiPiZD` ecosystem model.
# Detritus sinks downward at 2 m/day; the closed bottom keeps sunk detritus in the lower box.

bgc = Agate.Models.NiPiZD.construct(;
)
nothing #hide

bgc_model = Biogeochemistry(
    bgc; light_attenuation=FunctionFieldPAR(; grid, PAR_f=irradiance)
)
nothing #hide

full_model = NonhydrostaticModel(;
    grid,
    clock=Clock(; time=0.0),
    timestepper=:QuasiAdamsBashforth2,
    closure=ScalarDiffusivity(
        VerticallyImplicitTimeDiscretization(); ν=diffusivity, κ=diffusivity
    ),
    biogeochemistry=bgc_model,
)
nothing #hide

# ## Initial conditions

set!(full_model; default_initial_conditions(bgc; detritus = 0.0, total_plankton_biomass = 0.12)...) # mmol N / m³

# ## Simulation
filename = "N2P2ZD_column.jld2"

simulation = Simulation(full_model; Δt=1hour, stop_time=stop_time)

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

timeseries_keys = keys(timeseries)
nothing #hide

#Filter keys for P, Z, N, and D fields
P_keys = filter(k -> startswith(string(k), "P"), timeseries_keys)
Z_keys = filter(k -> startswith(string(k), "Z"), timeseries_keys)
N_key = :N
D_key = :D

#Combine all keys into a single list for iteration
all_keys = [P_keys..., Z_keys..., N_key, D_key]

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
        limits=((0, 365*3), (-200, 0)),
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
