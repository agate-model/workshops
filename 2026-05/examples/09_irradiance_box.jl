# # [Exercise 09: Irradiance box model] (@id irradiance_box_exercise)
#
# This exercise introduces seasonal irradiance forcing in a zero-dimensional box model.
# The box is well mixed, so the light forcing only varies through time. The tracer,
# contribution, and community-size diagnostics reuse the workshop helper functions
# introduced in Exercise 02.

# ## Loading dependencies

using Agate
using Agate.Library.Light
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

const year = years = 365day

mkpath("outputs")
mkpath("figures")

nothing #hide

# ## Ecosystem model

bgc = Agate.Models.NiPiZD.construct()
initial_conditions = default_initial_conditions(bgc; detritus=0.0, total_plankton_biomass=0.12)

nothing #hide

# ## Seasonal irradiance

@inline function seasonal_surface_PAR(t)
    return 60 *
           (1 - cos((t + 15days) * 2π / year)) *
           (1 / (1 + 0.2 * exp(-((mod(t, year) - 200days) / 50days)^2))) + 2
end

@inline seasonal_PAR(t) = seasonal_surface_PAR(t)

const default_PAR = 80
@inline constant_PAR(t) = default_PAR

t_range = 0.0:days:(365.0days)
seasonal_PAR_values = [seasonal_PAR(t) for t in t_range]
default_PAR_values = [constant_PAR(t) for t in t_range]

fig_forcing = Figure(; size=(800, 350), fontsize=14)
ax = Axis(fig_forcing[1, 1]; xlabel="Time (days)", ylabel="PAR", title="Seasonal and constant irradiance")
lines!(ax, t_range ./ days, seasonal_PAR_values; linewidth=3, label="seasonal PAR")
lines!(ax, t_range ./ days, default_PAR_values; linewidth=3, linestyle=:dash, label="constant PAR")
axislegend(ax; position=:rt)
save(joinpath("figures", "09_irradiance_box_forcing.png"), fig_forcing; px_per_unit=1)

fig_forcing

# ## Box-model simulations
#
# The diagnostic comparison uses two otherwise identical box-model runs: a
# constant-irradiance reference and the seasonal-irradiance case.

constant_light = FunctionFieldPAR(; grid=BoxModelGrid(), PAR_f=constant_PAR)
seasonal_light = FunctionFieldPAR(; grid=BoxModelGrid(), PAR_f=seasonal_PAR)

constant_run = run_box_model(
    bgc;
    filename=joinpath("outputs", "09_irradiance_box_constant.jld2"),
    initial_conditions,
    stop_time=1year,
    light_attenuation=constant_light,
)

seasonal_run = run_box_model(
    bgc;
    filename=joinpath("outputs", "09_irradiance_box.jld2"),
    initial_conditions,
    stop_time=1year,
    light_attenuation=seasonal_light,
)

constant_timeseries = read_box_tracer_timeseries(constant_run.filename, constant_run.tracer_syms)
seasonal_timeseries = read_box_tracer_timeseries(seasonal_run.filename, seasonal_run.tracer_syms)

nothing #hide

# ## Tracer-concentration comparison
#
# `plot_box_timeseries` plots every shared tracer and overlays the two forcing
# cases in each panel.

tracer_comparison_path = joinpath("figures", "09_irradiance_box_tracer_comparison.png")
fig_tracers = plot_box_timeseries(
    [constant_timeseries, seasonal_timeseries];
    labels=["constant PAR", "seasonal PAR"],
    figure_path=tracer_comparison_path,
)
save(joinpath("figures", "09_irradiance_box.png"), fig_tracers; px_per_unit=1)
fig_tracers

# ## Nitrogen contributions
#
# The stacked-area diagnostic shows how living and non-living nitrogen pools vary
# through the seasonal-irradiance run.

contributions_path = joinpath("figures", "09_irradiance_box_seasonal_contributions.png")
fig_contributions = plot_contributions(
    seasonal_timeseries.times,
    seasonal_timeseries.data;
    figure_path=contributions_path,
)
fig_contributions

# ## Community-weighted mean size comparison
#
# `plot_cwm_size` pairs each time series with the biogeochemistry object that
# defines the plankton diameters. Both runs use the same ecosystem model here.

cwm_comparison_path = joinpath("figures", "09_irradiance_box_cwm_size_comparison.png")
fig_cwm = plot_cwm_size(
    [constant_timeseries, seasonal_timeseries],
    [bgc, bgc];
    labels=["constant PAR", "seasonal PAR"],
    figure_path=cwm_comparison_path,
)
fig_cwm
