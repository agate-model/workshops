# # [Exercise 02: Diagnostics] (@id diagnostics_exercise)
#
# This exercise introduces reusable diagnostics from the workshop helper script so later
# exercises can load and reuse them directly.

# ## Loading dependencies

using CairoMakie
using Agate
using Oceananigans.Units: day
workshop_script = let dir = @__DIR__
    while !isfile(joinpath(dir, "src", "AgateWorkshop.jl"))
        parent = dirname(dir)
        parent == dir && error("Could not find src/AgateWorkshop.jl")
        dir = parent
    end
    joinpath(dir, "src", "AgateWorkshop.jl")
end
include(workshop_script)


mkpath(joinpath("outputs"))
mkpath(joinpath("figures"))

nothing #hide

# ## Run the Quick start model
#
# The diagnostics operate on saved box-model output. We reuse the wrapper from
# Exercise 01 to create a small output file.

bgc = default_quickstart_bgc()
run = run_box_model(bgc; filename=joinpath("outputs", "02_diagnostics_quick_start.jld2"))
timeseries = read_box_tracer_timeseries(run.filename, run.tracer_syms)

times = timeseries.times
data = timeseries.data

nothing #hide

# ## Tracer concentrations
#
# `plot_tracer_concentrations` follows the per-tracer plotting pattern from the
# Quick start exercise, but grows the figure vertically for larger communities.

tracer_concentrations_figure_path = joinpath("figures", "02_diagnostic_tracer_concentrations.png")
fig_tracers = plot_tracer_concentrations(times, data, run.tracer_syms)
save(tracer_concentrations_figure_path, fig_tracers; px_per_unit=1)
fig_tracers

# ## Relative nitrogen contributions
#
# `plot_contributions` shows three coordinated stacked-area diagnostics:
# individual tracer contributions, living versus non-living nitrogen, and
# phytoplankton versus zooplankton contributions to living biomass.

nitrogen_contributions_figure_path = joinpath("figures", "02_diagnostic_relative_nitrogen_contributions.png")
fig_nitrogen = plot_contributions(times, data)
save(nitrogen_contributions_figure_path, fig_nitrogen; px_per_unit=1)
fig_nitrogen

# ## Community-weighted mean size
#
# Agate.jl stores plankton equivalent spherical diameter (ESD) metadata on
# constructed biogeochemistry objects. The size diagnostic takes the
# biogeochemistry object directly, uses Agate introspection internally, and
# keeps tracer labels and diameters aligned with the model definition. It plots
# the community-weighted mean size for all plankton, then separates the
# phytoplankton and zooplankton mean sizes into their own subplots.

size_spectrum_figure_path = joinpath("figures", "02_diagnostic_size_spectrum.png")
fig_size = plot_size_spectrum(times, data, bgc)
save(size_spectrum_figure_path, fig_size; px_per_unit=1)
fig_size

# ### Comparison
#
# The same comparison helper can plot any selected variables from two or more
# time series. The default detritus remineralization rate is `0.1213 / day`.
# Here we compare the default run with a higher remineralization case,
# `0.25 / day`, for selected tracer concentrations.

high_remineralization_bgc = Agate.Models.NiPiZD.construct(;
    parameters = (detritus_remineralization = 0.25 / day,),
)
high_remineralization_run = run_box_model(
    high_remineralization_bgc;
    filename=joinpath("outputs", "02_diagnostics_high_detritus_remineralization.jld2"),
)
high_remineralization_timeseries = read_box_tracer_timeseries(
    high_remineralization_run.filename,
    high_remineralization_run.tracer_syms,
)

comparison_figure_path = joinpath("figures", "02_diagnostic_timeseries_comparison.png")
fig_comparison = plot_timeseries_comparison(
    timeseries,
    high_remineralization_timeseries;
    labels=["default", "detritus remineralization = 0.25 / day"],
    variables=[:N, :D],
    ylabels=Dict(
        :N => "N concentration (mmol N m⁻³)",
        :D => "D concentration (mmol N m⁻³)",
    ),
)
save(comparison_figure_path, fig_comparison; px_per_unit=1)
fig_comparison


# ## Parameter bars
#
# The same helper can also inspect model parameters directly. Here we plot the default
# maximum phytoplankton growth-rate values for the plankton types represented in the model.

parameter_bar_figure_path = joinpath("figures", "02_diagnostic_mumax_parameter_bars.png")
fig_mumax_parameter = plot_plankton_parameter_bars(
    bgc,
    :maximum_growth_rate;
    ylabel = "maximum_growth_rate",
    title = "Maximum growth rate by phytoplankton type",
)
save(parameter_bar_figure_path, fig_mumax_parameter; px_per_unit=1)
fig_mumax_parameter

# ## Exercises
#
# 1. Change the box-model community size and rerun the tracer concentration diagnostic.
# 2. Change the model size structure and rerun the size diagnostic.
# 3. Compare the phytoplankton and zooplankton CWM panels. Which community shifts more?
# 4. Add another altered parameter set and compare selected tracers with `plot_timeseries_comparison`.
