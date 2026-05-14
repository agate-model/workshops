using Pkg

Pkg.activate(@__DIR__)
Pkg.instantiate()

using Literate
using Documenter

workshop_root = normpath(joinpath(@__DIR__, ".."))

examples_dir = joinpath(workshop_root, "examples")
scripts_dir = joinpath(workshop_root, "scripts")
docs_src_dir = joinpath(@__DIR__, "src")
docs_exercises_dir = joinpath(docs_src_dir, "exercises")
docs_assets_dir = joinpath(docs_src_dir, "assets")

mkpath(scripts_dir)
mkpath(docs_exercises_dir)
mkpath(docs_assets_dir)

example_files = [
    "00_setup_check.jl",
]

# Run from the workshop root so relative paths in examples are predictable.
cd(workshop_root) do
    mkpath("figures")
    mkpath("outputs")

    for file in example_files
        source = joinpath(examples_dir, file)

        # Generate the runnable participant script from the same source file.
        Literate.script(
            source,
            scripts_dir;
            keep_comments = true,
            credit = false,
        )

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
    sitename = "Agate.jl workshop",
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
