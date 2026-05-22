# # [Exercise 04: Number size classes] (@id number_size_classes_exercise)
#
# This exercise changes the number of phytoplankton and zooplankton size
# classes in the Agate.jl NiPiZD model. The total initial plankton biomass is
# held fixed and split evenly across the available plankton tracers, so the
# comparison isolates the effect of resolving more size classes.

# ## Loading dependencies

using Agate
using Agate.Introspection: tracer_names
using CairoMakie

using AgateWorkshop

mkpath("outputs")
mkpath("figures")

nothing #hide

# ## Number-of-classes cases
#
# The default model has two phytoplankton classes and two zooplankton classes.
# The alternative cases keep the same broad phytoplankton and zooplankton size
# ranges and logarithmic spacing, but increase both groups to five and ten
# classes.

default_phyto_size_structure = (n = 2, min_esd = 2, max_esd = 10, splitting = :log_splitting)
default_zoo_size_structure = (n = 2, min_esd = 20, max_esd = 100, splitting = :linear_splitting)

function construct_size_class_bgc(n)
    return Agate.Models.NiPiZD.construct(;
        phyto_size_structure = (; default_phyto_size_structure..., n),
        zoo_size_structure = (; default_zoo_size_structure..., n),
    )
end

bgc_default = Agate.Models.NiPiZD.construct(;
    phyto_size_structure = default_phyto_size_structure,
    zoo_size_structure = default_zoo_size_structure,
)
bgc_5_each = construct_size_class_bgc(5)
bgc_10_each = construct_size_class_bgc(10)

bgcs = [bgc_default, bgc_5_each, bgc_10_each]
case_labels = ["default: 2 P, 2 Z", "5 P, 5 Z", "10 P, 10 Z"]

for (label, bgc) in zip(case_labels, bgcs)
    println(label)
    println(tracer_names(bgc))
end

nothing #hide

# ## Run zero-dimensional ecosystem simulations
#
# `default_initial_conditions` distributes the same total plankton biomass evenly
# across whichever plankton tracers are present in each configuration.

runs = [
    run_box_model(
        bgc;
        filename = joinpath("outputs", "04_number_size_classes_$(i).jld2"),
        initial_conditions = default_initial_conditions(bgc; nutrient = 8.0, total_plankton_biomass = 0.15),
    )
    for (i, bgc) in enumerate(bgcs)
]

timeseries = [read_box_tracer_timeseries(run.filename, run.tracer_syms) for run in runs]

nothing #hide

# ## Tracer concentration comparison
#
# This diagnostic compares the tracer set across the three configurations. Tracers that exist only in the higher-resolution cases appear only for those cases.

comparison_variables = sort!(unique(vcat([collect(keys(ts.data)) for ts in timeseries]...)); by = string)
comparison_figure_path = joinpath("figures", "04_number_size_classes_timeseries_comparison.png")
fig_comparison = plot_box_timeseries(timeseries; labels = case_labels, variables = comparison_variables)
save(comparison_figure_path, fig_comparison; px_per_unit = 1)
fig_comparison

# ## Relative nitrogen contributions: default size classes

nitrogen_default_figure_path = joinpath("figures", "04_number_size_classes_relative_nitrogen_default.png")
fig_nitrogen_default = plot_contributions(timeseries[1].times, timeseries[1].data)
save(nitrogen_default_figure_path, fig_nitrogen_default; px_per_unit = 1)
fig_nitrogen_default

# ## Relative nitrogen contributions: five classes each

nitrogen_5_figure_path = joinpath("figures", "04_number_size_classes_relative_nitrogen_5_each.png")
fig_nitrogen_5 = plot_contributions(timeseries[2].times, timeseries[2].data)
save(nitrogen_5_figure_path, fig_nitrogen_5; px_per_unit = 1)
fig_nitrogen_5

# ## Relative nitrogen contributions: ten classes each

nitrogen_10_figure_path = joinpath("figures", "04_number_size_classes_relative_nitrogen_10_each.png")
fig_nitrogen_10 = plot_contributions(timeseries[3].times, timeseries[3].data)
save(nitrogen_10_figure_path, fig_nitrogen_10; px_per_unit = 1)
fig_nitrogen_10

# ## Community-weighted mean size comparison

size_comparison_figure_path = joinpath("figures", "04_number_size_classes_cwm_size_comparison.png")
fig_size_comparison = plot_cwm_size(timeseries, bgcs; labels = case_labels)
save(size_comparison_figure_path, fig_size_comparison; px_per_unit = 1)
fig_size_comparison
