# Define a type for sparse variables to simplify code
const SparseVars = Union{JuMP.Containers.SparseAxisArray,SparseVariables.IndexedVarArray}

"""
    get_representative_period_indices(T::TS.TimeStructure, sp::Int64)

Return indices in the time structure `T` of the representative periods for strategic
period `sp`.
"""
function get_representative_period_indices(T::TS.TimeStructure, sp::Int64)
    return if eltype(T.operational) <: TS.RepresentativePeriods
        (1:(T.operational[sp].len))
    else
        [1]
    end
end

"""
    get_scenario_indices(T::TS.TimeStructure, sp::Int64, rp::Int64)

Return indices of the scenarios in the time structure `T` for strategic period number `sp`
and representative period `rp`.
"""
function get_scenario_indices(T::TS.TimeStructure, sp::Int64, rp::Int64)
    if eltype(T.operational) <: TS.RepresentativePeriods
        if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
            return (1:(T.operational[sp].rep_periods[rp].len))
        else
            return [1]
        end
    elseif eltype(T.operational) <: TS.OperationalScenarios
        return (1:(T.operational[sp].len))
    else
        return [1]
    end
end

"""
    get_op(tp::TS.TimePeriod)

Get the operational period of TimePeriod `tp`.
"""
function get_op(tp::TS.TimePeriod)
    if :period in fieldnames(typeof(tp))
        return get_op(tp.period)
    else
        return tp.op
    end
end

"""
    get_supertypes(x::Any)

Return the vector of the supertypes of `x`.
"""
function get_supertypes(x::Any)
    T = typeof(x)
    supertypes = [T]
    while T != Any
        T = supertype(T)
        push!(supertypes, T)
    end
    return supertypes
end

"""
    find_type_field(dict::Dict, x::Any)

Return closest supertype of a key being of same type as `x`.
"""
function find_type_field(dict::Dict, x::Any)
    for supertype ∈ get_supertypes(x)
        if haskey(dict, supertype)
            return supertype
        end
    end
    return Nothing
end

"""
    get_nested_value(dict::Dict, keys_str::String)

Get value of a `nested` dict based on keys in the string `key_str` separated by periods.
"""
function get_nested_value(dict::Dict, keys_str::String)
    keys = split(keys_str, ".")
    current_value = dict
    for key ∈ keys
        if haskey(current_value, Symbol(key))
            current_value = current_value[Symbol(key)]
        end
    end
    return current_value
end

"""
    get_nth_field(s::String, delimiter::Char, n::Int)

Get `n`'th value of a string `s` separated by the character `delimiter`.
"""
function get_nth_field(s::String, delimiter::Char, n::Int)
    fields = split(s, delimiter)
    return length(fields) >= n ? fields[n] : ""
end

"""
    merge_dicts(dict1::Dict, dict2::Dict)

Merge `dict1` and `dict2` (in case of overlap, `dict2` overwrites entries in `dict1`).
"""
function merge_dicts(dict1::Dict, dict2::Dict)
    merged = deepcopy(dict1)
    for (k, v) ∈ dict2
        if haskey(merged, k)
            if isa(merged[k], Dict) && isa(v, Dict)
                merged[k] = merge_dicts(merged[k], v)
            else
                merged[k] = v
            end
        else
            merged[k] = v
        end
    end
    return merged
end

"""
    nested_eltype(x::TimeProfile)

Return the type of the lowest TimeProfile, of a nested TimeProfile `x`, not being a FixedProfile.
"""
function nested_eltype(x::TimeProfile)
    y = typeof(x)
    while y <: TimeProfile && length(y.parameters) > 1 && !(y.parameters[2] <: FixedProfile)
        y = y.parameters[2]
    end
    return y
end

"""
    format_number(x::Number)

Format number `x` to two decimals and add thousands seperators (comma).
"""
function format_number(x::Number)
    # Format the number with two decimal places using @sprintf
    formatted_number = @sprintf("%.2f", x)

    # Add separator (comma)
    return replace(formatted_number, r"(?<=\d)(?=(\d{3})+\.)" => ",")
end

"""
    get_max_installed(n, t::Vector{<:TS.TimeStructure})

Get the maximum capacity installable by an investemnt.
"""
function get_max_installed(n::EMB.Node, t::Vector{<:TS.TimeStructure})
    if EMI.has_investment(n)
        time_profile = EMI.max_installed(EMI.investment_data(n, :cap))
        return maximum(time_profile[t])
    else
        return 0.0
    end
