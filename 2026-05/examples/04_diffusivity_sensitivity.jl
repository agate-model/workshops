# # [1D water column example] (@id 1D_column_example)

# !!! info
#     This example uses [Oceananigans.jl](https://clima.github.io/OceananigansDocumentation/stable/) and [OceanBioME.jl](https://oceanbiome.github.io/OceanBioME.jl/stable/).
#     We recommend familiarizing yourself with their user interface if you intend to make changes to the physical model setup.

# In this example we run a default Agate.jl-NiPiZD model inside a 2 layer column model.
# The simulation is repeated across a range of vertical diffusivities, then the top-layer
# total plankton biomass is summarized as a function of κ_max.

# ## Loading dependencies

using Agate
using Agate.Library.Light
using OceanBioME
using OceanBioME: Biogeochemistry
using Oceananigans
using Oceananigans.Units
using CairoMakie
using Statistics

stop_time = 3*365day
Δt = 1hour
output_interval = 1day
layer_interface = -100meters
PAR_surface_max = 80

κ_values = [
    3e-5,
    1e-4,
    3e-4,
    1e-3,
]

# ## Forcings

function make_diffusivity(κ_max, layer_interface)
    return (x, y, z, t) -> ifelse(z >= layer_interface, κ_max, 0.0)
end

function irradiance(x, y, z, t)
    return ifelse(z >= layer_interface, PAR_surface_max, 0.0)
end

# ## Physical and ecosystem model

function build_model(κ_max)
    grid = RectilinearGrid(; size=(1, 1, 2), extent=(20meters, 20meters, 200meters))
    diffusivity = make_diffusivity(κ_max, layer_interface)

    bgc = Agate.Models.NiPiZD.construct()
    bgc_model = Biogeochemistry(
        bgc; light_attenuation=FunctionFieldPAR(; grid, PAR_f=irradiance)
    )

    model = NonhydrostaticModel(;
        grid,
        clock=Clock(; time=0.0),
        timestepper=:QuasiAdamsBashforth2,
        closure=ScalarDiffusivity(
            VerticallyImplicitTimeDiscretization(); ν=diffusivity, κ=diffusivity
        ),
        biogeochemistry=bgc_model,
    )

    set!(model; N=7.0, P1=0.01, P2=0.01, Z1=0.05, Z2=0.05, D=0.0)

    return model
end

function output_filename(κ_max)
    κ_label = replace(string(κ_max), "." => "p", "-" => "m")
    return "N2P2ZD_column_k$(κ_label).jld2"
end

function run_column(κ_max)
    model = build_model(κ_max)
    filename = output_filename(κ_max)

    simulation = Simulation(model; Δt, stop_time)

    simulation.output_writers[:profiles] = JLD2Writer(
        model,
        model.tracers;
        filename,
        schedule=TimeInterval(output_interval),
        overwrite_existing=true,
    )

    run!(simulation)

    return filename, model
end

function top_layer_index(timeseries_field)
    _, _, z_nodes = nodes(timeseries_field)
    z_vals = collect(z_nodes)
    return argmax(z_vals)
end

function top_layer_plankton_biomass(filename)
    P1 = FieldTimeSeries(filename, "P1")
    P2 = FieldTimeSeries(filename, "P2")
    Z1 = FieldTimeSeries(filename, "Z1")
    Z2 = FieldTimeSeries(filename, "Z2")

    k_top = top_layer_index(P1)
    times = collect(P1.times ./ days)

    biomass = vec(
        interior(P1, 1, 1, k_top, :) .+
        interior(P2, 1, 1, k_top, :) .+
        interior(Z1, 1, 1, k_top, :) .+
        interior(Z2, 1, 1, k_top, :)
    )

    final_biomass = biomass[end]
    final_year = times .>= maximum(times) - 365
    mean_final_year_biomass = mean(biomass[final_year])

    return final_biomass, mean_final_year_biomass
end

# ## Sensitivity runs

final_top_layer_biomass = Float64[]
mean_final_year_top_layer_biomass = Float64[]

for κ_max in κ_values
    @info "Running diffusivity sensitivity" κ_max
    filename, _ = run_column(κ_max)
    final_biomass, mean_final_year_biomass = top_layer_plankton_biomass(filename)
    push!(final_top_layer_biomass, final_biomass)
    push!(mean_final_year_top_layer_biomass, mean_final_year_biomass)
end

# ## Plot top-layer total plankton biomass against κ_max

fig = Figure(; size=(850, 550), fontsize=16)
ax = Axis(
    fig[1, 1];
    xlabel="κ_max (m² s⁻¹)",
    ylabel="Top-layer total plankton biomass (mmol N m⁻³)",
    title="Diffusivity sensitivity",
    xscale=log10,
)

scatterlines!(ax, κ_values, mean_final_year_top_layer_biomass; label="Final-year mean")
axislegend(ax; position=:rb)

save("top_layer_plankton_biomass_vs_kmax.png", fig)

fig
