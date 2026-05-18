# # [Exercise 01: Allometric scaling] (@id allometric_scaling_exercise)
#
# This exercise changes allometric scaling in the [Agate.jl-NiPiZD](@ref NiPiZD) model.
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
using Agate.Introspection: plankton_tracers
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
# The default Agate.jl-NiPiZD phytoplankton sizes are 2 and 10 μm ESD.
# The default zooplankton sizes are 20 and 100 μm ESD.
# We define those diameters explicitly, use them for plotting, and pass them to `construct` so the plotted sizes and model sizes are identical.

phyto_diameters = [2.0, 10.0]
zoo_diameters = [20.0, 100.0]

plankton_diameters = Dict(:P1 => 2.0, :P2 => 10.0, :Z1 => 20.0, :Z2 => 100.0)

allometric_diameters = exp.(range(log(1.0), log(120.0); length = 200))

cell_volume(d) = 4 / 3 * π * (d / 2)^3
power_law(diameters; prefactor, exponent) = prefactor .* cell_volume.(diameters) .^ exponent

nothing #hide

# ## Default allometry
#
# We start with the default allometric coefficients.
# Rates are specified using Oceananigans units, for example `2 / day`, rather than manually converting from seconds.

bgc_default = Agate.Models.NiPiZD.construct(;
    phyto_size_structure = phyto_diameters,
    zoo_size_structure = zoo_diameters,
)

plankton = plankton_tracers(bgc_default)
println("Plankton tracers: ", plankton)

mumax_default_a = 2 / day
mumax_default_b = -0.15
kN_default_a = 0.17
kN_default_b = 0.27
gmax_default_a = 30.84 / day
gmax_default_b = -0.16

mumax_default_curve = power_law(allometric_diameters; prefactor = mumax_default_a, exponent = mumax_default_b) .* day
kN_default_curve = power_law(allometric_diameters; prefactor = kN_default_a, exponent = kN_default_b)
gmax_default_curve = power_law(allometric_diameters; prefactor = gmax_default_a, exponent = gmax_default_b) .* day

plankton_sizes = [plankton_diameters[p] for p in plankton]
mumax_default = bgc_default.parameters.maximum_growth_rate .* day
kN_default = bgc_default.parameters.nutrient_half_saturation
gmax_default = bgc_default.parameters.maximum_predation_rate .* day

fig_default = Figure(; size = (1050, 420), fontsize = 16)
ax_mumax_default = Axis(fig_default[1, 1]; xlabel = "Diameter (μm ESD)", ylabel = "mumax (d⁻¹)", title = "Default mumax", xscale = log10)
ax_kN_default = Axis(fig_default[1, 2]; xlabel = "Diameter (μm ESD)", ylabel = "kN", title = "Default kN", xscale = log10)
ax_gmax_default = Axis(fig_default[1, 3]; xlabel = "Diameter (μm ESD)", ylabel = "gmax (d⁻¹)", title = "Default gmax", xscale = log10)

lines!(ax_mumax_default, allometric_diameters, mumax_default_curve)
scatter!(ax_mumax_default, plankton_sizes, mumax_default; markersize = 14)
text!(ax_mumax_default, plankton_sizes, mumax_default; text = string.(plankton), align = (:left, :bottom), offset = (5, 5))

lines!(ax_kN_default, allometric_diameters, kN_default_curve)
scatter!(ax_kN_default, plankton_sizes, kN_default; markersize = 14)
text!(ax_kN_default, plankton_sizes, kN_default; text = string.(plankton), align = (:left, :bottom), offset = (5, 5))

lines!(ax_gmax_default, allometric_diameters, gmax_default_curve)
scatter!(ax_gmax_default, plankton_sizes, gmax_default; markersize = 14)
text!(ax_gmax_default, plankton_sizes, gmax_default; text = string.(plankton), align = (:left, :bottom), offset = (5, 5))

save("figures/01_default_allometry.png", fig_default)
fig_default

# ## Flat allometry
#
# Next we set the exponent `b` to zero for `mumax`, `kN`, and `gmax`.
# The parameter values no longer depend on size, so each curve is horizontal.

