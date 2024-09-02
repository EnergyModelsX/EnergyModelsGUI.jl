# Define a type for sparse variables to simplify code
const SparseVars = Union{JuMP.Containers.SparseAxisArray,SparseVariables.IndexedVarArray}

# Create a type for all Clickable objects in the get_axes(gui)[:topo]
const Plotable = Union{Nothing,EMB.Node,Link,Area,Transmission,TransmissionMode} # Types that can trigger an update in the get_axes(gui)[:results] plot

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
    get_max_installed(n, t::Vector{S})

Get the maximum capacity installable by an investemnt.
"""
function get_max_installed(n::EMB.Node, t::Vector{S}) where {S<:TS.TimeStructure}
    if EMI.has_investment(n)
        time_profile = EMI.max_installed(EMI.investment_data(n, :cap))
        return maximum(time_profile[t])
    else
        return 0.0
    end
end
function get_max_installed(n::Storage, t::Vector{S}) where {S<:TS.TimeStructure}
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
function get_max_installed(
    n::EMG.TransmissionMode, t::Vector{S}
) where {S<:TS.TimeStructure}
    if EMI.has_investment(n)
        time_profile = EMI.max_installed(EMI.investment_data(n, :cap))
        return maximum(time_profile[t])
    else
        return 0.0
    end
end
function get_max_installed(
    trans::EMG.Transmission, t::Vector{S}
) where {S<:TS.TimeStructure}
    return maximum([get_max_installed(m, t) for m ∈ modes(trans)])
end
function get_max_installed(::Any, ::Vector{S}) where {S<:TS.TimeStructure}
    return 0.0
end
