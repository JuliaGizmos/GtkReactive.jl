using Gtk.ShortNames, GtkReactive, Graphics, Colors

win = Window("Drawing")
c = canvas(UserUnit)       # create a canvas with user-specified coordinates
push!(win, c)

const lines = Signal([])   # the list of lines that we'll draw
const newline = Signal([]) # the in-progress line (will be added to list above)

# Add mouse interactions
const drawing = Signal(false)  # this will be true if we're dragging a new line
sigstart = map(c.mouse.buttonpress) do btn
    if btn.button == 1 && btn.modifiers == 0
        push!(drawing, true)   # start extending the line
        push!(newline, [btn.position])
    end
end

const dummybutton = MouseButton{UserUnit}()
sigextend = map(filterwhen(drawing, dummybutton, c.mouse.motion)) do btn
    push!(newline, push!(value(newline), btn.position))
end

sigend = map(c.mouse.buttonrelease) do btn
    if btn.button == 1
        push!(drawing, false)  # stop extending the line
        push!(lines, push!(value(lines), value(newline)))
        push!(newline, [])
    end
end

# Draw on the canvas
redraw = draw(c, lines, newline) do cnvs, lns, newl
    fill!(cnvs, colorant"white")   # background is white
    set_coordinates(cnvs, BoundingBox(0, 1, 0, 1))  # set coords to 0..1 along each axis
    ctx = getgc(cnvs)
    for l in lns
        drawline(ctx, l, colorant"blue")
    end
    drawline(ctx, newl, colorant"red")
end

function drawline(ctx, l, color)
    isempty(l) && return
    p = first(l)
    move_to(ctx, p.x, p.y)
    set_source(ctx, color)
    for i = 2:length(l)
        p = l[i]
        line_to(ctx, p.x, p.y)
    end
    stroke(ctx)
end

Gtk.showall(win)