end
function get_max_installed(n::Storage, t::Vector{<:TS.TimeStructure})
    if EMI.has_investment(n)
        storage_data = [
            EMI.investment_data(n, :charge),
            EMI.investment_data(n, :level),
            EMI.investment_data(n, :discharge),
        ]

        time_profiles = [EMI.max_installed(d) for d ∈ storage_data if !isnothing(d)]
        return maximum([maximum(x[t]) for x ∈ time_profiles])
    else
        return 0.0
    end
end
function get_max_installed(::Any, ::Vector{<:TS.TimeStructure})
    return 0.0
end

"""
    mouse_within_axis(ax::Makie.AbstractAxis, mouse_pos::Tuple{Float32,Float32})

Check if mouse position is within the pixel area of `ax`.
"""
function mouse_within_axis(ax::Makie.AbstractAxis, mouse_pos::Tuple{Float32,Float32})
    origin::Vec2{Int64} = pixelarea(ax.scene)[].origin
    widths::Vec2{Int64} = pixelarea(ax.scene)[].widths
    mouse_pos_loc::Vec2{Float32} = mouse_pos .- origin

    return all(mouse_pos_loc .> 0.0f0) && all(mouse_pos_loc .- widths .< 0.0f0)
end

"""
    scroll_ylim(ax::Makie.AbstractAxis, val::Float64)

Shift the ylim with `val` units to mimic scrolling feature of an axis `ax`.
"""
function scroll_ylim(ax::Makie.AbstractAxis, val::Float64)
    ylim = collect(ax.yaxis.attributes.limits[])
    ylim .+= val
    if ylim[2] > 1
        ylim = (0, 1)
    end
    ylims!(ax, ylim[1], ylim[2])
end

"""
    _type_to_header(::Type{<:TS.AbstractStrategicPeriod})
    _type_to_header(::Type{<:TS.AbstractRepresentativePeriod})
    _type_to_header(::Type{<:TS.AbstractOperationalScenario})
    _type_to_header(::Type{<:TS.TimePeriod})
    _type_to_header(::Type{<:TS.TimeStructure})
    _type_to_header(::Type{<:Resource})
    _type_to_header(::Type{<:AbstractElement})

Map types to header symbols for saving results.
"""
_type_to_header(::Type{<:TS.AbstractStrategicPeriod}) = :sp
_type_to_header(::Type{<:TS.AbstractRepresentativePeriod}) = :rp
_type_to_header(::Type{<:TS.AbstractOperationalScenario}) = :osc
_type_to_header(::Type{<:TS.TimePeriod}) = :t
_type_to_header(::Type{<:TS.TimeStructure}) = :t
_type_to_header(::Type{<:Resource}) = :res
_type_to_header(::Type{<:AbstractElement}) = :element

"""
    save_results(model::Model; directory=joinpath(pwd(),"csv_files"))

Saves the model results of all variables as CSV files and metadata as a yml-file.
If no directory is specified, it will create, if necessary, a new directory "csv_files" in
the current working directory and save the files in said directory.
"""
function save_results(model::Model; directory = joinpath(pwd(), "csv_files"))
    if !ispath(directory)
        mkpath(directory)
    end

    # Write each variable to a CSV file
    Threads.@threads for v ∈ collect(keys(object_dictionary(model)))
        if !isempty(model[v])
            datatypes::Vector = get_jump_axis_types(model[v])
            headers::Vector{Symbol} = _type_to_header.(datatypes)
            push!(headers, :val)
            fn = joinpath(directory, string(v) * ".csv")
            CSV.write(
                fn,
                JuMP.Containers.rowtable(value, model[v]);
                header = headers,
            )
        end
    end

    # Write metadata to a YAML file
    metadata = Dict(
        "name" => JuMP.name(model),
        "solver" => JuMP._try_solver_name(model),
        "objective_sense" => objective_sense(model),
        "num_variables" => num_variables(model),
        "objective_value" => objective_value(model),
        "termination_status" => termination_status(model),
        "date" => string(Dates.now()),
        "EnergyModelsGUI version" => installed()["EnergyModelsGUI"],
    )
    metadata_file = joinpath(directory, "metadata.yaml")
    open(metadata_file, "w") do io
        YAML.write(io, metadata)
    end
end

