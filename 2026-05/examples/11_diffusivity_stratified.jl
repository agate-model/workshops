# # [Exercise 11: Stratified diffusivity] (@id diffusivity_stratified_exercise)

# This exercise introduces stratified vertical diffusivity in a simple two-layer water-column model.

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
workshop_script = let dir = @__DIR__
    while !isfile(joinpath(dir, "src", "AgateWorkshop.jl"))
        parent = dirname(dir)
        parent == dir && error("Could not find src/AgateWorkshop.jl")
        dir = parent
    end
    joinpath(dir, "src", "AgateWorkshop.jl")
end
include(workshop_script)

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
z_range = [-150.0, -50.0]  # Two 100 m layer centers 
x, y, z = 0.0, 0.0, 0.0
κₜ_values = [diffusivity(x, y, z, t) for t in t_range, z in z_range]
PAR_values = [irradiance(x, y, z, t) for t in t_range, z in z_range]

fig_forcing = Figure(; size=(800, 600), fontsize=14)
forcing_heatmap!(fig_forcing, 1, t_range ./ days, z_range, PAR_values; title="irradiance")
forcing_heatmap!(fig_forcing, 2, t_range ./ days, z_range, κₜ_values; title="diffusivity")

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
filename = "11_diffusivity_stratified.jld2"

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
save("11_diffusivity_stratified.png", fig)

fig  # Display the figure
