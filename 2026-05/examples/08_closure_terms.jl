# # [Exercise 08: Closure Terms] (@id closure_terms_exercise)
#
# Mortality terms close the plankton food web by routing unresolved losses back to
# nutrients and detritus. This exercise compares the default model with two
# experiments that remove one closure pathway at a time:
#
# - no linear mortality;
# - no quadratic, density-dependent mortality.


# ## Loading dependencies

using Agate
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

mkpath(joinpath("outputs"))
mkpath(joinpath("figures"))

nothing #hide

# ## Construct closure-term configurations
#
# The default NiPiZD configuration includes both linear mortality for all
# plankton classes and quadratic mortality for the zooplankton classes. We build
# two sensitivity experiments by setting each mortality vector to zero while
# keeping all other parameters unchanged.

bgc = default_quickstart_bgc()

no_linear_bgc = Agate.Models.NiPiZD.construct(;
    parameters = (linear_mortality = zero.(bgc.parameters.linear_mortality),),
)

no_quadratic_bgc = Agate.Models.NiPiZD.construct(;
    parameters = (quadratic_mortality = zero.(bgc.parameters.quadratic_mortality),),
)

bgcs = [bgc, no_linear_bgc, no_quadratic_bgc]
case_labels = ["default", "without linear mortality", "without quadratic mortality"]

nothing #hide

# ## Run box models
#
# Each configuration is run with the same box-model setup and the same initial
# conditions helper. The diagnostics compare the resulting tracer trajectories.

run = run_box_model(bgc; filename = joinpath("outputs", "08_closure_default.jld2"))
no_linear_run = run_box_model(no_linear_bgc; filename = joinpath("outputs", "08_closure_no_linear.jld2"))
no_quadratic_run = run_box_model(no_quadratic_bgc; filename = joinpath("outputs", "08_closure_no_quadratic.jld2"))

timeseries = read_box_tracer_timeseries(run.filename, run.tracer_syms)
no_linear_timeseries = read_box_tracer_timeseries(no_linear_run.filename, no_linear_run.tracer_syms)
no_quadratic_timeseries = read_box_tracer_timeseries(no_quadratic_run.filename, no_quadratic_run.tracer_syms)

nothing #hide

# ## Tracer concentration comparison
#
# This plot compares all tracers across the default and closure-term experiments.

comparison_figure_path = joinpath("figures", "08_closure_timeseries_comparison.png")
fig_comparison = plot_box_timeseries(
    [timeseries, no_linear_timeseries, no_quadratic_timeseries];
    labels = case_labels,
)
save(comparison_figure_path, fig_comparison; px_per_unit = 1)
fig_comparison

# ## Community-weighted mean size comparison
#
# The CWM diagnostic compares how removing mortality pathways changes the size
# structure of the plankton community.

cwm_size_comparison_figure_path = joinpath("figures", "08_closure_cwm_size_comparison.png")
fig_size_comparison = plot_cwm_size(
    [timeseries, no_linear_timeseries, no_quadratic_timeseries],
    bgcs;
    labels = case_labels,
)
save(cwm_size_comparison_figure_path, fig_size_comparison; px_per_unit = 1)
fig_size_comparison

# ## Relative nitrogen contributions: default closure

nitrogen_default_figure_path = joinpath("figures", "08_closure_relative_nitrogen_default.png")
fig_nitrogen_default = plot_contributions(timeseries.times, timeseries.data)
save(nitrogen_default_figure_path, fig_nitrogen_default; px_per_unit = 1)
fig_nitrogen_default

# ## Relative nitrogen contributions: without linear mortality

nitrogen_no_linear_figure_path = joinpath("figures", "08_closure_relative_nitrogen_no_linear.png")
fig_nitrogen_no_linear = plot_contributions(no_linear_timeseries.times, no_linear_timeseries.data)
save(nitrogen_no_linear_figure_path, fig_nitrogen_no_linear; px_per_unit = 1)
fig_nitrogen_no_linear

# ## Relative nitrogen contributions: without quadratic mortality

nitrogen_no_quadratic_figure_path = joinpath("figures", "08_closure_relative_nitrogen_no_quadratic.png")
fig_nitrogen_no_quadratic = plot_contributions(no_quadratic_timeseries.times, no_quadratic_timeseries.data)
save(nitrogen_no_quadratic_figure_path, fig_nitrogen_no_quadratic; px_per_unit = 1)
fig_nitrogen_no_quadratic
