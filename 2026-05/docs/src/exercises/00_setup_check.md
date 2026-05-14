```@meta
EditURL = "../../../examples/00_setup_check.jl"
```

# Setup check

This short example checks that the Agate.jl workshop environment is available.

It is both a runnable Julia script and a rendered documentation page.

````julia
using Agate

println("Agate.jl loaded successfully.")
println("Active project: ", Base.active_project())
````

````
Agate.jl loaded successfully.
Active project: /home/joost/workshops/2026-05-22/docs/Project.toml

````

The setup check is complete if this file runs without errors.

