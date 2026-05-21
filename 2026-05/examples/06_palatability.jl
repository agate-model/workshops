# # [Exercise 06: Palatability] (@id palatability_exercise)
#
# Predator-prey palatability controls how strongly each zooplankton type grazes
# each phytoplankton type. This exercise follows the Agate.jl matrix example:
# first inspect the palatability matrices, then run each configuration in a box
# model and reuse the diagnostics introduced in Exercise 02.

# ## Loading dependencies

using Agate
using Agate.Introspection: interaction_matrix
using CairoMakie
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

# ## Construct palatability configurations
#
# The default model derives its palatability matrix allometrically. By default,
# zooplankton prefer prey that are 10 times smaller than themselves. We compare
# that default with two alternatives:
#
# - a different preferred predator:prey size ratio, `Vopt = 5`, for both
#   zooplankton types;
# - an explicit custom palatability matrix supplied directly.

bgc = default_quickstart_bgc()

vopt_bgc = Agate.Models.NiPiZD.construct(;
    parameters = (optimum_predator_prey_ratio = (Z1 = 5.0, Z2 = 5.0),),
)

custom_bgc = Agate.Models.NiPiZD.construct(;
    palatability_matrix = [0.0 1.0; 1.0 0.0],
)

bgcs = [bgc, vopt_bgc, custom_bgc]
case_labels = ["Vopt = 10", "Vopt = 5", "custom palatability"]

nothing #hide

# ## Palatability matrices
#
# `interaction_matrix(bgc, :palatability)` returns a labelled interaction table.
# Rows are consumers and columns are prey.

function plot_interaction_matrix!(fig, position, table; title)
    matrix = Matrix(table.matrix)
    nrows, ncols = size(matrix)

    ax = Axis(
        fig[position...];
        title,
        xlabel = string(table.column_axis),
        ylabel = string(table.row_axis),
        xticks = (1:ncols, string.(table.columns)),
        yticks = (1:nrows, string.(table.rows)),
        yreversed = true,
        aspect = DataAspect(),
    )

    hm = heatmap!(ax, 1:ncols, 1:nrows, matrix'; colorrange = (0, 1))

    for row in 1:nrows, col in 1:ncols
        text!(
            ax,
            col,
            row;
            text = string(round(matrix[row, col]; digits = 2)),
            align = (:center, :center),
            fontsize = 11,
        )
    end

    return hm
end

palatability_figure_path = joinpath("figures", "06_palatability_matrices.png")
fig_palatability = Figure(; size = (760, 280), fontsize = 12)

palatability_tables = [interaction_matrix(bgc, :palatability) for bgc in bgcs]
hm = plot_interaction_matrix!(fig_palatability, (1, 1), palatability_tables[1]; title = case_labels[1])
plot_interaction_matrix!(fig_palatability, (1, 2), palatability_tables[2]; title = case_labels[2])
plot_interaction_matrix!(fig_palatability, (1, 3), palatability_tables[3]; title = case_labels[3])
Colorbar(fig_palatability[1, 4], hm; label = "palatability")

save(palatability_figure_path, fig_palatability; px_per_unit = 1)
fig_palatability

# ## Run box models
#
# We use the same box-model wrapper as in Exercise 02 so the output can be read
# by the workshop diagnostics.

run = run_box_model(bgc; filename = joinpath("outputs", "06_palatability_default.jld2"))
vopt_run = run_box_model(vopt_bgc; filename = joinpath("outputs", "06_palatability_vopt5.jld2"))
custom_run = run_box_model(custom_bgc; filename = joinpath("outputs", "06_palatability_custom.jld2"))

timeseries = read_box_tracer_timeseries(run.filename, run.tracer_syms)
vopt_timeseries = read_box_tracer_timeseries(vopt_run.filename, vopt_run.tracer_syms)
custom_timeseries = read_box_tracer_timeseries(custom_run.filename, custom_run.tracer_syms)

times = timeseries.times
data = timeseries.data

nothing #hide

# ## Tracer concentrations
#
# First inspect the default configuration by itself.

tracer_concentrations_figure_path = joinpath("figures", "06_palatability_tracer_concentrations.png")
fig_tracers = plot_box_timeseries(timeseries)
save(tracer_concentrations_figure_path, fig_tracers; px_per_unit = 1)
fig_tracers

# ## Tracer concentration comparison
#
# The same diagnostic compares all three palatability configurations.

comparison_figure_path = joinpath("figures", "06_palatability_timeseries_comparison.png")
fig_comparison = plot_box_timeseries(
    [timeseries, vopt_timeseries, custom_timeseries];
    labels = case_labels,
)
save(comparison_figure_path, fig_comparison; px_per_unit = 1)
fig_comparison

# ## Relative nitrogen contributions
#
# The contribution diagnostic summarizes the default palatability run as living
# versus non-living nitrogen and phytoplankton versus zooplankton biomass.

nitrogen_contributions_figure_path = joinpath("figures", "06_palatability_relative_nitrogen_contributions.png")
fig_nitrogen = plot_contributions(times, data)
save(nitrogen_contributions_figure_path, fig_nitrogen; px_per_unit = 1)
fig_nitrogen

# ## Community-weighted mean size
#
# Palatability changes predator-prey coupling, so it can also shift the size
# structure of the simulated community.

cwm_size_figure_path = joinpath("figures", "06_palatability_cwm_size.png")
fig_size = plot_cwm_size(timeseries, bgc)
save(cwm_size_figure_path, fig_size; px_per_unit = 1)
fig_size

# ## Community-weighted mean size comparison
#
# Each time series is paired with its matching biogeochemistry object because the
# plankton sizes are defined on the model configuration.

cwm_size_comparison_figure_path = joinpath("figures", "06_palatability_cwm_size_comparison.png")
fig_size_comparison = plot_cwm_size(
    [timeseries, vopt_timeseries, custom_timeseries],
    bgcs;
    labels = case_labels,
)
save(cwm_size_comparison_figure_path, fig_size_comparison; px_per_unit = 1)
fig_size_comparison

# ## Parameter bars
#
# `Vopt` is a zooplankton parameter used to derive the allometric palatability
# matrix. The custom-matrix case supplies palatability directly, so its `Vopt`
# values remain at their defaults even though its realized interaction matrix is
# different.

parameter_bar_figure_path = joinpath("figures", "06_palatability_vopt_parameter_bars.png")
fig_vopt_parameter = plot_plankton_parameter_bars(
    bgcs,
    :optimum_predator_prey_ratio;
    labels = case_labels,
    ylabel = "optimum_predator_prey_ratio",
    title = "Preferred predator:prey size ratio by zooplankton type",
)
save(parameter_bar_figure_path, fig_vopt_parameter; px_per_unit = 1)
fig_vopt_parameter

# ## Exercises
#
# 1. Change the custom palatability matrix and rerun the comparison plots.
# 2. Change only one zooplankton `Vopt` value. Which prey and consumer respond most?
# 3. Compare the palatability matrix plot with the tracer and CWM diagnostics.
