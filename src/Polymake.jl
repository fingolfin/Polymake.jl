module Polymake

export pm_Integer, pm_Rational,
    pm_perl_Object, pm_perl_PropertyValue,
    pm_Set, pm_Vector, pm_Array, pm_Matrix,
    PolymakeError


# We need to import all functions which will be extended on the Cxx side
import Base: ==, <, <=, *, -, +, /, div, rem,
    append!, delete!, numerator, denominator,
    empty!, getindex, in, intersect, intersect!, isempty,
    length, numerator, push!, resize!,
    setdiff, setdiff!, setindex!, symdiff, symdiff!,
    union, union!

using CxxWrap

struct PolymakeError <: Exception
    msg
end

function Base.showerror(io::IO, ex::PolymakeError)
    print(io, "Exception occured at Polymake side:\n$(ex.msg)")
end

###########################
# Load Cxx stuff and init
##########################

@static if Sys.isapple()
    @wrapmodule(joinpath(@__DIR__, "..", "deps", "src", "libpolymake.dylib"),
        :define_module_polymake)
elseif Sys.islinux()
    @wrapmodule(joinpath(@__DIR__, "..", "deps", "src", "libpolymake.so"),
        :define_module_polymake)
else
    error("System is not supported!")
end

const C_TYPES = [
   ("pm_perl_PropertyValue", pm_perl_PropertyValue),
   ("pm_perl_OptionSet", pm_perl_OptionSet),
   ("pm_perl_Object", pm_perl_Object),
   ("pm_Integer", pm_Integer),
   ("pm_Rational", pm_Rational),
   ("pm_Matrix_pm_Integer", pm_Matrix{pm_Integer}),
   ("pm_Matrix_pm_Rational", pm_Matrix{pm_Rational}),
   ("pm_Vector_pm_Integer", pm_Vector{pm_Integer}),
   ("pm_Vector_pm_Rational", pm_Vector{pm_Rational}),
   ("pm_Set_Int64", pm_Set{Int64}),
   ("pm_Set_Int32", pm_Set{Int32}),
   ("pm_Array_Int32", pm_Array{Int32}),
   ("pm_Array_Int64", pm_Array{Int64}),
   ("pm_Array_String", pm_Array{String}),
   ("pm_Array_pm_Set_Int32", pm_Matrix{pm_Set{Int32}}),
   ("pm_Array_pm_Matrix_pm_Integer", pm_Array{pm_Matrix{pm_Integer}}),
]

include("repl.jl")

function __init__()
    @initcxx
    try
        initialize_polymake()
    catch ex # initialize_polymake throws jl_error
        throw(PolymakeError(ex.msg))
    end
    application("common")
    shell_execute("include(\"$(joinpath(@__DIR__, "..", "deps", "rules", "julia.rules"))\");")
    startup_apps = convert_from_property_value(call_function("startup_applications",Array{Any,1}([])))
    for app in startup_apps
        application(app)
    end
    application("polytope")

    # We need to set the Julia types as c types for polymake
    for (name, c_type) in C_TYPES
        current_type = Ptr{Cvoid}(pointer_from_objref(c_type))
        set_julia_type(name, current_type)
    end

    if isdefined(Base, :active_repl)
        run_polymake_repl()
    end
end

const SmallObject = Union{pm_Integer, pm_Rational, pm_Matrix, pm_Vector, pm_Set, pm_Array}

include("functions.jl")
include("convert.jl")
include("object_helpers.jl")
include("integers.jl")
include("rationals.jl")
include("sets.jl")
include("vectors.jl")
include("matrices.jl")
include("arrays.jl")

includes = joinpath("generated", "includes.jl")
if isfile(joinpath(@__DIR__, includes))
    include(includes)
else
    @warn("You need to run '] build Polymake' first.")
end

end # of module Polymake
