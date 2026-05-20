module WorkshopDiagnostics

using Agate
using Agate.Library.Light
using Agate.Introspection: tracer_names
using OceanBioME
using OceanBioME: Biogeochemistry, BoxModel, BoxModelGrid
using Oceananigans
using Oceananigans.Units
using CairoMakie
using LinearAlgebra: diag
using Statistics

export run_quickstart_box_model,
       read_quickstart_timeseries,
       plot_tracer_concentrations,
       plot_contributions,
       plot_size_spectrum,
       plot_trophic_interactions,
       summarize_predation_matrix,
       default_plankton_diameters,
       default_predation_matrix

"""
    run_quickstart_box_model(; filename=joinpath("outputs", "quick_start.jld2"))

Run the Agate.jl Quickstart box model and write daily tracer output.

This mirrors the Quickstart model: a default NiPiZD model with two
phytoplankton groups, two zooplankton groups, nutrient, and detritus.
"""
function run_quickstart_box_model(; filename=joinpath("outputs", "quick_start.jld2"))
    mkpath(dirname(filename))

    bgc = Agate.Models.NiPiZD.construct()
    light_attenuation = FunctionFieldPAR(; grid=BoxModelGrid())
    bgc_model = Biogeochemistry(bgc; light_attenuation=light_attenuation)
    full_model = BoxModel(; biogeochemistry=bgc_model)

    set!(full_model; N=7.0, P1=0.01, Z1=0.01, P2=0.1, Z2=0.01, D=0.01)

    simulation = Simulation(full_model; Δt=240minutes, stop_time=1095days)

    simulation.output_writers[:fields] = JLD2Writer(
        full_model,
        full_model.fields;
        filename=filename,
        schedule=TimeInterval(1day),
        overwrite_existing=true,
    )

    run!(simulation)

    tracer_syms = tracer_names(bgc)
    return (; filename, tracer_syms)
end

"""
    read_quickstart_timeseries(filename, tracer_syms)

Read box-model tracer output written by `run_quickstart_box_model`.
"""
function read_quickstart_timeseries(filename, tracer_syms)
    times = FieldTimeSeries(filename, string(first(tracer_syms))).times ./ day

    data = Dict{Symbol, Vector{Float64}}()
    for tracer in tracer_syms
        series = FieldTimeSeries(filename, string(tracer))[1, 1, 1, :]
        data[Symbol(tracer)] = collect(Float64.(series))
    end

    return (; times=collect(Float64.(times)), data)
end

function _get(data::Dict{Symbol, Vector{Float64}}, key::Symbol)
    return get(data, key, zeros(length(first(values(data)))))
end

function _sum_matching(data::Dict{Symbol, Vector{Float64}}, pattern::Regex)
    matching = [values for (key, values) in data if occursin(pattern, String(key))]
    isempty(matching) && return zeros(length(first(values(data))))
    return reduce(.+, matching)
end

function _stacked_relative_area!(ax, times, series)
    denominator = reduce(.+, last.(series)) .+ eps()
    lower = zeros(length(times))

    for (label, values) in series
        upper = lower .+ values ./ denominator
        band!(ax, times, lower, upper; label)
        lower = upper
    end

    ylims!(ax, 0, 1)
    return ax
end


"""
    plot_tracer_concentrations(times, data, tracer_syms; figure_path, columns=2)

Plot each tracer concentration in its own panel. The figure height expands with
how many tracer panels are needed.
"""
function plot_tracer_concentrations(times, data, tracer_syms=sort(collect(keys(data)); by=string);
                                    figure_path=joinpath("figures", "diagnostic_00_tracer_concentrations.png"),
                                    columns=2)
    mkpath(dirname(figure_path))

    tracers = Symbol.(tracer_syms)
    ntracers = length(tracers)
    rows = cld(ntracers, columns)

    fig = Figure(; size=(600 * columns, 260 * rows), fontsize=20)

    for (idx, tracer) in enumerate(tracers)
        row = cld(idx, columns)
        col = mod1(idx, columns)
        ax = Axis(
            fig[row, col];
            ylabel=string(tracer),
            xlabel="Days",
            title="$(tracer) concentration (mmol N m⁻³)",
        )
        lines!(ax, times, _get(data, tracer); linewidth=3)
    end

    save(figure_path, fig)
    return fig
end

"""
    plot_contributions(times, data; figure_path)

Plot relative nitrogen contributions as stacked areas for total nitrogen pools
and for living plankton pools.
"""
function plot_contributions(times, data; figure_path=joinpath("figures", "diagnostic_01_relative_nitrogen_contributions.png"))
    mkpath(dirname(figure_path))

    N = _get(data, :N)
    D = _get(data, :D)
    phytoplankton = _sum_matching(data, r"^P\d*$")
    zooplankton = _sum_matching(data, r"^Z\d*$")

    fig = Figure(; size=(1100, 750), fontsize=20)

    ax1 = Axis(fig[1, 1];
        xlabel="Time (days)",
        ylabel="Relative contribution",
        title="Relative nitrogen pools")
    _stacked_relative_area!(ax1, times, [
        "N" => N,
        "D" => D,
        "P" => phytoplankton,
        "Z" => zooplankton,
    ])
    axislegend(ax1; position=:rt)

    ax2 = Axis(fig[2, 1];
        xlabel="Time (days)",
        ylabel="Relative contribution",
        title="Relative living plankton pools")
    _stacked_relative_area!(ax2, times, [
        "P" => phytoplankton,
        "Z" => zooplankton,
    ])
    axislegend(ax2; position=:rt)

    save(figure_path, fig)
    return fig
end