"""
    get_types(input) -> Vector{Symbol}

Retrieves the names of all defined types from modules or packages.

# Method Overloads

- `get_types(modul::Module)`:
  Returns a vector of type names defined in the given module.

- `get_types(moduls::Vector{Module})`:
  Returns a combined vector of type names from multiple modules.

- `get_types(pkg::Union{String, Symbol})`:
  Converts the package name to a module (via `Main`) and returns its defined types.

- `get_types(pkgs::Union{Vector{<:Union{String, Symbol}}, Set{<:Union{String, Symbol}}})`:
  Returns a combined vector of type names from multiple packages.

# Arguments
- `input`: Can be a single module, a vector of modules, a single package name (as `String` or `Symbol`), or a collection of package names.

# Returns
- `Vector{Symbol}`: A list of names corresponding to types defined in the given module(s) or package(s).

# Description
This set of functions helps extract type definitions from Julia modules or packages. It filters out non-type bindings and collects only those that are instances of `DataType`.

# Example
```julia
get_types(Base)  # returns type names defined in Base

get_types(["Base", "Core"])  # returns type names from both packages
```
"""
function get_types(modul::Module)
    types = []
    for name ∈ names(modul)
        if isdefined(modul, name) && getfield(modul, name) isa DataType
            push!(types, name)
        end
    end
    return types
end

function get_types(moduls::Vector{Module})
    types=[]
    for modul ∈ moduls
        append!(types, get_types(modul))
    end
    return types
end

function get_types(pkg::Union{String,Symbol})
    return get_types(getfield(Main, Symbol(pkg)))
end

function get_types(pkgs::Union{Vector{<:Union{String,Symbol}},Set{<:Union{String,Symbol}}})
    types = []
    for pkg ∈ pkgs
        append!(types, get_types(pkg))
    end
    return types
end

"""
    get_supertypes(input) -> Dict{Symbol, Vector{Type}}

Retrieves the supertypes of all defined types from modules or packages.

# Method Overloads

- `get_supertypes(modul::Module)`:
  Returns a dictionary mapping type names to their supertypes from the given module.

- `get_supertypes(moduls::Vector{Module})`:
  Merges and returns supertypes from multiple modules.

- `get_supertypes(pkg::Union{String, Symbol})`:
  Converts the package name to a module (via `Main`) and returns its type supertypes.

- `get_supertypes(pkgs::Union{Vector{<:Union{String, Symbol}}, Set{<:Union{String, Symbol}}})`:
  Merges and returns supertypes from multiple packages via their names.

# Arguments
- `input`: Can be a single module, a vector of modules, a single package name (as `String` or `Symbol`), or a collection of package names.

# Returns
- `Dict{Symbol, Vector{Type}}`: A dictionary where each key is a type name and the value is a vector of its supertypes.

# Description
This set of functions helps extract the inheritance hierarchy of types defined in Julia modules or packages. It filters out non-type bindings and collects supertypes using `supertypes`.

"""
function get_supertypes(modul::Module)
    types=Dict()
    for name ∈ names(modul)
        if isdefined(modul, name) && getfield(modul, name) isa DataType
            types[name] = supertypes(getfield(modul, name))
        end
    end
    return types
end

function get_supertypes(moduls::Vector{Module})
    types=Dict()
    for modul ∈ moduls
        merge!(types, get_supertypes(modul))
    end
    return types
end

function get_supertypes(pkg::Union{String,Symbol})
    return get_supertypes(getfield(Main, Symbol(pkg)))
end

function get_supertypes(
    pkgs::Union{Vector{<:Union{String,Symbol}},Set{<:Union{String,Symbol}}},
)
    types = Dict()
    for pkg ∈ pkgs
        merge!(types, get_supertypes(pkg))
    end
    return types
end

"""
    has_fields(type::Type) -> Bool

Checks whether a given type is a concrete struct with at least one field.

# Arguments
- `type::Type`: The type to be inspected.

# Returns
- `Bool`: Returns `true` if the type is a concrete struct and has one or more fields; otherwise, returns `false`.

# Description
This function combines three checks:
- `isconcretetype(type)`: Ensures the type is concrete (i.e., can be instantiated).
- `isstructtype(type)`: Ensures the type is a struct.
- `nfields(type) > 0`: Ensures the struct has at least one field.

# Example
```julia
struct MyStruct
    x::Int
end

has_fields(MyStruct)  # returns true

abstract type AbstractType end
has_fields(AbstractType)  # returns false
```
"""
function has_fields(type)
    return (isconcretetype(type) && isstructtype(type) && nfields(type) > 0)
end

