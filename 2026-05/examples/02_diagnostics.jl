# # [Exercise 02: Diagnostics] (@id diagnostics_exercise)
#
# This exercise introduces reusable diagnostic functions from
# `src/WorkshopDiagnostics.jl`. The functions live in `src` so that later
# exercises can reuse them, but the calls are shown here explicitly.

# ## Loading dependencies

using CairoMakie

include(joinpath(@__DIR__, "..", "src", "WorkshopSetup.jl"))

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

fig_tracers = plot_tracer_concentrations(
    times,
    data,
    run.tracer_syms;
    figure_path=joinpath("figures", "02_diagnostic_tracer_concentrations.png"),
)
fig_tracers

# ## Relative nitrogen contributions
#
# `plot_contributions` sums phytoplankton and zooplankton
# tracers, then compares their relative contributions with nutrient and
# detritus pools and with each other.

fig_nitrogen = plot_contributions(
    times,
    data;
    figure_path=joinpath("figures", "02_diagnostic_relative_nitrogen_contributions.png"),
)
fig_nitrogen

# ## Community-weighted mean size
#
# The default Quick start does not expose a single canonical size diagnostic, so
# the workshop uses an illustrative diameter lookup for the plankton groups.
# This diagnostic plots the community-weighted mean size for all plankton, then
# overlays the phytoplankton and zooplankton means separately.

fig_size = plot_size_spectrum(
    times,
    data;
    diameters=default_plankton_diameters(),
    figure_path=joinpath("figures", "02_diagnostic_size_spectrum.png"),
)
fig_size

# ## Trophic interactions
#
# `default_predation_matrix` and `summarize_predation_matrix` create a compact
# workshop representation of who eats whom. Later exercises can replace this
# illustrative matrix with matrices generated from model parameters.

predation = default_predation_matrix()
summary = summarize_predation_matrix(predation.groups, predation.matrix)
println(summary)

fig_trophic = plot_trophic_interactions(
    predation.groups,
    predation.matrix;
    figure_path=joinpath("figures", "02_diagnostic_trophic_interactions.png"),
)
fig_trophic

# ## Exercises
#
# 1. Change the box-model community size and rerun the tracer concentration diagnostic.
# 2. Change one illustrative plankton diameter and rerun the size diagnostic.
# 3. Compare the phytoplankton and zooplankton CWM curves. Which community shifts more?
# 4. Turn on cannibalism in `default_predation_matrix(; cannibalism=true)`. How does connectance change?
