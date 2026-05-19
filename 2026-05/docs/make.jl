using Pkg

Pkg.activate(@__DIR__)
Pkg.instantiate()

using Literate
using Documenter

workshop_root = normpath(joinpath(@__DIR__, ".."))

examples_dir = joinpath(workshop_root, "examples")
docs_src_dir = joinpath(@__DIR__, "src")
docs_exercises_dir = joinpath(docs_src_dir, "generated")
mkpath(docs_exercises_dir)

# Literate executes generated pages from docs/src/exercises. This small shim
# lets the examples keep the simple path they use when run from examples/.
docs_support_src_dir = joinpath(docs_src_dir, "src")
mkpath(docs_support_src_dir)
write(
    joinpath(docs_support_src_dir, "WorkshopSetup.jl"),
    "include(joinpath(@__DIR__, \"..\", \"..\", \"..\", \"src\", \"WorkshopSetup.jl\"))\n",
)

example_files = [
    "00_setup_check.jl",
    "01_quick_start.jl",
    "02_diagnostics.jl",
    "03_allometric_scaling.jl",
    "04_number_and_size.jl",
    "05_palatability.jl",
    "06_diffusivity.jl",
    "07_irradiance.jl",
]

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
        )
    end
end

makedocs(
    sitename="Agate.jl workshop 2026-05",
    format=Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=String[],
        size_threshold_warn=1_000_000,
        size_threshold=2_000_000,
    ),
    modules=Module[],
    pages=[
        "Home" => "index.md",
        "Setup" => "setup.md",
        "Examples" => [
            "00 Setup Check" => "generated/00_setup_check.md",
            "01 Quick Start" => "generated/01_quick_start.md",
            "02 Diagnostics" => "generated/02_diagnostics.md",
            "03 Allometric Scaling" => "generated/03_allometric_scaling.md",
            "04 Number and Size" => "generated/04_number_and_size.md",
            "05 Palatability" => "generated/05_palatability.md",
            "06 Diffusivity" => "generated/06_diffusivity.md",
            "07 Irradiance" => "generated/07_irradiance.md",
        ],
    ],
)

deploydocs(
    repo="github.com/agate-model/workshops.git",
    devbranch="main",
    push_preview=true,
)
