using Agate
using Agate.Introspection: plankton_diameters, plankton_tracers, tracer_names
using Agate.Library.Light
using CairoMakie
using OceanBioME: Biogeochemistry, BoxModel, BoxModelGrid
using Oceananigans
using Oceananigans.Units: day, minute

const DEFAULT_INITIAL_CONDITIONS = (N=7.0, P1=0.01, Z1=0.01, P2=0.1, Z2=0.01, D=0.01)

default_quickstart_bgc() = Agate.Models.NiPiZD.construct()

default_quickstart_initial_conditions() = DEFAULT_INITIAL_CONDITIONS

function build_box_model(
    bgc;
    light_attenuation=FunctionFieldPAR(; grid=BoxModelGrid()),
    initial_conditions=DEFAULT_INITIAL_CONDITIONS,
)
    bgc_model = Biogeochemistry(bgc; light_attenuation)
    model = BoxModel(; biogeochemistry=bgc_model)
    set!(model; initial_conditions...)
    return model
end

function run_box_model(
    bgc;
    filename=joinpath("outputs", "quick_start.jld2"),
    initial_conditions=DEFAULT_INITIAL_CONDITIONS,
    Δt=240minute,
    stop_time=1095day,
    output_interval=1day,
    light_attenuation=FunctionFieldPAR(; grid=BoxModelGrid()),
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

    return (
        model=model,
        simulation=simulation,
        filename=filename,
        tracer_syms=tracer_names(bgc),
    )
end

function _read_field_values(field_time_series)
    return [first(interior(field_time_series[n])) for n in eachindex(field_time_series.times)]
end

function read_box_tracer_timeseries(filename, tracer_syms)
    tracer_syms = collect(Symbol.(tracer_syms))
    data = Dict{Symbol, Vector{Float64}}()
    times = nothing

    for tracer in tracer_syms
        field_time_series = FieldTimeSeries(filename, string(tracer))
        times === nothing && (times = collect(field_time_series.times) ./ day)
        data[tracer] = Float64.(_read_field_values(field_time_series))
    end

    return (times=times, data=data)
end

_times(ts) = hasproperty(ts, :times) ? getproperty(ts, :times) : ts[1]
_data(ts) = hasproperty(ts, :data) ? getproperty(ts, :data) : ts[2]

function _keys_from_data(data)
    return sort!(collect(keys(data)); by=string)
end

function _prefixed_keys(data, prefix)
    return filter(key -> startswith(String(key), prefix), _keys_from_data(data))
end

function _sum_keys(data, keys)
    isempty(keys) && return zeros(length(first(values(data))))
    total = zero(data[first(keys)])
    for key in keys
        total = total .+ data[key]
    end
    return total
end

function _plankton_keys(data)
    phyto = _prefixed_keys(data, "P")
    zoo = _prefixed_keys(data, "Z")
    return phyto, zoo, vcat(phyto, zoo)
end

function _cwm(data, diameters, keys)
    isempty(keys) && return zeros(length(first(values(data))))

    total = zero(data[first(keys)])
    weighted = zero(data[first(keys)])

    for key in keys
        haskey(diameters, key) || error("Missing diameter for tracer $key.")
        values = data[key]
        total = total .+ values
        weighted = weighted .+ diameters[key] .* values
    end

    return weighted ./ total
end

function _save_if_requested(fig, figure_path)
    figure_path !== nothing && save(figure_path, fig)
    return fig
end

function plot_tracer_concentrations(times, data, tracer_syms=_keys_from_data(data); figure_path=nothing)
    tracer_syms = collect(Symbol.(tracer_syms))
    n_tracers = length(tracer_syms)
    n_columns = min(2, n_tracers)
    n_rows = cld(n_tracers, n_columns)
    fig = Figure(; size=(600 * n_columns, 280 * n_rows), fontsize=16)

    for (idx, tracer) in enumerate(tracer_syms)
        row = cld(idx, n_columns)
        col = mod1(idx, n_columns)
        ax = Axis(
            fig[row, col];
            title="$(tracer) concentration",
            xlabel="Days",
            ylabel="mmol N m⁻³",
        )
        lines!(ax, times, data[tracer]; linewidth=3)
    end

    return _save_if_requested(fig, figure_path)
end

function plot_timeseries_comparison(series...; labels=nothing, variables=nothing, ylabels=nothing, figure_path=nothing)
    length(series) >= 2 || error("At least two time series are required for a comparison.")

    if labels === nothing
        labels = ["series $i" for i in eachindex(series)]
    end

    length(labels) == length(series) || error("labels must have one entry per time series.")

    first_data = _data(first(series))
    if variables === nothing
        variables = _keys_from_data(first_data)
    else
        variables = collect(Symbol.(variables))
    end

    if ylabels === nothing
        ylabels = Dict(variable => string(variable) for variable in variables)
    else
        ylabels = Dict(Symbol(key) => value for (key, value) in pairs(ylabels))
    end

    n_variables = length(variables)
    n_columns = min(2, n_variables)
    n_rows = cld(n_variables, n_columns)
    fig = Figure(; size=(600 * n_columns, 280 * n_rows), fontsize=16)

    for (idx, variable) in enumerate(variables)
        row = cld(idx, n_columns)
        col = mod1(idx, n_columns)
        ax = Axis(
            fig[row, col];
            title=string(variable),
            xlabel="Days",
            ylabel=get(ylabels, variable, string(variable)),
        )

        for (series_idx, ts) in enumerate(series)
            data = _data(ts)
            haskey(data, variable) || continue
            lines!(ax, _times(ts), data[variable]; label=labels[series_idx], linewidth=3)
        end

        axislegend(ax; position=:rt)
    end

    return _save_if_requested(fig, figure_path)
end

function plot_tracer_concentrations_comparison(series...; labels=nothing, tracer_syms=nothing, figure_path=nothing)
    variables = tracer_syms === nothing ? nothing : collect(Symbol.(tracer_syms))
    ylabels = variables === nothing ? nothing : Dict(variable => "Concentration (mmol N m⁻³)" for variable in variables)
    return plot_timeseries_comparison(series...; labels=labels, variables=variables, ylabels=ylabels, figure_path=figure_path)
end

function plot_contributions(times, data; figure_path=nothing)
    phyto, zoo, plankton = _plankton_keys(data)
    nutrient = haskey(data, :N) ? data[:N] : zeros(length(times))
    detritus = haskey(data, :D) ? data[:D] : zeros(length(times))
    phyto_total = _sum_keys(data, phyto)
    zoo_total = _sum_keys(data, zoo)
    living = phyto_total .+ zoo_total
    total = nutrient .+ detritus .+ living

    fig = Figure(; size=(950, 760), fontsize=16)

    ax1 = Axis(fig[1, 1]; title="Relative nitrogen pools", xlabel="Days", ylabel="Fraction")
    lines!(ax1, times, nutrient ./ total; label="N", linewidth=3)
    lines!(ax1, times, detritus ./ total; label="D", linewidth=3)
    lines!(ax1, times, living ./ total; label="living", linewidth=3)
    axislegend(ax1; position=:rt)

    ax2 = Axis(fig[2, 1]; title="Living biomass", xlabel="Days", ylabel="mmol N m⁻³")
    lines!(ax2, times, phyto_total; label="phytoplankton", linewidth=3)
    lines!(ax2, times, zoo_total; label="zooplankton", linewidth=3)
    axislegend(ax2; position=:rt)

    ax3 = Axis(fig[3, 1]; title="Phytoplankton vs zooplankton", xlabel="Days", ylabel="Fraction of living biomass")
    lines!(ax3, times, phyto_total ./ living; label="phytoplankton", linewidth=3)
    lines!(ax3, times, zoo_total ./ living; label="zooplankton", linewidth=3)
    axislegend(ax3; position=:rt)

    return _save_if_requested(fig, figure_path)
end

function plot_size_spectrum(times, data, bgc; figure_path=nothing)
    diameters = Dict(plankton_tracers(bgc) .=> plankton_diameters(bgc))
    phyto, zoo, plankton = _plankton_keys(data)

    fig = Figure(; size=(950, 760), fontsize=16)
    axes = [
        Axis(fig[1, 1]; title="All plankton", xlabel="Days", ylabel="CWM ESD (μm)"),
        Axis(fig[2, 1]; title="Phytoplankton", xlabel="Days", ylabel="CWM ESD (μm)"),
        Axis(fig[3, 1]; title="Zooplankton", xlabel="Days", ylabel="CWM ESD (μm)"),
    ]

    !isempty(plankton) && lines!(axes[1], times, _cwm(data, diameters, plankton); linewidth=3)
    !isempty(phyto) && lines!(axes[2], times, _cwm(data, diameters, phyto); linewidth=3)
    !isempty(zoo) && lines!(axes[3], times, _cwm(data, diameters, zoo); linewidth=3)

    return _save_if_requested(fig, figure_path)
end
