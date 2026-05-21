using Pkg

Pkg.activate(@__DIR__)

workshop_root = normpath(joinpath(@__DIR__, ".."))
Pkg.instantiate()

using Literate
using Documenter

examples_dir = joinpath(workshop_root, "examples")
docs_src_dir = joinpath(@__DIR__, "src")
docs_exercises_dir = joinpath(docs_src_dir, "generated")
mkpath(docs_exercises_dir)


example_files = [
    "00_setup_check.jl",
    "01_quick_start.jl",
    "02_diagnostics.jl",
    "03_allometric_scaling.jl",
    "04_number_size_classes.jl",
    "05_size_range.jl",
    "06_palatability.jl",
    "07_assimilation_efficiency.jl",
    "08_closure_terms.jl",
    "09_irradiance_box.jl",
    "10_irradiance_column.jl",
    "11_diffusivity_stratified.jl",
    "12_diffusivity_seasonal.jl",
]

function strip_jld2_warnings(content)
    return replace(
        content,
        r"(?ms)^┌ Warning:.*?^└ @ JLD2 .*?/(writing_datatypes|reconstructing_datatypes)\.jl:\d+\n" => "",
    )
end

# Run from the workshop root so relative paths in examples are predictable.
cd(workshop_root) do
    mkpath("figures")
    mkpath("outputs")

    for file in example_files
        source = joinpath(examples_dir, file)

        # Generate and execute the rendered documentation page.
        # Executing here lets CI pre-run examples and include generated figures
        # in the deployed documentation.
        Literate.markdown(
            source,
            docs_exercises_dir;
            documenter=true,
            execute=true,
            credit=false,
            postprocess=strip_jld2_warnings,
        )
    end
end

# Quarto renders slide decks into slides/_site before this script runs in CI.
# Copy that site into docs/src before makedocs so Documenter can validate
# local links to the rendered slide HTML.
slides_site_src = joinpath(workshop_root, "slides", "_site")
slides_docs_src = joinpath(docs_src_dir, "slides")

if isdir(slides_site_src)
    isdir(slides_docs_src) && rm(slides_docs_src; recursive=true, force=true)
    cp(slides_site_src, slides_docs_src)
else
    @warn "Quarto slide output not found before makedocs; slide links may be unavailable" slides_site_src
end

makedocs(
    sitename="Agate.jl workshop 2026-05",
    format=Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=String[],
        size_threshold_warn=1_000_000,
        size_threshold=2_100_000,
    ),
    modules=Module[],
    pages=[
        "Home" => "index.md",
        "Setup" => "setup.md",
        "Workshop slides" => "lectures.md",
        "Examples" => [
            "00 Setup Check" => "generated/00_setup_check.md",
            "01 Quick Start" => "generated/01_quick_start.md",
            "02 Diagnostics" => "generated/02_diagnostics.md",
            "03 Allometric Scaling" => "generated/03_allometric_scaling.md",
            "04 Number of Size Classes" => "generated/04_number_size_classes.md",
            "05 Size Range" => "generated/05_size_range.md",
            "06 Palatability" => "generated/06_palatability.md",
            "07 Assimilation Efficiency" => "generated/07_assimilation_efficiency.md",
            "08 Closure Terms" => "generated/08_closure_terms.md",
            "09 Irradiance Box" => "generated/09_irradiance_box.md",
            "10 Irradiance Column" => "generated/10_irradiance_column.md",
            "11 Diffusivity Stratified" => "generated/11_diffusivity_stratified.md",
            "12 Diffusivity Seasonal" => "generated/12_diffusivity_seasonal.md",
        ],
    ],
)
# Ensure rendered slides are present in the final build output even if a
# future Documenter version changes how non-markdown files are copied.
slides_build_dst = joinpath(@__DIR__, "build", "slides")
if isdir(slides_site_src)
    isdir(slides_build_dst) && rm(slides_build_dst; recursive=true, force=true)
    cp(slides_site_src, slides_build_dst)
end

deploydocs(
    repo="github.com/agate-model/workshops.git",
    devbranch="main",
    push_preview=true,
)
