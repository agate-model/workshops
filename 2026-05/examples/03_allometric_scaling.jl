# # [Exercise 03: Allometric scaling] (@id allometric_scaling_exercise)
#
# This exercise changes allometric scaling in the Agate.jl NiPiZD model.
# We inspect the trait curves produced by different allometric coefficients, then run each case in a well-mixed zero-dimensional box.
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
using Agate.Introspection: plankton_diameters, plankton_groups, plankton_tracers
using Agate.Library.Allometry: AllometricParam, PowerLaw
using Agate.Library.Light
using OceanBioME
using OceanBioME: Biogeochemistry
using Oceananigans
using Oceananigans.Units
using CairoMakie

mkpath("outputs")
mkpath("figures")

nothing #hide

# ## Plankton sizes
#
# The Agate.jl-NiPiZD model stores plankton ESD metadata on constructed biogeochemistry objects.
# The introspection helpers keep tracer labels and diameters aligned, so plotting code does not need to duplicate the model's size structure.

function plankton_diameter_lookup(bgc)
    return Dict(plankton_tracers(bgc) .=> plankton_diameters(bgc))
end

function group_tracer_diameters(bgc, group::Symbol)
    lookup = plankton_diameter_lookup(bgc)
    return [lookup[tracer] for tracer in getproperty(plankton_groups(bgc), group)]
end

function allometric_diameter_range(bgc; length = 200)
    diameters = plankton_diameters(bgc)
    return exp.(range(log(minimum(diameters) / 2), log(maximum(diameters) * 1.2); length))
end

cell_volume(d) = 4 / 3 * π * (d / 2)^3
power_law(diameters; prefactor, exponent) = prefactor .* cell_volume.(diameters) .^ exponent

nothing #hide

# ## Default allometry
#
# We start with the default allometric coefficients.
# Rates are specified using Oceananigans units, for example `2 / day`, rather than manually converting from seconds.

bgc_default = Agate.Models.NiPiZD.construct()

println("Plankton tracers: ", plankton_tracers(bgc_default))
println("Plankton diameters: ", plankton_diameters(bgc_default), " μm")

mumax_default_a = 2 / day
mumax_default_b = -0.15
kN_default_a = 0.17
kN_default_b = 0.27
gmax_default_a = 30.84 / day
gmax_default_b = -0.16

# The phytoplankton parameters are plotted at phytoplankton diameters, and the zooplankton parameter is plotted at zooplankton diameters.
# These are inferred from the constructed model rather than written out by hand.

function parameter_values_for_group(bgc, group::Symbol, values)
    tracers = collect(getproperty(plankton_groups(bgc), group))
    all_tracers = collect(plankton_tracers(bgc))
    values = collect(values)

    if length(values) == length(tracers)
        return values
    elseif length(values) == length(all_tracers)
        lookup = Dict(all_tracers .=> values)
        return [lookup[tracer] for tracer in tracers]
    else
        error("Cannot align $(length(values)) parameter values with $(length(tracers)) $(group) tracers.")
    end
end

function allometry_case(bgc; mumax_prefactor, mumax_exponent, kN_prefactor, kN_exponent, gmax_prefactor, gmax_exponent)
    P = collect(plankton_groups(bgc).P)
    Z = collect(plankton_groups(bgc).Z)
    P_diameters = group_tracer_diameters(bgc, :P)
    Z_diameters = group_tracer_diameters(bgc, :Z)
    curve_diameters = allometric_diameter_range(bgc)

    return (
        mumax = (
            title = "mumax",
            tracers = P,
            diameters = P_diameters,
            values = parameter_values_for_group(bgc, :P, bgc.parameters.maximum_growth_rate) .* day,
            curve = power_law(curve_diameters; prefactor = mumax_prefactor, exponent = mumax_exponent) .* day,
            ylabel = "mumax (d⁻¹)",
        ),
        kN = (
            title = "kN",
            tracers = P,
            diameters = P_diameters,
            values = parameter_values_for_group(bgc, :P, bgc.parameters.nutrient_half_saturation),
            curve = power_law(curve_diameters; prefactor = kN_prefactor, exponent = kN_exponent),
            ylabel = "kN",
        ),
        gmax = (
            title = "gmax",
            tracers = Z,
            diameters = Z_diameters,
            values = parameter_values_for_group(bgc, :Z, bgc.parameters.maximum_predation_rate) .* day,
            curve = power_law(curve_diameters; prefactor = gmax_prefactor, exponent = gmax_exponent) .* day,
            ylabel = "gmax (d⁻¹)",
        ),
        curve_diameters = curve_diameters,
    )
end

