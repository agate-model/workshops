module WorkshopBoxModels

using Agate
using Agate.Introspection: tracer_names
using Agate.Library.Light
using OceanBioME: Biogeochemistry
using Oceananigans
using Oceananigans.Units

export build_box_model,
       run_box_model,
       read_box_tracer_timeseries,
       default_quickstart_initial_conditions,
       default_quickstart_bgc

"""
    default_quickstart_bgc()

Construct the default Agate.jl NiPiZD biogeochemistry used in the package Quick start.
"""
default_quickstart_bgc() = Agate.Models.NiPiZD.construct()

"""
    default_quickstart_initial_conditions()

Return the initial conditions used in the Agate.jl Quick start box-model example.
"""
default_quickstart_initial_conditions() = (N=7.0, P1=0.01, Z1=0.01, P2=0.1, Z2=0.01, D=0.01)

"""
    build_box_model(bgc; light_attenuation, initial_conditions)

Wrap an Agate.jl biogeochemistry object in an OceanBioME/Oceananigans box model.

The `bgc` argument can be any Agate-compatible biogeochemistry object, from a
small default NiPiZD model to a larger custom community. The initial conditions
must provide values for the tracer names required by that model.
"""
function build_box_model(
    bgc;
    light_attenuation=FunctionFieldPAR(; grid=BoxModelGrid()),
    initial_conditions=default_quickstart_initial_conditions(),
)
    bgc_model = Biogeochemistry(bgc; light_attenuation)
    model = BoxModel(; biogeochemistry=bgc_model)
    set!(model; initial_conditions...)
    return model
end

"""
    run_box_model(bgc; filename, initial_conditions, Δt, stop_time, output_interval)

Build, run, and save tracer output for an Agate.jl box model.

Returns a named tuple containing the `model`, `simulation`, output `filename`, and
Agate tracer symbols. The wrapper keeps workshop scripts short while leaving the
model construction explicit and inspectable.
"""
function run_box_model(
    bgc;
    filename="outputs/quick_start.jld2",
    initial_conditions=default_quickstart_initial_conditions(),
    light_attenuation=FunctionFieldPAR(; grid=BoxModelGrid()),
    Δt=240minutes,
    stop_time=1095days,
    output_interval=1day,
)
    mkpath(dirname(filename))

    model = build_box_model(bgc; light_attenuation, initial_conditions)
    simulation = Simulation(model; Δt, stop_time)

    simulation.output_writers[:fields] = JLD2Writer(
        model,
        model.fields;
        filename,
        schedule=TimeInterval(output_interval),
        overwrite_existing=true,
    )

    run!(simulation)

    return (; model, simulation, filename, tracer_syms=tracer_names(bgc))
end

"""
    read_box_tracer_timeseries(filename, tracer_syms)

Read tracer time series from a saved box-model output file.
"""
function read_box_tracer_timeseries(filename, tracer_syms)
    times = FieldTimeSeries(filename, string(first(tracer_syms))).times ./ day

    data = Dict{Symbol, Vector{Float64}}()
    for tracer in tracer_syms
        series = FieldTimeSeries(filename, string(tracer))[1, 1, 1, :]
        data[Symbol(tracer)] = collect(Float64.(series))
    end

    return (; times=collect(Float64.(times)), data)
end

end # module
