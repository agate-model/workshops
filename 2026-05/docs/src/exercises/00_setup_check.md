```@meta
EditURL = "../../../examples/00_setup_check.jl"
```

# Setup check

Run this script to check that the Docker environment is setup correctly.

````julia
using Agate

println("Agate.jl loaded successfully.")
println("Active project: ", Base.active_project())
````

````
Agate.jl loaded successfully.
Active project: /home/phyto/workshops/2026-05/docs/Project.toml

````

The setup check is complete if this file runs without errors.

