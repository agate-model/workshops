# # [Exercise 03: Allometric scaling] (@id allometric_scaling_exercise)
#
# This exercise changes allometric scaling in the Agate.jl NiPiZD model.
# We inspect the plankton parameter values produced by different allometric coefficients, then run each case in a well-mixed zero-dimensional box.
#
# Agate.jl represents allometric parameter rules as a power law on spherical cell volume:
#
# ```math
# \mathrm{trait} = a V^b, \qquad V = \frac{4}{3}\pi\left(\frac{d}{2}\right)^3
# ```
#
# where `d` is equivalent spherical diameter (ESD), `a` is the `prefactor`, and `b` is the `exponent`.
# Changing `a` shifts the whole curve up or down; changing `b` changes how strongly the trait depends on plankton size.
#
# In this exercise we focus on three size-dependent parameters.
# `mumax` is the maximum phytoplankton growth rate.
# `kN` is the nutrient half-saturation concentration: lower values mean growth saturates at lower nutrient concentration.
# `gmax` is the maximum zooplankton predation rate.

# ## Loading dependencies
#
# The example uses Agate.jl, Oceananigans.jl, and OceanBioME.jl for the ecosystem simulation.
# CairoMakie.jl is used for plotting.

using Agate
using Agate.Introspection: plankton_groups
using Agate.Library.Allometry: AllometricParam, PowerLaw
using Oceananigans
using Oceananigans.Units
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

# ## Allometry cases
#
# We start with the default allometric coefficients, then construct two alternatives:
# a flat case where the selected parameters do not vary with plankton size, and a
# stronger small-fast case where smaller plankton have higher growth and predation rates.

bgc_default = Agate.Models.NiPiZD.construct()

println("Plankton groups: ", plankton_groups(bgc_default))

bgc_flat = Agate.Models.NiPiZD.construct(;
    parameters = (
        maximum_growth_rate = AllometricParam(PowerLaw(); prefactor = 2 / day, exponent = 0.0),
        nutrient_half_saturation = AllometricParam(PowerLaw(); prefactor = 0.17, exponent = 0.0),
        maximum_predation_rate = AllometricParam(PowerLaw(); prefactor = 30.84 / day, exponent = 0.0),
    ),
)

bgc_strong_small_fast = Agate.Models.NiPiZD.construct(;
    parameters = (
        maximum_growth_rate = AllometricParam(PowerLaw(); prefactor = 2 / day, exponent = -0.35),
        nutrient_half_saturation = AllometricParam(PowerLaw(); prefactor = 0.17, exponent = 0.35),
        maximum_predation_rate = AllometricParam(PowerLaw(); prefactor = 30.84 / day, exponent = -0.35),
    ),
)

bgc_cases = [bgc_default, bgc_flat, bgc_strong_small_fast]
bgc_case_labels = ["Default", "Flat", "Strong small-fast"]

# ## Parameter bar charts
#
# `plot_plankton_parameter_bars` accepts one model or an array of models. When an
# array is provided, it draws grouped bars so the same plankton type can be compared
# across parameter sets.

fig_mumax = plot_plankton_parameter_bars(
    bgc_cases,
    :maximum_growth_rate;
    labels = bgc_case_labels,
    ylabel = "maximum_growth_rate",
    title = "Maximum growth rate by phytoplankton type",
    figure_path = joinpath("figures", "03_mumax_parameter_bars.png"),
)
fig_mumax

fig_kN = plot_plankton_parameter_bars(
    bgc_cases,
    :nutrient_half_saturation;
    labels = bgc_case_labels,
    ylabel = "nutrient_half_saturation",
    title = "Nutrient half-saturation by phytoplankton type",
    figure_path = joinpath("figures", "03_kN_parameter_bars.png"),
)
fig_kN

fig_gmax = plot_plankton_parameter_bars(
    bgc_cases,
    :maximum_predation_rate;
    labels = bgc_case_labels,
    ylabel = "maximum_predation_rate",
    title = "Maximum predation rate by zooplankton type",
    figure_path = joinpath("figures", "03_gmax_parameter_bars.png"),
)
fig_gmax

