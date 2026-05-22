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
# `plot_box_timeseries` accepts the complete named tuple returned by
# `read_box_tracer_timeseries` and plots each tracer in a separate panel.

tracer_concentrations_figure_path = joinpath("figures", "02_diagnostic_tracer_concentrations.png")
fig_tracers = plot_box_timeseries(timeseries)
save(tracer_concentrations_figure_path, fig_tracers; px_per_unit=1)
display(fig_tracers)
fig_tracers

# ### Comparison
#
# The same helper can also compare two or more box-model time series. The
# default detritus remineralization rate is `0.1213 / day`. Here we compare
# the default run with a higher remineralization case, `0.25 / day`, for all
# shared tracers.

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
fig_comparison = plot_box_timeseries(
    [timeseries, high_remineralization_timeseries];
    labels=["default", "detritus remineralization = 0.25 / day"],
)
save(comparison_figure_path, fig_comparison; px_per_unit=1)
display(fig_comparison)
fig_comparison

# ## Relative nitrogen contributions
#
# `plot_contributions` shows two coordinated stacked-area diagnostics:
# living versus non-living nitrogen, and phytoplankton versus zooplankton
# contributions to living biomass.

nitrogen_contributions_figure_path = joinpath("figures", "02_diagnostic_relative_nitrogen_contributions.png")
fig_nitrogen = plot_contributions(times, data)
save(nitrogen_contributions_figure_path, fig_nitrogen; px_per_unit=1)
display(fig_nitrogen)
fig_nitrogen

# ## Community-weighted mean size
#
# Agate.jl stores plankton equivalent spherical diameter (ESD) metadata on
# constructed biogeochemistry objects. `plot_cwm_size` accepts a box-model time
# series and the matching biogeochemistry object, then computes the
# community-weighted mean size for all plankton, phytoplankton, and zooplankton.

cwm_size_figure_path = joinpath("figures", "02_diagnostic_cwm_size.png")
fig_size = plot_cwm_size(timeseries, bgc)
save(cwm_size_figure_path, fig_size; px_per_unit=1)
display(fig_size)
fig_size

# ## Community-weighted mean size comparison
#
# The same helper can compare multiple runs. Each time series is paired with a
# biogeochemistry object because the plankton sizes are defined by the model,
# and different models may have different plankton groups or size structures.

cwm_size_comparison_figure_path = joinpath("figures", "02_diagnostic_cwm_size_comparison.png")
fig_size_comparison = plot_cwm_size(
    [timeseries, high_remineralization_timeseries],
    [bgc, high_remineralization_bgc];
    labels=["default", "detritus remineralization = 0.25 / day"],
)
save(cwm_size_comparison_figure_path, fig_size_comparison; px_per_unit=1)
display(fig_size_comparison)
fig_size_comparison

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
display(fig_mumax_parameter)
fig_mumax_parameter