bgc_flat = Agate.Models.NiPiZD.construct(;
    phyto_size_structure = phyto_diameters,
    zoo_size_structure = zoo_diameters,
    parameters = (
        maximum_growth_rate = AllometricParam(PowerLaw(); prefactor = 2 / day, exponent = 0.0),
        nutrient_half_saturation = AllometricParam(PowerLaw(); prefactor = 0.17, exponent = 0.0),
        maximum_predation_rate = AllometricParam(PowerLaw(); prefactor = 30.84 / day, exponent = 0.0),
    ),
)

mumax_flat_curve = power_law(allometric_diameters; prefactor = 2 / day, exponent = 0.0) .* day
kN_flat_curve = power_law(allometric_diameters; prefactor = 0.17, exponent = 0.0)
gmax_flat_curve = power_law(allometric_diameters; prefactor = 30.84 / day, exponent = 0.0) .* day

mumax_flat = bgc_flat.parameters.maximum_growth_rate .* day
kN_flat = bgc_flat.parameters.nutrient_half_saturation
gmax_flat = bgc_flat.parameters.maximum_predation_rate .* day

fig_flat = Figure(; size = (1050, 420), fontsize = 16)
ax_mumax_flat = Axis(fig_flat[1, 1]; xlabel = "Diameter (μm ESD)", ylabel = "mumax (d⁻¹)", title = "Flat mumax", xscale = log10)
ax_kN_flat = Axis(fig_flat[1, 2]; xlabel = "Diameter (μm ESD)", ylabel = "kN", title = "Flat kN", xscale = log10)
ax_gmax_flat = Axis(fig_flat[1, 3]; xlabel = "Diameter (μm ESD)", ylabel = "gmax (d⁻¹)", title = "Flat gmax", xscale = log10)

lines!(ax_mumax_flat, allometric_diameters, mumax_flat_curve)
scatter!(ax_mumax_flat, plankton_sizes, mumax_flat; markersize = 14)
text!(ax_mumax_flat, plankton_sizes, mumax_flat; text = string.(plankton), align = (:left, :bottom), offset = (5, 5))

lines!(ax_kN_flat, allometric_diameters, kN_flat_curve)
scatter!(ax_kN_flat, plankton_sizes, kN_flat; markersize = 14)
text!(ax_kN_flat, plankton_sizes, kN_flat; text = string.(plankton), align = (:left, :bottom), offset = (5, 5))

lines!(ax_gmax_flat, allometric_diameters, gmax_flat_curve)
scatter!(ax_gmax_flat, plankton_sizes, gmax_flat; markersize = 14)
text!(ax_gmax_flat, plankton_sizes, gmax_flat; text = string.(plankton), align = (:left, :bottom), offset = (5, 5))

save("figures/01_flat_allometry.png", fig_flat)
fig_flat

# ## Strong small-fast allometry
#
# Finally we make the size dependence stronger.
# Negative `mumax` and `gmax` exponents make smaller plankton grow and graze faster.
# A positive `kN` exponent makes larger phytoplankton require higher nutrient concentration to approach maximum growth.

bgc_strong_small_fast = Agate.Models.NiPiZD.construct(;
    phyto_size_structure = phyto_diameters,
    zoo_size_structure = zoo_diameters,
    parameters = (
        maximum_growth_rate = AllometricParam(PowerLaw(); prefactor = 2 / day, exponent = -0.35),
        nutrient_half_saturation = AllometricParam(PowerLaw(); prefactor = 0.17, exponent = 0.35),
        maximum_predation_rate = AllometricParam(PowerLaw(); prefactor = 30.84 / day, exponent = -0.35),
    ),
)

mumax_strong_curve = power_law(allometric_diameters; prefactor = 2 / day, exponent = -0.35) .* day
kN_strong_curve = power_law(allometric_diameters; prefactor = 0.17, exponent = 0.35)
gmax_strong_curve = power_law(allometric_diameters; prefactor = 30.84 / day, exponent = -0.35) .* day

mumax_strong = bgc_strong_small_fast.parameters.maximum_growth_rate .* day
kN_strong = bgc_strong_small_fast.parameters.nutrient_half_saturation
gmax_strong = bgc_strong_small_fast.parameters.maximum_predation_rate .* day