# ## Zero-dimensional ecosystem simulations
#
# The parameter plots show potential rates.
# We now run the same three allometric cases in a well-mixed box model and compare the ecosystem dynamics.

# Run the default case.
default_run = run_box_model(
    bgc_default;
    filename = joinpath("outputs", "03_default.jld2"),
    initial_conditions = default_initial_conditions(bgc_default; nutrient = 8.0, total_plankton_biomass = 0.08),
)
default_filename = default_run.filename

# Run the flat-allometry case.
flat_run = run_box_model(
    bgc_flat;
    filename = joinpath("outputs", "03_flat.jld2"),
    initial_conditions = default_initial_conditions(bgc_flat; nutrient = 8.0, total_plankton_biomass = 0.08),
)
flat_filename = flat_run.filename

# Run the strong small-fast case.
strong_run = run_box_model(
    bgc_strong_small_fast;
    filename = joinpath("outputs", "03_strong_small_fast.jld2"),
    initial_conditions = default_initial_conditions(bgc_strong_small_fast; nutrient = 8.0, total_plankton_biomass = 0.08),
)
strong_filename = strong_run.filename

nothing #hide

# ## Diagnostic plots
#
# The simulations are compared with the reusable diagnostics introduced in Exercise 02.
# `plot_box_timeseries` compares tracer concentrations, `plot_contributions` shows
# relative nitrogen partitioning for each allometric configuration, and
# `plot_cwm_size` compares community-weighted mean plankton sizes.

default_timeseries = read_box_tracer_timeseries(default_run.filename, default_run.tracer_syms)
flat_timeseries = read_box_tracer_timeseries(flat_run.filename, flat_run.tracer_syms)
strong_timeseries = read_box_tracer_timeseries(strong_run.filename, strong_run.tracer_syms)

comparison_figure_path = joinpath("figures", "03_allometry_timeseries_comparison.png")
fig_comparison = plot_box_timeseries(
    [default_timeseries, flat_timeseries, strong_timeseries];
    labels = bgc_case_labels,
)
save(comparison_figure_path, fig_comparison; px_per_unit = 1)
fig_comparison

# ### Relative nitrogen contributions: default allometry

nitrogen_default_figure_path = joinpath("figures", "03_allometry_relative_nitrogen_default.png")
fig_nitrogen_default = plot_contributions(default_timeseries.times, default_timeseries.data)
save(nitrogen_default_figure_path, fig_nitrogen_default; px_per_unit = 1)
fig_nitrogen_default

# ### Relative nitrogen contributions: flat allometry

nitrogen_flat_figure_path = joinpath("figures", "03_allometry_relative_nitrogen_flat.png")
fig_nitrogen_flat = plot_contributions(flat_timeseries.times, flat_timeseries.data)
save(nitrogen_flat_figure_path, fig_nitrogen_flat; px_per_unit = 1)
fig_nitrogen_flat

# ### Relative nitrogen contributions: strong small-fast allometry

nitrogen_strong_figure_path = joinpath("figures", "03_allometry_relative_nitrogen_strong_small_fast.png")
fig_nitrogen_strong = plot_contributions(strong_timeseries.times, strong_timeseries.data)
save(nitrogen_strong_figure_path, fig_nitrogen_strong; px_per_unit = 1)
fig_nitrogen_strong

# ### Community-weighted mean size comparison

cwm_size_comparison_figure_path = joinpath("figures", "03_allometry_cwm_size_comparison.png")
fig_size_comparison = plot_cwm_size(
    [default_timeseries, flat_timeseries, strong_timeseries],
    bgc_cases;
    labels = bgc_case_labels,
)
save(cwm_size_comparison_figure_path, fig_size_comparison; px_per_unit = 1)
fig_size_comparison

# ## Exercises
#
# 1. In the parameter bar charts, which plankton types have the largest `mumax`, `kN`, and `gmax` values?
# 2. In the flat allometry case, which differences remain among the plankton tracers, and which disappear?
# 3. In the strong small-fast case, how do the selected parameter values change for the smallest and largest plankton?
# 4. Compare the ecosystem dynamics. Which allometric choice produces the largest total phytoplankton biomass, and when?