"""
    update_tree!(current_lvl::Dict{Type, Union{Dict, Nothing}}, tmp_type::Type) -> Nothing

Ensures that a given type exists as a key in the current level of a nested type dependency dictionary.

# Arguments
- `current_lvl::Dict{Type, Union{Dict, Nothing}}`: The current level of the nested dictionary structure representing type dependencies.
- `tmp_type::Type`: The type to be added as a key in the current level if it does not already exist.

# Behavior
If `tmp_type` is not already a key in `current_lvl`, it adds it with an empty dictionary as its value, preparing for further nesting.

# Returns
- `Nothing`: This function modifies `current_lvl` in-place and does not return a value.

"""
function update_tree!(current_lvl, tmp_type::Type)
    if !haskey(current_lvl, tmp_type)
        current_lvl[tmp_type] = Dict{Type,Union{Dict,Nothing}}()
    end
    return
end

"""
    get_types_structure(emx_supertypes_dict::Dict{Any, Vector{Type}}) -> Dict{Type, Union{Dict, Nothing}}

Constructs a nested dictionary representing type dependencies from a dictionary of supertypes.

# Arguments
- `emx_supertypes_dict::Dict{Any, Vector{Type}}`: A dictionary where each key corresponds to a type identifier, and the value is a vector of supertypes ordered from the most general to the most specific.

# Returns
- `Dict{Type, Union{Dict, Nothing}}`: A nested dictionary structure where each type is a key pointing to its subtype hierarchy. Leaf nodes point to `nothing`.

# Description
This function builds a tree-like structure of type dependencies by iterating through each type's supertypes and nesting them accordingly. It uses the helper function `update_tree!` to insert types into the correct level of the hierarchy.
```
"""
function get_types_structure(emx_supertypes_dict)
    # make a visualization of the type dependencies by building a nested dictionary of types
    emx_type_dependencies = Dict{Type,Union{Dict,Nothing}}()
    for (emx_type_id, emx_supertypes) ∈ emx_supertypes_dict
        i = 0
        current_lvl = emx_type_dependencies
        while i < length(emx_supertypes)
            tmp_type = emx_supertypes[end-i]
            update_tree!(current_lvl, tmp_type)
            current_lvl = current_lvl[tmp_type]
            i+=1
        end
    end
    return emx_type_dependencies
end

"""
    inherit_descriptive_names_from_supertypes!(descriptive_names, emx_supertypes_dict)

Copies descriptive field names from supertypes to subtypes in the `descriptive_names` dictionary.

# Arguments
- `descriptive_names::Dict`: A dictionary containing descriptive names for structure fields,
 organized by type.
- `emx_supertypes_dict::Dict`: A dictionary mapping type identifiers to arrays of types,
 where the first element is the type itself and the remaining elements are its supertypes.

# Description
For each type in `emx_supertypes_dict`, this function checks if the type has fields.
For each field, it looks for descriptive names in the supertypes.
If a descriptive name exists for a field in a supertype but not in the subtype,
 it copies the descriptive name from the supertype to the subtype.

# Modifies
- Updates `descriptive_names` in-place by inheriting missing descriptive names from supertypes.
"""
function inherit_descriptive_names_from_supertypes!(descriptive_names, emx_supertypes_dict)
    for (emx_type_id, emx_supertypes) ∈ emx_supertypes_dict
        emx_type = emx_supertypes[1]
        # check if emx_type has field names and if so retrieve them, otherwise continue
        if !has_fields(emx_type)
            continue
        end
        emx_type_fieldnames = fieldnames(emx_type)
        for fname ∈ emx_type_fieldnames
            for emx_supertype ∈ emx_supertypes[2:end] # skip first element as it is the type itself
                #check if the supertype has an entry in descriptive names for fname
                # Extract only what is after the dot in emx_supertype, if any
                supertype_str = string(emx_supertype)
                supertype_key =
                    occursin(r"\.", supertype_str) ?
                    match(r"\.([^.]+)$", supertype_str).captures[1] : supertype_str
                if haskey(descriptive_names[:structures], Symbol(supertype_key)) &&
                   haskey(
                    descriptive_names[:structures][Symbol(supertype_key)],
                    Symbol(fname),
                )
                    # if so, and if the emx_type does not have an entry for fname, copy it
                    if !haskey(descriptive_names[:structures], Symbol(emx_type)) ||
                       !haskey(
                        descriptive_names[:structures][Symbol(emx_type)],
                        Symbol(fname),
                    )
                        if !haskey(descriptive_names[:structures], Symbol(emx_type))
                            descriptive_names[:structures][Symbol(emx_type)] =
                                Dict{Symbol,Any}()
                        end
                        descriptive_names[:structures][Symbol(emx_type)][Symbol(fname)] =
                            descriptive_names[:structures][Symbol(supertype_key)][Symbol(
                                fname,
                            )]
                    end
                end
            end
        end
    end
end
