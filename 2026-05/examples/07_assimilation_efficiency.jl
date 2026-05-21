# # [Exercise 07: Assimilation Efficiency] (@id assimilation_efficiency_exercise)
#
# Assimilation efficiency controls how efficiently consumed prey biomass is
# converted into zooplankton biomass. This exercise mirrors the palatability
# matrix exercise: first inspect the derived assimilation matrices, then run each
# configuration in a box model and compare the diagnostics introduced in
# Exercise 02.

# ## Loading dependencies

using Agate
using Agate.Introspection: interaction_matrix
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

# ## Construct assimilation-efficiency configurations
#
# Palatability controls which prey are consumed. Assimilation efficiency controls
# how much consumed prey biomass becomes zooplankton biomass. In the default
# model, `assimilation_efficiency` is defined for each zooplankton type and is
# expanded into a consumer-by-prey assimilation matrix.
#
# We compare three cases:
#
# - the default model;
# - a high-assimilation case, where both zooplankton types assimilate consumed
#   prey more efficiently;
# - a manual matrix case, where assimilation efficiency depends on both consumer
#   and prey identity.

bgc = default_quickstart_bgc()

default_assimilation_efficiency = bgc.parameters.assimilation_efficiency
println("Default assimilation efficiency: ", default_assimilation_efficiency)

high_assimilation_bgc = Agate.Models.NiPiZD.construct(;
    parameters = (assimilation_efficiency = (Z1 = 0.8, Z2 = 0.8),),
)

manual_matrix_bgc = Agate.Models.NiPiZD.construct(;
    assimilation_matrix = Float32[0.9 0.25; 0.25 0.9],
)

bgcs = [bgc, high_assimilation_bgc, manual_matrix_bgc]
case_labels = ["default", "high assimilation", "manual matrix"]

nothing #hide

# ## Assimilation matrices
#
# `interaction_matrix(bgc, :assimilation)` returns a labelled interaction table.
# Rows are consumers and columns are prey. The default and high-assimilation
# cases derive this matrix from the zooplankton `assimilation_efficiency`
# parameter. The manual-matrix case supplies the full matrix directly.

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

assimilation_figure_path = joinpath("figures", "07_assimilation_matrices.png")
fig_assimilation = Figure(; size = (760, 280), fontsize = 12)

assimilation_tables = [interaction_matrix(bgc, :assimilation) for bgc in bgcs]
hm = plot_interaction_matrix!(fig_assimilation, (1, 1), assimilation_tables[1]; title = case_labels[1])
plot_interaction_matrix!(fig_assimilation, (1, 2), assimilation_tables[2]; title = case_labels[2])
plot_interaction_matrix!(fig_assimilation, (1, 3), assimilation_tables[3]; title = case_labels[3])
Colorbar(fig_assimilation[1, 4], hm; label = "assimilation efficiency")

save(assimilation_figure_path, fig_assimilation; px_per_unit = 1)
fig_assimilation

# ## Run box models
#
# We use the same box-model wrapper as in Exercise 02 so the outputs can be read
# by the workshop diagnostics.

run = run_box_model(bgc; filename = joinpath("outputs", "07_assimilation_default.jld2"))
high_run = run_box_model(high_assimilation_bgc; filename = joinpath("outputs", "07_assimilation_high.jld2"))
manual_run = run_box_model(manual_matrix_bgc; filename = joinpath("outputs", "07_assimilation_manual_matrix.jld2"))

timeseries = read_box_tracer_timeseries(run.filename, run.tracer_syms)
high_timeseries = read_box_tracer_timeseries(high_run.filename, high_run.tracer_syms)
manual_timeseries = read_box_tracer_timeseries(manual_run.filename, manual_run.tracer_syms)

times = timeseries.times
data = timeseries.data

nothing #hide

# ## Tracer concentration comparison
#
# The concentration diagnostic compares all three assimilation-efficiency configurations.

comparison_figure_path = joinpath("figures", "07_assimilation_timeseries_comparison.png")
fig_comparison = plot_box_timeseries(
    [timeseries, high_timeseries, manual_timeseries];
    labels = case_labels,
)
save(comparison_figure_path, fig_comparison; px_per_unit = 1)
fig_comparison

# ## Relative nitrogen contributions: default assimilation

nitrogen_default_figure_path = joinpath("figures", "07_assimilation_relative_nitrogen_default.png")
fig_nitrogen_default = plot_contributions(timeseries.times, timeseries.data)
save(nitrogen_default_figure_path, fig_nitrogen_default; px_per_unit = 1)
fig_nitrogen_default

# ## Relative nitrogen contributions: high assimilation

nitrogen_high_figure_path = joinpath("figures", "07_assimilation_relative_nitrogen_high.png")
fig_nitrogen_high = plot_contributions(high_timeseries.times, high_timeseries.data)
save(nitrogen_high_figure_path, fig_nitrogen_high; px_per_unit = 1)
fig_nitrogen_high

# ## Relative nitrogen contributions: manual matrix

nitrogen_manual_figure_path = joinpath("figures", "07_assimilation_relative_nitrogen_manual_matrix.png")
fig_nitrogen_manual = plot_contributions(manual_timeseries.times, manual_timeseries.data)
save(nitrogen_manual_figure_path, fig_nitrogen_manual; px_per_unit = 1)
fig_nitrogen_manual

# ## Community-weighted mean size comparison
#
# Each time series is paired with its matching biogeochemistry object because
# plankton sizes are defined on the model configuration.

cwm_size_comparison_figure_path = joinpath("figures", "07_assimilation_cwm_size_comparison.png")
fig_size_comparison = plot_cwm_size(
    [timeseries, high_timeseries, manual_timeseries],
    bgcs;
    labels = case_labels,
)
save(cwm_size_comparison_figure_path, fig_size_comparison; px_per_unit = 1)
fig_size_comparison

# ## Exercises
#
# 1. Change the high-assimilation values for only one zooplankton type and rerun
#    the comparison plots.
# 2. Change one entry in the manual assimilation matrix. Which tracer responds
#    most strongly?
# 3. Compare the matrix heatmaps with the diagnostic plots. Which differences
#    appear in the realized ecosystem trajectories?
