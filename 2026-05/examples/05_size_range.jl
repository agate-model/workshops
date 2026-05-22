# # [Exercise 05: Size range] (@id size_range_exercise)
#
# This exercise changes the size ranges represented by the Agate.jl NiPiZD
# model. We compare the default two-phytoplankton, two-zooplankton community
# with a wider but physiologically realistic range for both trophic groups.

# ## Loading dependencies

using Agate
using Agate.Introspection: tracer_names
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

mkpath("outputs")
mkpath("figures")

nothing #hide

# ## Size-range cases
#
# The wide-range case keeps two classes per trophic group and logarithmic spacing,
# but expands the endpoints to include small picophytoplankton through large
# microphytoplankton, and microzooplankton through small mesozooplankton.

bgc_default = default_quickstart_bgc()

bgc_wide_range = Agate.Models.NiPiZD.construct(;
    phyto_size_structure = (n = 2, min_esd = 0.6, max_esd = 60.0, splitting = :log_splitting),
    zoo_size_structure = (n = 2, min_esd = 6.0, max_esd = 600.0, splitting = :log_splitting),
)

bgcs = [bgc_default, bgc_wide_range]
case_labels = ["default size range", "wide realistic size range"]

for (label, bgc) in zip(case_labels, bgcs)
    println(label)
    println(tracer_names(bgc))
end

nothing #hide

# ## Run zero-dimensional ecosystem simulations
#
# Total initial plankton biomass is the same in both cases and is split evenly
# across the plankton tracers.

runs = [
    run_box_model(
        bgc;
        filename = joinpath("outputs", "05_size_range_$(i).jld2"),
        initial_conditions = default_initial_conditions(bgc; nutrient = 8.0, total_plankton_biomass = 0.15),
    )
    for (i, bgc) in enumerate(bgcs)
]

timeseries = [read_box_tracer_timeseries(run.filename, run.tracer_syms) for run in runs]

nothing #hide

# ## Tracer concentration comparison

comparison_figure_path = joinpath("figures", "05_size_range_timeseries_comparison.png")
fig_comparison = plot_box_timeseries(timeseries; labels = case_labels)
save(comparison_figure_path, fig_comparison; px_per_unit = 1)
fig_comparison

# ## Relative nitrogen contributions: default size range

nitrogen_default_figure_path = joinpath("figures", "05_size_range_relative_nitrogen_default.png")
fig_nitrogen_default = plot_contributions(timeseries[1].times, timeseries[1].data)
save(nitrogen_default_figure_path, fig_nitrogen_default; px_per_unit = 1)
fig_nitrogen_default

# ## Relative nitrogen contributions: wide realistic size range

nitrogen_wide_figure_path = joinpath("figures", "05_size_range_relative_nitrogen_wide.png")
fig_nitrogen_wide = plot_contributions(timeseries[2].times, timeseries[2].data)
save(nitrogen_wide_figure_path, fig_nitrogen_wide; px_per_unit = 1)
fig_nitrogen_wide

# ## Community-weighted mean size comparison

size_comparison_figure_path = joinpath("figures", "05_size_range_cwm_size_comparison.png")
fig_size_comparison = plot_cwm_size(timeseries, bgcs; labels = case_labels)
save(size_comparison_figure_path, fig_size_comparison; px_per_unit = 1)
fig_size_comparison
