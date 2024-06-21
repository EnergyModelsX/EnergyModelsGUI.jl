# Define a type for sparse variables to simplify code
const SparseVars = Union{JuMP.Containers.SparseAxisArray,SparseVariables.IndexedVarArray}

# Create a type for all Clickable objects in the gui.axes[:topo]
const Plotable = Union{
    Nothing,EMB.Node,EMB.Link,EMG.Area,EMG.Transmission,EMG.TransmissionMode
} # Types that can trigger an update in the gui.axes[:results] plot

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
and representative period `rp`
"""
function get_scenario_indices(T::TS.TimeStructure, sp::Int64, rp::Int64)
    if eltype(T.operational) <: TS.RepresentativePeriods
        if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
            return (1:(T.operational[sp].rep_periods[rp].len))
        else
            return (1:(T.operational[sp].len))
        end
    elseif eltype(T.operational) <: TS.RepresentativePeriods
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
    stepify(x::Vector{S},
        y::Vector{T};
        start_at_zero::Bool = true
    ) where {S <: Number, T <: Number}

For a data set (`x`,`y`) add intermediate points to obtain a stepwise function and add a
point at zero if `start_at_zero = true`
"""
function stepify(
    x::Vector{S}, y::Vector{T}; start_at_zero::Bool=true
) where {S<:Number,T<:Number}
    return if start_at_zero
        (vcat(0, repeat(x[1:(end - 1)]; inner=2), x[end]), repeat(y; inner=2))
    else
        (vcat(repeat(x; inner=2), x[end]), vcat(y[1], repeat(y[2:end]; inner=2)))
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
    exists(data::JuMP.Containers.DenseAxisArray, node::Plotable)

Check if `node` exist in the `data` structure.
"""
function exists(data::JuMP.Containers.DenseAxisArray, node::Plotable)
    if isnothing(node)
        return false
    end
    for axis ∈ axes(data), entry ∈ axis
        if entry == node
            return true
        end
    end
    return false
end

"""
    exists(data::SparseVars, node::Plotable)

Check if `node` exist in the `data` structure.
"""
function exists(data::SparseVars, node::Plotable)
    if isnothing(node)
        return false
    end
    for key ∈ keys(data.data), entry ∈ key
        if entry == node
            return true
        end
    end
    return false
end
