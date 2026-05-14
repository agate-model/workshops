# # Setup check
#
# This short example checks that the Agate.jl workshop environment is available.
#
# It is both a runnable Julia script and a rendered documentation page.

using Agate

println("Agate.jl loaded successfully.")
println("Active project: ", Base.active_project())

# The setup check is complete if this file runs without errors.
