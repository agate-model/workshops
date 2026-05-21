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

function plankton_initial_conditions(bgc; phyto = 0.03, zoo = 0.01)
    groups = plankton_groups(bgc)
    pairs = Pair{Symbol,Float64}[]

    for tracer in groups.P
        push!(pairs, tracer => phyto)
    end

    for tracer in groups.Z
        push!(pairs, tracer => zoo)
    end

    return (; pairs...)
end

# Run the default case.
default_run = run_box_model(
    bgc_default;
    filename = joinpath("outputs", "03_default.jld2"),
    initial_conditions = (N = 8.0, D = 0.01, plankton_initial_conditions(bgc_default)...),
)
default_filename = default_run.filename

# Run the flat-allometry case.
flat_run = run_box_model(
    bgc_flat;
    filename = joinpath("outputs", "03_flat.jld2"),
    initial_conditions = (N = 8.0, D = 0.01, plankton_initial_conditions(bgc_flat)...),
)
flat_filename = flat_run.filename

# Run the strong small-fast case.
strong_run = run_box_model(
    bgc_strong_small_fast;
    filename = joinpath("outputs", "03_strong_small_fast.jld2"),
    initial_conditions = (N = 8.0, D = 0.01, plankton_initial_conditions(bgc_strong_small_fast)...),
)
strong_filename = strong_run.filename

nothing #hide

# ## Plot ecosystem dynamics
#
# We summarize each simulation by plotting nutrient, total phytoplankton, total zooplankton, and detritus.
# The P and Z totals use the model's plankton group metadata, so the plotting still works if the size structure changes.

function read_box_totals(filename, bgc)
    P = plankton_groups(bgc).P
    Z = plankton_groups(bgc).Z
    times = FieldTimeSeries(filename, "N").times ./ day
    N = FieldTimeSeries(filename, "N")[1, 1, 1, :]
    D = FieldTimeSeries(filename, "D")[1, 1, 1, :]

    total_tracer_group(tracers) = sum(FieldTimeSeries(filename, string(tracer))[1, 1, 1, :] for tracer in tracers)

    return (;
        times = collect(times),
        N = collect(N),
        P = collect(total_tracer_group(P)),
        Z = collect(total_tracer_group(Z)),
        D = collect(D),
    )
end

default_dynamics = read_box_totals(default_filename, bgc_default)
flat_dynamics = read_box_totals(flat_filename, bgc_flat)
strong_dynamics = read_box_totals(strong_filename, bgc_strong_small_fast)

fig_dynamics = Figure(; size = (600, 480), fontsize = 12)

axN = Axis(fig_dynamics[1, 1]; xlabel = "Time (days)", ylabel = "N (mmol N m⁻³)", title = "Nutrient")
axP = Axis(fig_dynamics[1, 2]; xlabel = "Time (days)", ylabel = "P (mmol N m⁻³)", title = "Total phytoplankton")
axZ = Axis(fig_dynamics[2, 1]; xlabel = "Time (days)", ylabel = "Z (mmol N m⁻³)", title = "Total zooplankton")
axD = Axis(fig_dynamics[2, 2]; xlabel = "Time (days)", ylabel = "D (mmol N m⁻³)", title = "Detritus")

lines!(axN, default_dynamics.times, default_dynamics.N; label = "Default")
lines!(axN, flat_dynamics.times, flat_dynamics.N; label = "Flat")
lines!(axN, strong_dynamics.times, strong_dynamics.N; label = "Strong small-fast")

lines!(axP, default_dynamics.times, default_dynamics.P; label = "Default")
lines!(axP, flat_dynamics.times, flat_dynamics.P; label = "Flat")
lines!(axP, strong_dynamics.times, strong_dynamics.P; label = "Strong small-fast")

lines!(axZ, default_dynamics.times, default_dynamics.Z; label = "Default")
lines!(axZ, flat_dynamics.times, flat_dynamics.Z; label = "Flat")
lines!(axZ, strong_dynamics.times, strong_dynamics.Z; label = "Strong small-fast")

lines!(axD, default_dynamics.times, default_dynamics.D; label = "Default")
lines!(axD, flat_dynamics.times, flat_dynamics.D; label = "Flat")
lines!(axD, strong_dynamics.times, strong_dynamics.D; label = "Strong small-fast")

axislegend(axN; position = :rt)
save(joinpath("figures", "03_ecosystem_dynamics.png"), fig_dynamics; px_per_unit=1)
fig_dynamics

# ## Exercises
#
# 1. In the parameter bar charts, which plankton types have the largest `mumax`, `kN`, and `gmax` values?
# 2. In the flat allometry case, which differences remain among the plankton tracers, and which disappear?
# 3. In the strong small-fast case, how do the selected parameter values change for the smallest and largest plankton?
# 4. Compare the ecosystem dynamics. Which allometric choice produces the largest total phytoplankton biomass, and when?