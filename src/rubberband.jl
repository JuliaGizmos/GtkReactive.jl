"""
    signals = init_zoom_rubberband(canvas::GtkReactive.Canvas,
                                   zr::Signal{ZoomRegion},
                                   initiate = btn->(btn.button == 1 && btn.clicktype == BUTTON_PRESS && btn.modifiers == CONTROL),
                                   reset = btn->(btn.button == 1 && btn.clicktype == DOUBLE_BUTTON_PRESS && btn.modifiers == CONTROL),
                                   minpixels = 2)

Initialize rubber-band selection that updates `zr`. `signals` is a
dictionary holding the Reactive.jl signals needed for rubber-banding;
you can push `true/false` to `signals["enabled"]` to turn rubber
banding on and off, respectively. Your application is responsible for
making sure that `signals` does not get garbage-collected (which would
turn off rubberbanding).

`initiate(btn)` returns `true` when the condition for starting a
rubber-band selection has been met (by default, clicking mouse button
1). The argument `btn` is a [`MouseButton`](@ref) event. `reset(btn)`
returns true when restoring the full view (by default, double-clicking
mouse button 1). `minpixels` can be used for aborting rubber-band
selections smaller than some threshold.
"""
function init_zoom_rubberband{U,T}(canvas::Canvas{U},
                                   zr::Signal{ZoomRegion{T}},
                                   initiate::Function = zrb_init_default,
                                   reset::Function = zrb_reset_default,
                                   minpixels::Integer = 2)
    enabled = Signal(true)
    active = Signal(false)
    function update_zr(widget, bb)
        push!(active, false)
        push!(zr, ZoomRegion(value(zr).fullview, bb))
        nothing
    end
    rb = RubberBand(MousePosition{U}(-1,-1), MousePosition{U}(-1,-1), false, minpixels)
    dummybtn = MouseButton(MousePosition{U}(-1, -1), 0, 0, 0)
    local ctxcopy
    init = map(filterwhen(enabled, dummybtn, canvas.mouse.buttonpress)) do btn
        if initiate(btn)
            push!(active, true)
            ctxcopy = copy(getgc(canvas))
            rb.pos1 = rb.pos2 = btn.position
        elseif reset(btn)
            push!(active, false)  # double-clicks need to cancel the previous single-click
            push!(zr, GtkReactive.reset(value(zr)))
        end
        nothing
    end
    drag = map(filterwhen(active, dummybtn, canvas.mouse.motion)) do btn
        btn.button == 0 && return nothing
        rubberband_move(canvas, rb, btn, ctxcopy)
    end
    finish = map(filterwhen(active, dummybtn, canvas.mouse.buttonrelease)) do btn
        btn.button == 0 && return nothing
        push!(active, false)
        rubberband_stop(canvas, rb, btn, ctxcopy, update_zr)
    end
    Dict("enabled"=>enabled, "active"=>active, "init"=>init, "drag"=>drag, "finish"=>finish)
end

zrb_init_default(btn) = btn.button == 1 && btn.clicktype == BUTTON_PRESS && btn.modifiers == CONTROL
zrb_reset_default(btn) = btn.button == 1 && btn.clicktype == DOUBLE_BUTTON_PRESS && btn.modifiers == CONTROL

# For rubberband, we draw the selection region on the front canvas, and repair
# by copying from the back.
type RubberBand{U}
    pos1::MousePosition{U}
    pos2::MousePosition{U}
    moved::Bool
    minpixels::Int
end

const dash   = Float64[3.0,3.0]
const nodash = Float64[]

function rb_erase(r::GraphicsContext, rb::RubberBand, ctxcopy)
    # Erase the previous rubberband by copying from back surface to front
    rb_set(r, rb)
    # Because line widths are expressed in pixels, let's go to device units
    save(r)
    reset_transform(r)
    save(ctxcopy)
    reset_transform(ctxcopy)
    set_source(r, ctxcopy)
    set_line_width(r, 3)
    set_dash(r, nodash)
    stroke(r)
    restore(r)
    restore(ctxcopy)
end

function rb_draw(r::GraphicsContext, rb::RubberBand)
    rb_set(r, rb)
    save(r)
    reset_transform(r)
    set_line_width(r, 1)
    set_dash(r, dash, 3.0)
    set_source_rgb(r, 1, 1, 1)
    stroke_preserve(r)
    set_dash(r, dash, 0.0)
    set_source_rgb(r, 0, 0, 0)
    stroke(r)
    restore(r)
end

function rb_set(r::GraphicsContext, rb::RubberBand)
    x1, y1 = rb.pos1.x, rb.pos1.y
    x2, y2 = rb.pos2.x, rb.pos2.y
    rectangle(r, x1, y1, x2 - x1, y2 - y1)
end

function rubberband_move(c::Canvas, rb::RubberBand, btn, ctxcopy)
    if btn.button == 0
        return nothing
    end
    r = getgc(c)
    if rb.moved
        rb_erase(r, rb, ctxcopy)
    end
    rb.moved = true
    # Draw the new rubberband
    rb.pos2 = btn.position
    rb_draw(r, rb)
    reveal(c, false)
    nothing
end

function rubberband_stop(c::GtkReactive.Canvas, rb::RubberBand, btn, ctxcopy, callback_done)
    if !rb.moved
        return nothing
    end
    r = getgc(c)
    rb_set(r, rb)
    rb_erase(r, rb, ctxcopy)
    reveal(c, false)
    pos = btn.position
    x, y = pos.x, pos.y
    x1, y1 = rb.pos1.x, rb.pos1.y
    xd, yd = convertunits(DeviceUnit, r, x, y)
    x1d, y1d = convertunits(DeviceUnit, r, x1, y1)
    if abs(x1d-xd) > rb.minpixels || abs(y1d-yd) > rb.minpixels
        # It moved sufficiently, let's execute the callback
        bb = BoundingBox(min(x1,x), max(x1,x), min(y1,y), max(y1,y))
        callback_done(c, bb)
    end
    nothing
end
