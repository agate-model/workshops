# # [Exercise 02: Diagnostics] (@id diagnostics_exercise)
#
# This exercise introduces reusable diagnostic functions from
# `src/WorkshopDiagnostics.jl`. The functions live in `src` so that later
# exercises can reuse them, but the calls are shown here explicitly.

# ## Loading dependencies

using CairoMakie

include("src/WorkshopBoxModels.jl")
include("src/WorkshopDiagnostics.jl")
using .WorkshopBoxModels
using .WorkshopDiagnostics

mkpath("outputs")
mkpath("figures")

nothing #hide

# ## Run the Quick start model
#
# The diagnostics operate on saved box-model output. We reuse the wrapper from
# Exercise 01 to create a small output file.

bgc = default_quickstart_bgc()
run = run_box_model(bgc; filename="outputs/02_diagnostics_quick_start.jld2")
timeseries = read_box_tracer_timeseries(run.filename, run.tracer_syms)

times = timeseries.times
data = timeseries.data

nothing #hide

# ## Nitrogen pools
#
# `plot_nitrogen_pools` groups individual tracers into nutrient, detritus,
# phytoplankton, zooplankton, living plankton, and total nitrogen pools.

fig_nitrogen = plot_nitrogen_pools(times, data; figure_path="figures/02_diagnostic_nitrogen_pools.png")
fig_nitrogen

# ## Persistence
#
# `plot_persistence` counts how many plankton groups remain above a chosen
# biomass threshold. This provides a simple first check for loss of groups.

fig_persistence = plot_persistence(
    times,
    data;
    threshold=1e-6,
    figure_path="figures/02_diagnostic_persistence.png",
)
fig_persistence

# ## Size spectrum
#
# The default Quick start does not expose a single canonical size diagnostic, so
# the workshop uses an illustrative diameter lookup for the four plankton groups.

fig_size = plot_size_spectrum(
    times,
    data;
    diameters=default_plankton_diameters(),
    figure_path="figures/02_diagnostic_size_spectrum.png",
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
    figure_path="figures/02_diagnostic_trophic_interactions.png",
)
fig_trophic

# ## Exercises
#
# 1. Increase the persistence threshold. Which groups disappear first?
# 2. Change one illustrative plankton diameter and rerun the size-spectrum diagnostic.
# 3. Turn on cannibalism in `default_predation_matrix(; cannibalism=true)`. How does connectance change?
# 4. Pick one diagnostic and adapt it for a later workshop exercise.
