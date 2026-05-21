# # [Exercise 09: Irradiance box model] (@id irradiance_box_exercise)
#
# This exercise introduces seasonal irradiance forcing in a zero-dimensional box model.
# The box is well mixed, so the light forcing only varies through time.

# ## Loading dependencies

using Agate
using Agate.Introspection: tracer_names
using Agate.Library.Light
using OceanBioME
using OceanBioME: Biogeochemistry
using Oceananigans
using Oceananigans.Units
using CairoMakie

const year = years = 365day

mkpath("outputs")
mkpath("figures")

nothing #hide

# ## Ecosystem model

bgc = Agate.Models.NiPiZD.construct()
tracer_syms = Tuple(tracer_names(bgc))

nothing #hide

# ## Seasonal irradiance

@inline function seasonal_surface_PAR(t)
    return 60 *
           (1 - cos((t + 15days) * 2π / year)) *
           (1 / (1 + 0.2 * exp(-((mod(t, year) - 200days) / 50days)^2))) + 2
end

@inline seasonal_PAR(t) = seasonal_surface_PAR(t)

t_range = 0.0:days:(365.0days)
PAR_values = [seasonal_PAR(t) for t in t_range]

fig_forcing = Figure(; size=(800, 350), fontsize=14)
ax = Axis(fig_forcing[1, 1]; xlabel="Time (days)", ylabel="PAR", title="seasonal irradiance")
lines!(ax, t_range ./ days, PAR_values; linewidth=3)
save(joinpath("figures", "09_irradiance_box_forcing.png"), fig_forcing)

fig_forcing

# ## Box model

light_attenuation = FunctionFieldPAR(; grid=BoxModelGrid(), PAR_f=seasonal_PAR)
bgc_model = Biogeochemistry(bgc; light_attenuation)
full_model = BoxModel(; biogeochemistry=bgc_model)

set!(full_model; N=7.0, P1=0.01, P2=0.01, Z1=0.05, Z2=0.05, D=0.0)

filename = joinpath("outputs", "09_irradiance_box.jld2")

simulation = Simulation(full_model; Δt=240minutes, stop_time=1year)

simulation.output_writers[:fields] = JLD2Writer(
    full_model,
    full_model.fields;
    filename=filename,
    schedule=TimeInterval(1day),
    overwrite_existing=true,
)

run!(simulation)

nothing #hide

# ## Plotting

timeseries = NamedTuple{tracer_syms}(
    FieldTimeSeries(filename, "$field") for field in tracer_syms
)

fig = Figure(; size=(900, 900), fontsize=16)

for (i, key) in enumerate(tracer_syms)
    row = cld(i, 2)
    column = mod1(i, 2)
    times = collect(timeseries[key].times ./ days)
    values = vec(interior(timeseries[key], 1, 1, 1, :))

    ax = Axis(
        fig[row, column];
        title="$(key) concentration (mmol N / m³)",
        xlabel="Time (days)",
        ylabel="Concentration (mmol N / m³)",
        limits=((0, 365), nothing),
    )
    lines!(ax, times, values; linewidth=3)
end

save(joinpath("figures", "09_irradiance_box.png"), fig)

fig
