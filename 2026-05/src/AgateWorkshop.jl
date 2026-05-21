using Agate
using Agate.Introspection: plankton_diameters, plankton_groups, plankton_tracers, tracer_names
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
    figure_path !== nothing && save(figure_path, fig; px_per_unit=1)
    return fig
end


function _parameter_tracers_and_values(bgc, parameter_name::Symbol)
    groups = plankton_groups(bgc)
    plankton = collect(plankton_tracers(bgc))
    values = collect(getproperty(bgc.parameters, parameter_name))

    if length(values) == length(groups.P)
        return collect(groups.P), values, "Phytoplankton"
    elseif length(values) == length(groups.Z)
        return collect(groups.Z), values, "Zooplankton"
    elseif length(values) == length(plankton)
        return plankton, values, "Plankton"
    else
        error("Cannot align parameter $parameter_name with plankton tracers.")
    end
end

function plot_plankton_parameter_bars(
    bgcs,
    parameter_name::Symbol;
    labels=nothing,
    ylabel=string(parameter_name),
    title=string(parameter_name),
    figure_path=nothing,
)
    bgcs = bgcs isa Tuple || bgcs isa AbstractVector ? collect(bgcs) : [bgcs]
    !isempty(bgcs) || error("At least one biogeochemistry object is required.")

    labels === nothing && (labels = ["case $i" for i in eachindex(bgcs)])
    length(labels) == length(bgcs) || error("labels must have one entry per biogeochemistry object.")

    tracers, first_values, group_label = _parameter_tracers_and_values(first(bgcs), parameter_name)
    value_sets = [first_values]

    for bgc in bgcs[2:end]
        case_tracers, values, case_group_label = _parameter_tracers_and_values(bgc, parameter_name)
        case_tracers == tracers || error("All cases must use the same tracer names for $parameter_name.")
        case_group_label == group_label || error("All cases must align $parameter_name with the same plankton group.")
        push!(value_sets, values)
    end

    n_tracers = length(tracers)
    n_cases = length(bgcs)
    centers = collect(1:n_tracers)
    width = min(0.8 / n_cases, 0.28)
    offsets = ((1:n_cases) .- (n_cases + 1) / 2) .* width

    fig = Figure(; size=(max(420, 80 * n_tracers), 260), fontsize=12)
    ax = Axis(
        fig[1, 1];
        xlabel=group_label,
        ylabel,
        title,
        xticks=(centers, string.(tracers)),
    )

    for (case_idx, values) in enumerate(value_sets)
        barplot!(ax, centers .+ offsets[case_idx], values; width, label=labels[case_idx])
    end

    n_cases > 1 && axislegend(ax; position=:rt)

    return _save_if_requested(fig, figure_path)
end

function plot_tracer_concentrations(times, data, tracer_syms=_keys_from_data(data); figure_path=nothing)
    tracer_syms = collect(Symbol.(tracer_syms))
    n_tracers = length(tracer_syms)
    n_columns = min(2, n_tracers)
    n_rows = cld(n_tracers, n_columns)
    fig = Figure(; size=(360 * n_columns, 180 * n_rows), fontsize=12)

    for (idx, tracer) in enumerate(tracer_syms)
        row = cld(idx, n_columns)
        col = mod1(idx, n_columns)
        ax = Axis(
            fig[row, col];
            title="$(tracer) concentration",
            xlabel="Days",
            ylabel="mmol N m⁻³",
        )
        lines!(ax, times, data[tracer]; linewidth=2)
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
    fig = Figure(; size=(360 * n_columns, 180 * n_rows), fontsize=12)

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
            lines!(ax, _times(ts), data[variable]; label=labels[series_idx], linewidth=2)
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

    fig = Figure(; size=(560, 520), fontsize=12)

    ax1 = Axis(fig[1, 1]; title="Relative nitrogen pools", xlabel="Days", ylabel="Fraction")
    lines!(ax1, times, nutrient ./ total; label="N", linewidth=2)
    lines!(ax1, times, detritus ./ total; label="D", linewidth=2)
    lines!(ax1, times, living ./ total; label="living", linewidth=2)
    axislegend(ax1; position=:rt)

    ax2 = Axis(fig[2, 1]; title="Living biomass", xlabel="Days", ylabel="mmol N m⁻³")
    lines!(ax2, times, phyto_total; label="phytoplankton", linewidth=2)
    lines!(ax2, times, zoo_total; label="zooplankton", linewidth=2)
    axislegend(ax2; position=:rt)

    ax3 = Axis(fig[3, 1]; title="Phytoplankton vs zooplankton", xlabel="Days", ylabel="Fraction of living biomass")
    lines!(ax3, times, phyto_total ./ living; label="phytoplankton", linewidth=2)
    lines!(ax3, times, zoo_total ./ living; label="zooplankton", linewidth=2)
    axislegend(ax3; position=:rt)

    return _save_if_requested(fig, figure_path)
end

function plot_size_spectrum(times, data, bgc; figure_path=nothing)
    diameters = Dict(plankton_tracers(bgc) .=> plankton_diameters(bgc))
    phyto, zoo, plankton = _plankton_keys(data)

    fig = Figure(; size=(560, 520), fontsize=12)
    axes = [
        Axis(fig[1, 1]; title="All plankton", xlabel="Days", ylabel="CWM ESD (μm)"),
        Axis(fig[2, 1]; title="Phytoplankton", xlabel="Days", ylabel="CWM ESD (μm)"),
        Axis(fig[3, 1]; title="Zooplankton", xlabel="Days", ylabel="CWM ESD (μm)"),
    ]

    !isempty(plankton) && lines!(axes[1], times, _cwm(data, diameters, plankton); linewidth=2)
    !isempty(phyto) && lines!(axes[2], times, _cwm(data, diameters, phyto); linewidth=2)
    !isempty(zoo) && lines!(axes[3], times, _cwm(data, diameters, zoo); linewidth=2)

    return _save_if_requested(fig, figure_path)
end
