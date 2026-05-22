# # [Exercise 09: Irradiance box model] (@id irradiance_box_exercise)
#
# This exercise introduces seasonal irradiance forcing in a zero-dimensional box model.

# ## Loading dependencies

using Agate
using Agate.Library.Light
using OceanBioME: BoxModelGrid
using Oceananigans.Units
using CairoMakie
using AgateWorkshop

const year = years = 365day

mkpath("outputs")
mkpath("figures")

nothing #hide

# ## Ecosystem model

bgc = Agate.Models.NiPiZD.construct()
initial_conditions = default_initial_conditions(bgc)

nothing #hide

# ## Irradiance forcing

@inline function seasonal_surface_PAR(t)
    return 60 *
           (1 - cos((t + 15days) * 2π / year)) *
           (1 / (1 + 0.2 * exp(-((mod(t, year) - 200days) / 50days)^2))) + 2
end

@inline seasonal_PAR(t) = seasonal_surface_PAR(t)

@inline nonseasonal_surface_PAR(t) = 100 * max(0, cos(t * π / 12hours))
@inline nonseasonal_PAR(t) = nonseasonal_surface_PAR(t)

t_range = 0.0:hours:(365.0days)
seasonal_PAR_values = [seasonal_PAR(t) for t in t_range]
nonseasonal_PAR_values = [nonseasonal_PAR(t) for t in t_range]

fig_forcing = Figure(; size=(800, 350), fontsize=14)
ax = Axis(fig_forcing[1, 1]; xlabel="Time (days)", ylabel="PAR", title="Seasonal and non-seasonal irradiance")
lines!(ax, t_range ./ days, seasonal_PAR_values; linewidth=3, label="seasonal PAR")
lines!(ax, t_range ./ days, nonseasonal_PAR_values; linewidth=3, linestyle=:dash, label="non-seasonal PAR")
axislegend(ax; position=:rt)
save(joinpath("figures", "09_irradiance_box_forcing.png"), fig_forcing; px_per_unit=1)

fig_forcing

# ## Box-model simulations
#
# The diagnostic comparison uses two otherwise identical box-model runs: a
# non-seasonal reference and the seasonal-irradiance case. The reference
# uses the same default `FunctionFieldPAR(; grid=BoxModelGrid())` light forcing
# and default initial conditions as the workshop box-model helpers.

nonseasonal_light = FunctionFieldPAR(; grid=BoxModelGrid())
seasonal_light = FunctionFieldPAR(; grid=BoxModelGrid(), PAR_f=seasonal_PAR)

nonseasonal_run = run_box_model(
    bgc;
    filename=joinpath("outputs", "09_irradiance_box_nonseasonal.jld2"),
    initial_conditions,
    stop_time=1year,
    light_attenuation=nonseasonal_light,
)

seasonal_run = run_box_model(
    bgc;
    filename=joinpath("outputs", "09_irradiance_box.jld2"),
    initial_conditions,
    stop_time=1year,
    light_attenuation=seasonal_light,
)

nonseasonal_timeseries = read_box_tracer_timeseries(nonseasonal_run.filename, nonseasonal_run.tracer_syms)
seasonal_timeseries = read_box_tracer_timeseries(seasonal_run.filename, seasonal_run.tracer_syms)

nothing #hide

# ## Tracer-concentration comparison
#
# `plot_box_timeseries` plots every shared tracer and overlays the two forcing
# cases in each panel.

tracer_comparison_path = joinpath("figures", "09_irradiance_box_tracer_comparison.png")
fig_tracers = plot_box_timeseries(
    [nonseasonal_timeseries, seasonal_timeseries];
    labels=["non-seasonal PAR", "seasonal PAR"],
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
    [nonseasonal_timeseries, seasonal_timeseries],
    [bgc, bgc];
    labels=["non-seasonal PAR", "seasonal PAR"],
    figure_path=cwm_comparison_path,
)
fig_cwm
