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
]

# Run from the workshop root so relative paths in examples are predictable.
cd(workshop_root) do
    mkpath("figures")
    mkpath("outputs")

    for file in example_files
        source = joinpath(examples_dir, file)

        # Generate and execute the rendered documentation page.
        #
        # Executing here lets CI pre-run the examples and include generated figures
        # in the deployed documentation.
        Literate.markdown(
            source,
            docs_exercises_dir;
            documenter = true,
            execute = true,
            credit = false,
        )
    end
end

makedocs(
    sitename = "Agate.jl workshop 2026-05",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        assets = String[],
    ),
    modules = Module[],
    pages = [
        "Home" => "index.md",
        "Setup" => "setup.md",
        "Examples" => [
            "00 Setup Check" => "exercises/00_setup_check.md",
        ],
    ],
)

deploydocs(
    repo = "github.com/agate-model/workshops.git",
    devbranch = "main",
    push_preview = true,
)
