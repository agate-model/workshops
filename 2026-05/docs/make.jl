using Pkg

Pkg.activate(@__DIR__)
Pkg.instantiate()

using Literate
using Documenter

workshop_root = normpath(joinpath(@__DIR__, ".."))

examples_dir = joinpath(workshop_root, "examples")
docs_src_dir = joinpath(@__DIR__, "src")
docs_exercises_dir = joinpath(docs_src_dir, "exercises")
mkpath(docs_exercises_dir)
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
    ),
    modules=Module[],
    pages=[
        "Home" => "index.md",
        "Setup" => "setup.md",
        "Examples" => [
            "00 Setup Check" => "exercises/00_setup_check.md",
            "01 Quick Start" => "exercises/01_quick_start.md",
            "02 Diagnostics" => "exercises/02_diagnostics.md",
            "03 Allometric Scaling" => "exercises/03_allometric_scaling.md",
            "04 Number and Size" => "exercises/04_number_and_size.md",
            "05 Palatability" => "exercises/05_palatability.md",
            "06 Diffusivity" => "exercises/06_diffusivity.md",
            "07 Irradiance" => "exercises/07_irradiance.md",
        ],
    ],
)

deploydocs(
    repo="github.com/agate-model/workshops.git",
    devbranch="main",
    push_preview=true,
)
