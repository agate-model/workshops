# # Setup check
#
# Run this script to check that the Docker environment is setup correctly.
#

using Agate

println("Agate.jl loaded successfully.")
println("Active project: ", Base.active_project())

# The setup check is complete if this file runs without errors.
