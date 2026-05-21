# # [Exercise 01: Quick start] (@id quick_start_exercise)
#
# This exercise follows the Agate.jl Quick start and then packages the repeated
# box-model setup into a reusable workshop wrapper.
#
# The main idea is simple: construct any Agate-compatible biogeochemistry model,
# wrap it in an OceanBioME `Biogeochemistry`, place it in an Oceananigans
# `BoxModel`, set initial tracer values, and run a simulation.

# ## Loading dependencies

using Agate
using Agate.Introspection: tracer_names
using Agate.Library.Light
using OceanBioME
using OceanBioME: Biogeochemistry
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


mkpath(joinpath("outputs"))
mkpath(joinpath("figures"))

nothing #hide

# ## Agate.jl Quick start, step by step
#
# First construct the default two-phytoplankton, two-zooplankton NiPiZD model.

bgc = Agate.Models.NiPiZD.construct()
println(tracer_names(bgc))

nothing #hide

# The Quick start uses a seasonal photosynthetically active radiation field for a
# zero-dimensional box.

light_attenuation = FunctionFieldPAR(; grid=BoxModelGrid())

nothing #hide

# OceanBioME adapts the Agate biogeochemistry to an Oceananigans model.

bgc_model = Biogeochemistry(bgc; light_attenuation)
full_model = BoxModel(; biogeochemistry=bgc_model)

nothing #hide

# Set the initial tracer concentrations. The names must match the tracer names
# printed above.

set!(full_model; N=7.0, P1=0.01, Z1=0.01, P2=0.1, Z2=0.01, D=0.01)

nothing #hide

# Run the model and save daily tracer output.

quickstart_filename = joinpath("outputs", "01_quick_start_manual.jld2")
simulation = Simulation(full_model; Δt=240minutes, stop_time=1095days)

simulation.output_writers[:fields] = JLD2Writer(
    full_model,
    full_model.fields;
    filename=quickstart_filename,
    schedule=TimeInterval(1day),
    overwrite_existing=true,
)

run!(simulation)

nothing #hide

# ## Reading and plotting the output

tracer_syms = tracer_names(bgc)
timeseries = read_box_tracer_timeseries(quickstart_filename, tracer_syms)

fig_manual = Figure(; size=(1200, 800), fontsize=20)

for (idx, sym) in enumerate(tracer_syms)
    row = floor(Int, (idx - 1) / 2) + 1
    col = Int((idx - 1) % 2) + 1
    ax = Axis(
        fig_manual[row, col];
        ylabel=string(sym),
        xlabel="Days",
        title="$(sym) concentration (mmol N m⁻³)",
    )
    lines!(ax, timeseries.times, timeseries.data[Symbol(sym)]; linewidth=3)
end

save(joinpath("figures", "01_quick_start_manual.png"), fig_manual)
fig_manual

# ## A general workshop box-model wrapper
#
# The same setup will appear repeatedly in later exercises. The workshop
# helper script therefore defines:
#
# - `build_box_model(bgc; light_attenuation, initial_conditions)`
# - `run_box_model(bgc; filename, initial_conditions, Δt, stop_time, output_interval)`
# - `read_box_tracer_timeseries(filename, tracer_syms)`
#
# The wrapper takes `bgc` as an argument, so it can be reused with more complex
# Agate models as long as the initial conditions cover that model's tracers.

wrapped = run_box_model(
    bgc;
    filename=joinpath("outputs", "01_quick_start_wrapped.jld2"),
    initial_conditions=(N=7.0, P1=0.01, Z1=0.01, P2=0.1, Z2=0.01, D=0.01),
    Δt=240minutes,
    stop_time=1095days,
    output_interval=1day,
)

wrapped_timeseries = read_box_tracer_timeseries(wrapped.filename, wrapped.tracer_syms)

nothing #hide

# The wrapper is also useful when we change model complexity. Here we construct a
# larger NiPiZD community and use the same `run_box_model` function.

larger_bgc = Agate.Models.NiPiZD.construct(
    phyto_size_structure=(n=3, min_esd=1.0, max_esd=10.0, splitting=:log_splitting),
    zoo_size_structure=[10.0, 32.0, 100.0],
)

larger_initial_conditions = (N=7.0, D=0.01, P1=0.01, P2=0.01, P3=0.01, Z1=0.01, Z2=0.01, Z3=0.01)

larger = run_box_model(
    larger_bgc;
    filename=joinpath("outputs", "01_quick_start_larger_community.jld2"),
    initial_conditions=larger_initial_conditions,
    Δt=240minutes,
    stop_time=365days,
    output_interval=1day,
)

println(larger.tracer_syms)

nothing #hide

# ## Exercises
#
# 1. Change one initial condition in the manual Quick start. Which tracer changes first?
# 2. Change `stop_time` in the wrapper call from three years to one year.
# 3. Change the larger community to four phytoplankton classes. Which extra tracer name appears?
# 4. Add a new keyword to `run_box_model` for a different output interval.
