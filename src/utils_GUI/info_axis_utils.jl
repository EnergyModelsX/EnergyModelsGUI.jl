"""
    update_info_box!(gui::GUI, element; indent::Int64=0)

Based on `element` update the text in `gui.axes[:info]`
"""
function update_info_box!(gui::GUI, element; indent::Int64=0)
    infoBox = gui.axes[:info].scene.plots[1][1]
    if isnothing(element)
        infoBox[] = gui.vars[:default_text]
        return nothing
    end
    if indent == 0
        infoBox[] = "$element ($(typeof(element)))\n"
    end
    indent += 1
    indent_str = "  "^indent
    is_iterable(x) =
        isa(x, Vector) || isa(x, Dict) || typeof(x) <: EMB.Node || typeof(x) <: Resource
    if isa(element, Vector)
        for (i, field1) ∈ enumerate(element)
            if is_iterable(field1)
                infoBox[] *= indent_str * "$i: $(typeof(field1)):\n"
                update_info_box!(gui, field1; indent)
            else
                infoBox[] *= indent_str * "$i: $(typeof(field1))\n"
            end
        end
    elseif isa(element, Dict)
        for field1 ∈ keys(element)
            infoBox[] *= indent_str * "$field1 => $(element[field1])\n"
        end
    else
        for field1 ∈ fieldnames(typeof(element))
            value1 = getfield(element, field1)
            if is_iterable(value1)
                infoBox[] *= indent_str * "$(field1) ($(typeof(value1))):\n"
                update_info_box!(gui, value1; indent)
            else
                infoBox[] *= indent_str * "$(field1): $value1\n"
            end
        end
    end
end
