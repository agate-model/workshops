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
       plot_nitrogen_pools,
       plot_persistence,
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

"""
    plot_nitrogen_pools(times, data; figure_path)

Plot nutrient, phytoplankton, zooplankton, detritus, plankton, and total nitrogen pools.
"""
function plot_nitrogen_pools(times, data; figure_path=joinpath("figures", "diagnostic_01_nitrogen_pools.png"))
    mkpath(dirname(figure_path))

    N = _get(data, :N)
    D = _get(data, :D)
    P1 = _get(data, :P1)
    P2 = _get(data, :P2)
    Z1 = _get(data, :Z1)
    Z2 = _get(data, :Z2)

    phytoplankton = P1 .+ P2
    zooplankton = Z1 .+ Z2
    plankton = phytoplankton .+ zooplankton
    total = N .+ D .+ plankton

    fig = Figure(; size=(1100, 750), fontsize=20)

    ax1 = Axis(fig[1, 1];
        xlabel="Time (days)",
        ylabel="Nitrogen (mmol N m⁻³)",
        title="Nitrogen pools")

    lines!(ax1, times, N, label="Nutrient")
    lines!(ax1, times, phytoplankton, label="Phytoplankton")
    lines!(ax1, times, zooplankton, label="Zooplankton")
    lines!(ax1, times, D, label="Detritus")
    lines!(ax1, times, total, label="Total")
    axislegend(ax1; position=:rt)

    ax2 = Axis(fig[2, 1];
        xlabel="Time (days)",
        ylabel="Fraction of living plankton N",
        title="Relative contribution of plankton groups")

    living = plankton .+ eps()
    lines!(ax2, times, P1 ./ living, label="P1")
    lines!(ax2, times, P2 ./ living, label="P2")
    lines!(ax2, times, Z1 ./ living, label="Z1")
    lines!(ax2, times, Z2 ./ living, label="Z2")
    ylims!(ax2, 0, 1)
    axislegend(ax2; position=:rt)

    save(figure_path, fig)
    return fig
end

"""
    plot_persistence(times, data; threshold, figure_path)

Plot biomass by group and the number of groups above a persistence threshold.
"""
function plot_persistence(times, data; threshold=1e-6, figure_path=joinpath("figures", "diagnostic_02_persistence.png"))
    mkpath(dirname(figure_path))

    groups = [:P1, :P2, :Z1, :Z2]
    matrix = reduce(hcat, [_get(data, g) for g in groups])
    survivors = vec(sum(matrix .> threshold; dims=2))

    fig = Figure(; size=(1100, 750), fontsize=20)

    ax1 = Axis(fig[1, 1];
        xlabel="Time (days)",
        ylabel="Biomass (mmol N m⁻³)",
        title="Group biomass")
    for (i, g) in enumerate(groups)
        lines!(ax1, times, matrix[:, i], label=String(g))
    end
    axislegend(ax1; position=:rt)

    ax2 = Axis(fig[2, 1];
        xlabel="Time (days)",
        ylabel="Groups above threshold",
        title="Persistence threshold = $(threshold)")
    lines!(ax2, times, survivors)
    ylims!(ax2, 0, length(groups) + 0.5)

    save(figure_path, fig)
    return fig
end

"""
    default_plankton_diameters()

Return simple illustrative diameters for the Quickstart P and Z groups.

These are workshop diagnostics, not a claim about the package defaults.
"""
default_plankton_diameters() = Dict(:P1 => 1.0, :P2 => 5.0, :Z1 => 20.0, :Z2 => 80.0)

"""
    plot_size_spectrum(times, data; diameters, figure_path)

Plot final biomass against illustrative plankton diameters and the biomass-weighted
mean plankton size through time.
"""
function plot_size_spectrum(times, data; diameters=default_plankton_diameters(),
                            figure_path=joinpath("figures", "diagnostic_03_size_spectrum.png"))
    mkpath(dirname(figure_path))

    groups = [:P1, :P2, :Z1, :Z2]
    sizes = [diameters[g] for g in groups]
    biomass_matrix = reduce(hcat, [_get(data, g) for g in groups])
    final_biomass = biomass_matrix[end, :]

    total_biomass = vec(sum(biomass_matrix; dims=2)) .+ eps()
    mean_size = [sum(biomass_matrix[i, j] * sizes[j] for j in eachindex(groups)) / total_biomass[i]
                 for i in axes(biomass_matrix, 1)]

    fig = Figure(; size=(1100, 750), fontsize=20)

    ax1 = Axis(fig[1, 1];
        xlabel="Diameter (μm)",
        ylabel="Final biomass (mmol N m⁻³)",
        title="Final biomass by illustrative size class",
        xscale=log10)
    scatter!(ax1, sizes, final_biomass; markersize=22)
    for (x, y, g) in zip(sizes, final_biomass, groups)
        text!(ax1, x, y; text=String(g), align=(:left, :bottom), offset=(5, 5))
    end

    ax2 = Axis(fig[2, 1];
        xlabel="Time (days)",
        ylabel="Biomass-weighted diameter (μm)",
        title="Community mean size through time")
    lines!(ax2, times, mean_size)

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