fig_strong = Figure(; size = (1050, 420), fontsize = 16)
ax_mumax_strong = Axis(fig_strong[1, 1]; xlabel = "Diameter (μm ESD)", ylabel = "mumax (d⁻¹)", title = "Strong small-fast mumax", xscale = log10)
ax_kN_strong = Axis(fig_strong[1, 2]; xlabel = "Diameter (μm ESD)", ylabel = "kN", title = "Strong small-fast kN", xscale = log10)
ax_gmax_strong = Axis(fig_strong[1, 3]; xlabel = "Diameter (μm ESD)", ylabel = "gmax (d⁻¹)", title = "Strong small-fast gmax", xscale = log10)

lines!(ax_mumax_strong, allometric_diameters, mumax_strong_curve)
scatter!(ax_mumax_strong, plankton_sizes, mumax_strong; markersize = 14)
text!(ax_mumax_strong, plankton_sizes, mumax_strong; text = string.(plankton), align = (:left, :bottom), offset = (5, 5))

lines!(ax_kN_strong, allometric_diameters, kN_strong_curve)
scatter!(ax_kN_strong, plankton_sizes, kN_strong; markersize = 14)
text!(ax_kN_strong, plankton_sizes, kN_strong; text = string.(plankton), align = (:left, :bottom), offset = (5, 5))

lines!(ax_gmax_strong, allometric_diameters, gmax_strong_curve)
scatter!(ax_gmax_strong, plankton_sizes, gmax_strong; markersize = 14)
text!(ax_gmax_strong, plankton_sizes, gmax_strong; text = string.(plankton), align = (:left, :bottom), offset = (5, 5))

save("figures/01_strong_small_fast_allometry.png", fig_strong)
fig_strong

# ## Zero-dimensional ecosystem simulations
#
# The parameter plots show potential rates.
# We now run the same three allometric cases in a well-mixed box model and compare the ecosystem dynamics.

function run_box_model(bgc; filename)
    light_attenuation = FunctionFieldPAR(; grid = BoxModelGrid())
    bgc_model = Biogeochemistry(bgc; light_attenuation)
    full_model = BoxModel(; biogeochemistry = bgc_model)

    set!(full_model; N = 8.0, D = 0.01, P1 = 0.03, P2 = 0.03, Z1 = 0.01, Z2 = 0.01)

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
default_filename = run_box_model(bgc_default; filename = "outputs/01_default.jld2")

# Run the flat-allometry case.
flat_filename = run_box_model(bgc_flat; filename = "outputs/01_flat.jld2")

# Run the strong small-fast case.
strong_filename = run_box_model(bgc_strong_small_fast; filename = "outputs/01_strong_small_fast.jld2")

nothing #hide

# ## Plot ecosystem dynamics
#
# We summarize each simulation by plotting nutrient, total phytoplankton, total zooplankton, and detritus.
# These totals make the allometric cases easier to compare than six separate tracer lines.

function read_box_totals(filename)
    times = FieldTimeSeries(filename, "N").times ./ day
    N = FieldTimeSeries(filename, "N")[1, 1, 1, :]
    D = FieldTimeSeries(filename, "D")[1, 1, 1, :]
    P1 = FieldTimeSeries(filename, "P1")[1, 1, 1, :]
    P2 = FieldTimeSeries(filename, "P2")[1, 1, 1, :]
    Z1 = FieldTimeSeries(filename, "Z1")[1, 1, 1, :]
    Z2 = FieldTimeSeries(filename, "Z2")[1, 1, 1, :]

    return (; times = collect(times), N = collect(N), P = collect(P1 .+ P2), Z = collect(Z1 .+ Z2), D = collect(D))
end

default_dynamics = read_box_totals(default_filename)
flat_dynamics = read_box_totals(flat_filename)
strong_dynamics = read_box_totals(strong_filename)

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
save("figures/01_ecosystem_dynamics.png", fig_dynamics)
fig_dynamics

# ## Exercises
#
# 1. In the default allometry figure, which plankton sizes have the largest `mumax`, `kN`, and `gmax` values?
# 2. In the flat allometry figure, which differences remain among the four plankton tracers, and which disappear?
# 3. In the strong small-fast figure, how does making `b` more negative change the smallest and largest plankton?
# 4. Compare the ecosystem dynamics. Which allometric choice produces the largest total phytoplankton biomass, and when?