using Agate
using Agate.Introspection: plankton_diameters, plankton_groups, plankton_tracers, tracer_names
using Agate.Library.Light
using CairoMakie
using OceanBioME: Biogeochemistry, BoxModel, BoxModelGrid
using Oceananigans
using Oceananigans.Units: day, minute

const DEFAULT_INITIAL_CONDITIONS = (N=7.0, P1=0.01, Z1=0.01, P2=0.1, Z2=0.01, D=0.01)

const WORKSHOP_COLORS = (
    living = "#2A9D8F",
    nonliving = "#7A7A7A",
    phytoplankton = "#54A24B",
    zooplankton = "#E08214",
)

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

function _plankton_diameters_by_tracer(bgc)
    return Dict(Symbol.(plankton_tracers(bgc)) .=> plankton_diameters(bgc))
end

function _keys_with_diameters(keys, diameters)
    return filter(key -> haskey(diameters, key), keys)
end

function _cwm_or_nan(data, diameters, keys)
    keys = _keys_with_diameters(keys, diameters)
    isempty(keys) && return fill(NaN, length(first(values(data))))

    total = zero(data[first(keys)])
    weighted = zero(data[first(keys)])

    for key in keys
        values = data[key]
        total = total .+ values
        weighted = weighted .+ diameters[key] .* values
    end

    return weighted ./ ifelse.(total .> 0, total, NaN)
end

function _save_if_requested(fig, figure_path)
    figure_path !== nothing && save(figure_path, fig; px_per_unit=1)
    return fig
end

function _case_palette(n)
    colors = ["#0072B2", "#E69F00", "#009E73", "#CC79A7", "#56B4E9", "#D55E00", "#F0E442"]
    return [colors[mod1(i, length(colors))] for i in 1:n]
end

function _shared_line_legend!(fig, row, columns, colors, labels)
    elements = [LineElement(; color=color, linewidth=2) for color in colors]
    Legend(
        fig[row, columns],
        elements,
        labels;
        orientation=:horizontal,
        tellwidth=false,
        tellheight=true,
        framevisible=false,
    )
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

function _as_timeseries_vector(timeseries)
    if hasproperty(timeseries, :times) && hasproperty(timeseries, :data)
        return [timeseries]
    elseif timeseries isa AbstractVector || timeseries isa Tuple
        series = collect(timeseries)
        !isempty(series) || error("At least one box-model time series is required.")
        all(ts -> hasproperty(ts, :times) && hasproperty(ts, :data), series) ||
            error("Each entry must have times and data fields.")
        return series
    else
        error("Expected a box-model time series or a collection of box-model time series.")
    end
end

function _box_timeseries_variables(series, variables)
    if variables !== nothing
        return collect(Symbol.(variables))
    end

    keys_in_all = Set(keys(_data(first(series))))
    for ts in series[2:end]
        intersect!(keys_in_all, keys(_data(ts)))
    end

    return sort!(collect(keys_in_all); by=string)
end

function plot_box_timeseries(
    timeseries;
    labels=nothing,
    variables=nothing,
    ylabels=nothing,
    figure_path=nothing,
)
    series = _as_timeseries_vector(timeseries)
    variables = _box_timeseries_variables(series, variables)

    if labels === nothing
        labels = length(series) == 1 ? ["box model"] : ["series $i" for i in eachindex(series)]
    end

    length(labels) == length(series) || error("labels must have one entry per box-model time series.")

    if ylabels === nothing
        ylabels = Dict(variable => "Concentration (mmol N m⁻³)" for variable in variables)
    else
        ylabels = Dict(Symbol(key) => value for (key, value) in pairs(ylabels))
    end

    n_variables = length(variables)
    n_columns = min(2, n_variables)
    n_rows = cld(n_variables, n_columns)
    has_comparison = length(series) > 1
    legend_rows = has_comparison ? 1 : 0
    colors = _case_palette(length(series))
    fig = Figure(; size=(360 * n_columns, 180 * n_rows + 44 * legend_rows), fontsize=12)

    if has_comparison
        _shared_line_legend!(fig, 1, 1:n_columns, colors, labels)
    end

    for (idx, variable) in enumerate(variables)
        row = cld(idx, n_columns) + legend_rows
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
            lines!(ax, _times(ts), data[variable]; color=colors[series_idx], linewidth=2)
        end
    end

    return _save_if_requested(fig, figure_path)
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