function plot_allometry_case(bgc; label, filename, kwargs...)
    case = allometry_case(bgc; kwargs...)
    traits = (case.mumax, case.kN, case.gmax)

    fig = Figure(; size = (1050, 420), fontsize = 16)

    for (column, trait) in enumerate(traits)
        ax = Axis(
            fig[1, column];
            xlabel = "Diameter (μm ESD)",
            ylabel = trait.ylabel,
            title = "$label $(trait.title)",
            xscale = log10,
        )

        lines!(ax, case.curve_diameters, trait.curve)
        scatter!(ax, trait.diameters, trait.values; markersize = 14)
        text!(
            ax,
            trait.diameters,
            trait.values;
            text = string.(trait.tracers),
            align = (:left, :bottom),
            offset = (5, 5),
        )
    end

    save(filename, fig)
    return fig
end

fig_default = plot_allometry_case(
    bgc_default;
    label = "Default",
    filename = joinpath("figures", "03_default_allometry.png"),
    mumax_prefactor = mumax_default_a,
    mumax_exponent = mumax_default_b,
    kN_prefactor = kN_default_a,
    kN_exponent = kN_default_b,
    gmax_prefactor = gmax_default_a,
    gmax_exponent = gmax_default_b,
)
fig_default

# ## Flat allometry
#
# Next we set the exponent `b` to zero for `mumax`, `kN`, and `gmax`.
# The parameter values no longer depend on size, so each curve is horizontal.

bgc_flat = Agate.Models.NiPiZD.construct(;
    parameters = (
        maximum_growth_rate = AllometricParam(PowerLaw(); prefactor = 2 / day, exponent = 0.0),
        nutrient_half_saturation = AllometricParam(PowerLaw(); prefactor = 0.17, exponent = 0.0),
        maximum_predation_rate = AllometricParam(PowerLaw(); prefactor = 30.84 / day, exponent = 0.0),
    ),
)

fig_flat = plot_allometry_case(
    bgc_flat;
    label = "Flat",
    filename = joinpath("figures", "03_flat_allometry.png"),
    mumax_prefactor = 2 / day,
    mumax_exponent = 0.0,
    kN_prefactor = 0.17,
    kN_exponent = 0.0,
    gmax_prefactor = 30.84 / day,
    gmax_exponent = 0.0,
)
fig_flat

# ## Strong small-fast allometry
#
# Finally we make the size dependence stronger.
# Negative `mumax` and `gmax` exponents make smaller plankton grow and graze faster.
# A positive `kN` exponent makes larger phytoplankton require higher nutrient concentration to approach maximum growth.

bgc_strong_small_fast = Agate.Models.NiPiZD.construct(;
    parameters = (
        maximum_growth_rate = AllometricParam(PowerLaw(); prefactor = 2 / day, exponent = -0.35),
        nutrient_half_saturation = AllometricParam(PowerLaw(); prefactor = 0.17, exponent = 0.35),
        maximum_predation_rate = AllometricParam(PowerLaw(); prefactor = 30.84 / day, exponent = -0.35),
    ),
)

fig_strong = plot_allometry_case(
    bgc_strong_small_fast;
    label = "Strong small-fast",
    filename = joinpath("figures", "03_strong_small_fast_allometry.png"),
    mumax_prefactor = 2 / day,
    mumax_exponent = -0.35,
    kN_prefactor = 0.17,
    kN_exponent = 0.35,
    gmax_prefactor = 30.84 / day,
    gmax_exponent = -0.35,
)
fig_strong

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

function run_box_model(bgc; filename)
    light_attenuation = FunctionFieldPAR(; grid = BoxModelGrid())
    bgc_model = Biogeochemistry(bgc; light_attenuation)
    full_model = BoxModel(; biogeochemistry = bgc_model)

    set!(full_model; N = 8.0, D = 0.01, plankton_initial_conditions(bgc)...)

    simulation = Simulation(full_model; Δt = 240minutes, stop_time = 1095days)

    simulation.output_writers[:fields] = JLD2Writer(
        full_model,
        full_model.fields;
        filename,
        schedule = TimeInterval(1day),
        overwrite_existing = true,
    )

    run!(simulation)

    return filename
end

# Run the default case.
default_filename = run_box_model(bgc_default; filename = joinpath("outputs", "03_default.jld2"))

# Run the flat-allometry case.
flat_filename = run_box_model(bgc_flat; filename = joinpath("outputs", "03_flat.jld2"))

# Run the strong small-fast case.
strong_filename = run_box_model(bgc_strong_small_fast; filename = joinpath("outputs", "03_strong_small_fast.jld2"))

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

fig_dynamics = Figure(; size = (950, 760), fontsize = 16)

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
save(joinpath("figures", "03_ecosystem_dynamics.png"), fig_dynamics)
fig_dynamics

# ## Exercises
#
# 1. In the default allometry figure, which plankton sizes have the largest `mumax`, `kN`, and `gmax` values?
# 2. In the flat allometry figure, which differences remain among the four plankton tracers, and which disappear?
# 3. In the strong small-fast figure, how does making `b` more negative change the smallest and largest plankton?
# 4. Compare the ecosystem dynamics. Which allometric choice produces the largest total phytoplankton biomass, and when?