"""
    default_plankton_diameters()

Return simple illustrative diameters for the Quickstart P and Z groups.

These are workshop diagnostics, not a claim about the package defaults.
"""
default_plankton_diameters() = Dict(:P1 => 1.0, :P2 => 5.0, :Z1 => 20.0, :Z2 => 80.0)

function _matching_groups(data, diameters, pattern::Regex)
    groups = [key for key in keys(data) if occursin(pattern, String(key)) && haskey(diameters, key)]
    return sort(groups; by=string)
end

function _community_weighted_mean_size(data, diameters, groups)
    isempty(groups) && return zeros(length(first(values(data))))

    biomass_matrix = reduce(hcat, [_get(data, group) for group in groups])
    sizes = [diameters[group] for group in groups]
    total_biomass = vec(sum(biomass_matrix; dims=2)) .+ eps()

    return [sum(biomass_matrix[i, j] * sizes[j] for j in eachindex(groups)) / total_biomass[i]
            for i in axes(biomass_matrix, 1)]
end

"""
    plot_size_spectrum(times, data; diameters, figure_path)

Plot community-weighted mean plankton size through time in three subplots:
for the full plankton community, phytoplankton only, and zooplankton only.
"""
function plot_size_spectrum(times, data; diameters=default_plankton_diameters(),
                            figure_path=joinpath("figures", "diagnostic_03_size_spectrum.png"))
    mkpath(dirname(figure_path))

    phytoplankton_groups = _matching_groups(data, diameters, r"^P\d*$")
    zooplankton_groups = _matching_groups(data, diameters, r"^Z\d*$")
    plankton_groups = vcat(phytoplankton_groups, zooplankton_groups)

    mean_size = _community_weighted_mean_size(data, diameters, plankton_groups)
    phytoplankton_mean_size = _community_weighted_mean_size(data, diameters, phytoplankton_groups)
    zooplankton_mean_size = _community_weighted_mean_size(data, diameters, zooplankton_groups)

    fig = Figure(; size=(1100, 1050), fontsize=20)

    ax1 = Axis(fig[1, 1];
        xlabel="Time (days)",
        ylabel="CWM diameter (μm)",
        title="Community mean size through time")
    lines!(ax1, times, mean_size; label="P + Z")
    axislegend(ax1; position=:rt)

    ax2 = Axis(fig[2, 1];
        xlabel="Time (days)",
        ylabel="CWM diameter (μm)",
        title="Phytoplankton mean size through time")
    lines!(ax2, times, phytoplankton_mean_size; label="P")
    axislegend(ax2; position=:rt)

    ax3 = Axis(fig[3, 1];
        xlabel="Time (days)",
        ylabel="CWM diameter (μm)",
        title="Zooplankton mean size through time")
    lines!(ax3, times, zooplankton_mean_size; label="Z")
    axislegend(ax3; position=:rt)

    save(figure_path, fig)
    return fig
end

"""
    default_predation_matrix(; cannibalism=false)

Return a simple illustrative predation matrix for the Quickstart groups.

Rows are predators, columns are prey. Values indicate possible interaction strength.
This is an interpretable workshop matrix rather than a direct extraction from internals.
"""
function default_predation_matrix(; cannibalism=false)
    groups = [:P1, :P2, :Z1, :Z2]
    matrix = zeros(length(groups), length(groups))

    # Zooplankton graze phytoplankton.
    matrix[3, 1] = 1.0
    matrix[3, 2] = 0.6
    matrix[4, 1] = 0.4
    matrix[4, 2] = 1.0

    # Larger zooplankton can graze smaller zooplankton.
    matrix[4, 3] = 0.3

    if cannibalism
        matrix[3, 3] = 0.15
        matrix[4, 4] = 0.15
    end

    return (; groups, matrix)
end

"""
    summarize_predation_matrix(groups, matrix)

Return simple trophic-structure diagnostics for a predation matrix.
"""
function summarize_predation_matrix(groups, matrix)
    prey_per_predator = vec(sum(matrix .> 0; dims=2))
    predators_per_prey = vec(sum(matrix .> 0; dims=1))
    possible_links = length(matrix)
    active_links = count(>(0), matrix)
    diagonal_links = count(>(0), diag(matrix))

    return (;
        active_links,
        possible_links,
        connectance=active_links / possible_links,
        cannibalism_links=diagonal_links,
        prey_per_predator=Dict(groups .=> prey_per_predator),
        predators_per_prey=Dict(groups .=> predators_per_prey),
    )
end

"""
    plot_trophic_interactions(groups, matrix; figure_path)

Plot a predation matrix and simple prey/predator counts.
"""
function plot_trophic_interactions(groups, matrix; figure_path=joinpath("figures", "diagnostic_04_trophic_interactions.png"))
    mkpath(dirname(figure_path))

    summary = summarize_predation_matrix(groups, matrix)

    fig = Figure(; size=(1100, 750), fontsize=20)

    ax1 = Axis(fig[1, 1];
        xlabel="Prey",
        ylabel="Predator",
        title="Predation matrix",
        xticks=(1:length(groups), String.(groups)),
        yticks=(1:length(groups), String.(groups)))
    heatmap!(ax1, 1:length(groups), 1:length(groups), matrix')
    ax1.yreversed = true

    ax2 = Axis(fig[1, 2];
        xlabel="Predator",
        ylabel="Number of prey",
        title="Diet breadth",
        xticks=(1:length(groups), String.(groups)))
    barplot!(ax2, 1:length(groups), [summary.prey_per_predator[g] for g in groups])

    ax3 = Axis(fig[2, 1:2];
        xlabel="Prey",
        ylabel="Number of predators",
        title="Vulnerability",
        xticks=(1:length(groups), String.(groups)))
    barplot!(ax3, 1:length(groups), [summary.predators_per_prey[g] for g in groups])

    save(figure_path, fig)
    return fig
end

end # module