function plot_contributions(times, data; figure_path=nothing)
    phyto, zoo, _ = _plankton_keys(data)
    nutrient = haskey(data, :N) ? data[:N] : zeros(length(times))
    detritus = haskey(data, :D) ? data[:D] : zeros(length(times))
    phyto_total = _sum_keys(data, phyto)
    zoo_total = _sum_keys(data, zoo)
    living = phyto_total .+ zoo_total
    nonliving = nutrient .+ detritus
    total = living .+ nonliving

    fig = Figure(; size=(580, 410), fontsize=12)

    legend_elements = [
        PolyElement(; color=WORKSHOP_COLORS.living),
        PolyElement(; color=WORKSHOP_COLORS.nonliving),
        PolyElement(; color=WORKSHOP_COLORS.phytoplankton),
        PolyElement(; color=WORKSHOP_COLORS.zooplankton),
    ]
    Legend(
        fig[1, 1],
        legend_elements,
        ["living", "non-living", "phytoplankton", "zooplankton"];
        orientation=:horizontal,
        tellwidth=false,
        tellheight=true,
        framevisible=false,
    )

    ax_living = Axis(
        fig[2, 1];
        title="Living vs non-living nitrogen",
        xlabel="Days",
        ylabel="Fraction of total nitrogen",
        limits=(nothing, nothing, 0, 1),
    )

    ax_plankton = Axis(
        fig[3, 1];
        title="Phytoplankton vs zooplankton",
        xlabel="Days",
        ylabel="Fraction of living biomass",
        limits=(nothing, nothing, 0, 1),
    )

    _stacked_area!(
        ax_living,
        times,
        [_safe_fraction(living, total), _safe_fraction(nonliving, total)],
        ["living", "non-living"],
        [WORKSHOP_COLORS.living, WORKSHOP_COLORS.nonliving],
    )

    _stacked_area!(
        ax_plankton,
        times,
        [_safe_fraction(phyto_total, living), _safe_fraction(zoo_total, living)],
        ["phytoplankton", "zooplankton"],
        [WORKSHOP_COLORS.phytoplankton, WORKSHOP_COLORS.zooplankton],
    )

    return _save_if_requested(fig, figure_path)
end

function _as_bgc_vector(bgcs, n_series)
    if bgcs isa AbstractVector || bgcs isa Tuple
        bgcs = collect(bgcs)
        length(bgcs) == n_series || error("bgcs must have one entry per box-model time series.")
        return bgcs
    else
        return fill(bgcs, n_series)
    end
end

function plot_cwm_size(
    timeseries,
    bgcs;
    labels=nothing,
    figure_path=nothing,
)
    series = _as_timeseries_vector(timeseries)
    bgcs = _as_bgc_vector(bgcs, length(series))

    if labels === nothing
        labels = length(series) == 1 ? ["box model"] : ["series $i" for i in eachindex(series)]
    end

    length(labels) == length(series) || error("labels must have one entry per box-model time series.")

    has_comparison = length(series) > 1
    legend_rows = has_comparison ? 1 : 0
    colors = _case_palette(length(series))
    fig = Figure(; size=(560, 420 + 44 * legend_rows), fontsize=12)

    if has_comparison
        _shared_line_legend!(fig, 1, 1, colors, labels)
    end

    axes = [
        Axis(fig[1 + legend_rows, 1]; title="All plankton", xlabel="Days", ylabel="CWM ESD (μm)"),
        Axis(fig[2 + legend_rows, 1]; title="Phytoplankton", xlabel="Days", ylabel="CWM ESD (μm)"),
        Axis(fig[3 + legend_rows, 1]; title="Zooplankton", xlabel="Days", ylabel="CWM ESD (μm)"),
    ]

    for (idx, (ts, bgc)) in enumerate(zip(series, bgcs))
        data = _data(ts)
        diameters = _plankton_diameters_by_tracer(bgc)
        phyto, zoo, plankton = _plankton_keys(data)

        lines!(axes[1], _times(ts), _cwm_or_nan(data, diameters, plankton); color=colors[idx], linewidth=2)
        lines!(axes[2], _times(ts), _cwm_or_nan(data, diameters, phyto); color=colors[idx], linewidth=2)
        lines!(axes[3], _times(ts), _cwm_or_nan(data, diameters, zoo); color=colors[idx], linewidth=2)
    end

    return _save_if_requested(fig, figure_path)
end
