"""
    update_info_box!(gui::GUI, element; indent::Int64=0)

Based on `element` update the text in info box.
"""
function update_info_box!(gui::GUI, element)
    info_box = get_ax(gui, :info).scene.plots[1][1]
    if isnothing(element)
        info_box[] = get_var(gui, :default_text)
        return nothing
    end
    info_box[] = ""
    print_nested_structure!(
        element,
        info_box;
        vector_limit = 5,
        show_the_n_last_elements = 1,
    )
end

"""
    print_nested_structure!(
        element,
        output;
        indent::Int64=0,
        vector_limit::Int64=typemax(Int64),
    )

Appends the nested structure of element in a nice format to the output[] string. The
parameter `vector_limit` is used to truncate large vectors.
"""
function print_nested_structure!(
    element,
    output;
    indent::Int64 = 0,
    vector_limit::Int64 = typemax(Int64),
    show_the_n_last_elements::Int64 = 3,
)
    if indent == 0
        if isa(element, Dict) || isa(element, Vector)
            output[] *= "$(typeof(element))\n"
        else
            output[] *= "$element ($(typeof(element)))\n"
        end
    end
    indent += 1
    indent_str::String = "  "^indent
    expandable::Union = Union{
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
    if isa(element, Vector)
        if eltype(element) <: expandable
            for (i, field1) ∈ enumerate(element)
                if i == vector_limit + 1
                    output[] *= indent_str * "...\n"
                    continue
                end
                if i <= vector_limit || i > length(element) - show_the_n_last_elements
                    if isa(field1, expandable)
                        output[] *= indent_str * "$i ($(typeof(field1))):\n"
                        print_nested_structure!(field1, output; indent, vector_limit)
                    else
                        output[] *= indent_str * "$i: $(typeof(field1))($field1)\n"
                    end
                end
            end
        else
            output[] *= indent_str * "["
            for (i, field1) ∈ enumerate(element)
                if i == vector_limit + 1
                    output[] *= " ... "
                    continue
                end
                if i <= vector_limit || i > length(element) - show_the_n_last_elements
                    output[] *= "$field1"
                    if i != length(element)
                        output[] *= ", "
                    end
                end
            end
            output[] *= "]\n"
        end
    elseif isa(element, Dict)
        for field1 ∈ keys(element)
            if isa(element[field1], expandable)
                output[] *= indent_str * "$field1 ($(typeof(element[field1]))):\n"
                print_nested_structure!(element[field1], output; indent, vector_limit)
            else
                output[] *= indent_str * "$field1 => $(element[field1])\n"
            end
        end
    else
        for field1 ∈ fieldnames(typeof(element))
            value1 = getfield(element, field1)
            if isa(value1, expandable)
                output[] *= indent_str * "$(field1) ($(typeof(value1))):\n"
                print_nested_structure!(value1, output; indent, vector_limit)
            else
                if isa(value1, OperationalProfile) &&
                   !isa(value1, FixedProfile) &&
                   length(value1.vals) > vector_limit
                    # Truncate large vectors
                    output[] *= indent_str * "$(field1): $(typeof(value1))\n"
                else
                    output[] *= indent_str * "$(field1): $value1\n"
                end
            end
        end
    end
end
