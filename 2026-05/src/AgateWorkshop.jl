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

function _safe_fraction(numerator, denominator)
    return numerator ./ ifelse.(denominator .> 0, denominator, NaN)
end

function _stacked_area!(ax, times, values, labels, colors)
    lower = zeros(length(times))

    for (series, label, color) in zip(values, labels, colors)
        upper = lower .+ series
        band!(ax, times, lower, upper; color=color, label=label)
        lower = upper
    end

    return ax
end

function _contribution_palette(keys)
    phyto_colors = ["#7FC97F", "#4DAF4A", "#1B7837", "#00441B"]
    zoo_colors = ["#FDB863", "#E08214", "#B35806", "#7F3B08"]

    colors = String[]
    phyto_index = 0
    zoo_index = 0

    for key in keys
        if key == :N
            push!(colors, "#4C78A8")
        elseif key == :D
            push!(colors, "#B279A2")
        elseif startswith(String(key), "P")
            phyto_index += 1
            push!(colors, phyto_colors[mod1(phyto_index, length(phyto_colors))])
        elseif startswith(String(key), "Z")
            zoo_index += 1
            push!(colors, zoo_colors[mod1(zoo_index, length(zoo_colors))])
        else
            push!(colors, "#9D9D9D")
        end
    end

    return colors
end

function plot_contributions(times, data; figure_path=nothing)
    phyto, zoo, _ = _plankton_keys(data)
    nutrient = haskey(data, :N) ? data[:N] : zeros(length(times))
    detritus = haskey(data, :D) ? data[:D] : zeros(length(times))
    phyto_total = _sum_keys(data, phyto)
    zoo_total = _sum_keys(data, zoo)
    living = phyto_total .+ zoo_total
    nonliving = nutrient .+ detritus
    total = living .+ nonliving

    tracer_keys = Symbol[]
    haskey(data, :N) && push!(tracer_keys, :N)
    append!(tracer_keys, phyto)
    append!(tracer_keys, zoo)
    haskey(data, :D) && push!(tracer_keys, :D)

    tracer_values = [_safe_fraction(data[key], total) for key in tracer_keys]
    tracer_colors = _contribution_palette(tracer_keys)

    fig = Figure(; size=(580, 540), fontsize=12)
    axes = [
        Axis(fig[1, 1]; title="All tracers", xlabel="Days", ylabel="Fraction of total nitrogen", limits=(nothing, nothing, 0, 1)),
        Axis(fig[2, 1]; title="Living vs non-living nitrogen", xlabel="Days", ylabel="Fraction of total nitrogen", limits=(nothing, nothing, 0, 1)),
        Axis(fig[3, 1]; title="Phytoplankton vs zooplankton", xlabel="Days", ylabel="Fraction of living biomass", limits=(nothing, nothing, 0, 1)),
    ]

    _stacked_area!(axes[1], times, tracer_values, string.(tracer_keys), tracer_colors)

    _stacked_area!(
        axes[2],
        times,
        [_safe_fraction(living, total), _safe_fraction(nonliving, total)],
        ["living", "non-living"],
        ["#54A24B", "#9D9D9D"],
    )

    _stacked_area!(
        axes[3],
        times,
        [_safe_fraction(phyto_total, living), _safe_fraction(zoo_total, living)],
        ["phytoplankton", "zooplankton"],
        ["#54A24B", "#E08214"],
    )

    for ax in axes
        axislegend(ax; position=:rb)
    end

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
