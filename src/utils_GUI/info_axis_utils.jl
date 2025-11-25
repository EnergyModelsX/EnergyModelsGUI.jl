Expandable::Type = Union{
    Vector,
    Dict,
    EMB.Node,
    Resource,
    Link,
    TimeStructure,
    Data,
    AbstractInvData,
    Investment,
    LifetimeMode,
    TimeProfile,
}
"""
    update_info_box!(gui::GUI, element)

Based on `element` update the text in info box.
"""
function update_info_box!(gui::GUI, element)
    info_text = get_var(gui, :info_text)
    if isnothing(element)
        info_text[] = get_var(gui, :default_text)
        return nothing
    end
    io = IOBuffer()
    type = typeof(element)
    if isa(element, Dict) || isa(element, Vector)
        println(io, type)
    else
        println(io, element, " (", type, ")")
    end
    print_nested_structure!(element, io, 0, 5, 1)
    info_text[] = String(take!(io))
end

"""
    create_indent_string(indent::Int64)

Create an indentation string based on the `indent` level.
"""
create_indent_string(indent::Int64) = "  "^indent

"""
    print_nested_structure!(
        element,
        io::IOBuffer,
        indent::Int64,
        vector_limit::Int64,
        show_the_n_last_elements::Int64,
    )

Appends the nested structure of element in a nice format to the `io` buffer for `element`. 
The parameter `indent` tracks the indentation level, the parameter `vector_limit` is used 
to truncate large vectors and `show_the_n_last_elements` specifies how many of the last elements to show.
"""
function print_nested_structure!(
    element::Any,
    io::IOBuffer,
    indent::Int64,
    vector_limit::Int64,
    show_the_n_last_elements::Int64,
)
    indent += 1
    indent_str::String = create_indent_string(indent)
    for field1 ∈ fieldnames(typeof(element))
        value1 = getfield(element, field1)
        if isa(value1, Expandable)
            println(io, indent_str, field1, " (", typeof(value1), "):")
            print_nested_structure!(
                value1,
                io,
                indent,
                vector_limit,
                show_the_n_last_elements,
            )
        else
            if isa(value1, OperationalProfile) &&
               !isa(value1, FixedProfile) &&
               length(value1.vals) > vector_limit
                # Truncate large vectors
                println(io, indent_str, field1, ": ", typeof(value1))
            else
                println(io, indent_str, field1, ": ", value1)
            end
        end
    end
    return nothing
end
function print_nested_structure!(
    element::Dict,
    io::IOBuffer,
    indent::Int64,
    vector_limit::Int64,
    show_the_n_last_elements::Int64,
)
    indent += 1
    indent_str::String = create_indent_string(indent)
    for field1 ∈ keys(element)
        if isa(element[field1], Expandable)
            println(io, indent_str, field1, " (", typeof(element[field1]), "):")
            print_nested_structure!(
                element[field1],
                io,
                indent,
                vector_limit,
                show_the_n_last_elements,
            )
        else
            println(io, indent_str, field1, " => ", element[field1])
        end
    end
end
function print_nested_structure!(
    element::Vector{T},
    io::IOBuffer,
    indent::Int64,
    vector_limit::Int64,
    show_the_n_last_elements::Int64,
) where {T<:Expandable}
    indent += 1
    indent_str::String = create_indent_string(indent)
    for (i, field1) ∈ enumerate(element)
        if i == vector_limit + 1
            println(io, indent_str, "...")
            continue
        end
        if i <= vector_limit || i > length(element) - show_the_n_last_elements
            type = typeof(field1)
            if isa(field1, Expandable)
                println(io, indent_str, i, " (", type, "):")
                print_nested_structure!(
                    field1,
                    io,
                    indent,
                    vector_limit,
                    show_the_n_last_elements,
                )
            else
                println(io, indent_str, i, ": ", type, "(", field1, ")")
            end
        end
    end
    return nothing
end
function print_nested_structure!(
    element::Vector{T},
    io::IOBuffer,
    indent::Int64,
    vector_limit::Int64,
    show_the_n_last_elements::Int64,
) where {T}
    indent += 1
    indent_str::String = create_indent_string(indent)
    print(io, indent_str, "[")

    for (i, field1) ∈ enumerate(element)
        if i == vector_limit + 1
            print(io, " ... ")
            continue
        end
        if i <= vector_limit || i > length(element) - show_the_n_last_elements
            print(io, field1)
            if i != length(element)
                print(io, ", ")
            end
        end
    end
    println(io, "]")
    return nothing
end
