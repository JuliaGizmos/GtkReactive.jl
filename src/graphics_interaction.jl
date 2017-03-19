# Much of this is event-handling to support interactivity

using Gtk.GConstants: GDK_KEY_Left, GDK_KEY_Right, GDK_KEY_Up, GDK_KEY_Down
using Gtk.GConstants.GdkEventMask: KEY_PRESS, SCROLL

@compat abstract type CairoUnit <: Number end

Base.:+{U<:CairoUnit}(x::U, y::U) = U(x.val + y.val)
Base.:-{U<:CairoUnit}(x::U, y::U) = U(x.val - y.val)
Base.abs{U<:CairoUnit}(x::U) = U(abs(x.val))
Base.min{U<:CairoUnit}(x::U, y::U) = U(min(x.val, y.val))
Base.max{U<:CairoUnit}(x::U, y::U) = U(max(x.val, y.val))
Base.:<{U<:CairoUnit}(x::U, y::U) = x.val < y.val
Base.:<(x::CairoUnit, y::Number) = x.val < y
Base.:<(x::Number, y::CairoUnit) = x < y.val
Base.convert{T<:Number}(::Type{T}, x::CairoUnit) = T(x.val)
Base.promote_rule{T<:Number,U<:CairoUnit}(::Type{T}, ::Type{U}) = promote_type(T, Float64)

"""
    DeviceUnit(x)

Represent a number `x` as having "device" units (aka, screen
pixels). See the Cairo documentation.
"""
immutable DeviceUnit <: CairoUnit
    val::Float64
end

"""
    UserUnit(x)

Represent a number `x` as having "user" units, i.e., whatever units
have been established with [`set_coords`](@ref). See the Cairo
documentation.
"""
immutable UserUnit <: CairoUnit
    val::Float64
end

function convertunits(::Type{UserUnit}, c, x::DeviceUnit, y::DeviceUnit)
    xu, yu = device_to_user(getgc(c), x.val, y.val)
    UserUnit(xu), UserUnit(yu)
end
function convertunits(::Type{UserUnit}, c, x::UserUnit, y::UserUnit)
    x, y
end
function convertunits(::Type{DeviceUnit}, c, x::DeviceUnit, y::DeviceUnit)
    x, y
end
function convertunits(::Type{DeviceUnit}, c, x::UserUnit, y::UserUnit)
    xd, yd = user_to_device(getgc(c), x.val, y.val)
    DeviceUnit(xd), DeviceUnit(yd)
end

Graphics.rectangle(r::GraphicsContext, x::UserUnit, y::UserUnit, w::UserUnit, h::UserUnit) =
    rectangle(r, x.val, y.val, w.val, h.val)

"""
    MousePosition(x, y)

A type to hold mouse positions. Units of `x` and `y` are either
[`DeviceUnit`](@ref) or [`UserUnit`](@ref).
"""
immutable MousePosition{U<:CairoUnit}
    x::U
    y::U

    # Curiously, this is required for ambiguity resolution
    function (::Type{MousePosition{U}}){U<:CairoUnit}(x::U, y::U)
        new{U}(x, y)
    end
end
MousePosition{U<:CairoUnit}(x::U, y::U) = MousePosition{U}(x, y)
(::Type{MousePosition{U}}){U}(x::Real, y::Real) = MousePosition{U}(U(x), U(y))
function (::Type{MousePosition{U}}){U}(w::GtkCanvas, evt::Gtk.GdkEvent)
    MousePosition{U}(convertunits(U, w, DeviceUnit(evt.x), DeviceUnit(evt.y))...)
end

"""
    MouseButton(position, button, clicktype, modifiers)

A type to hold information about a mouse button event (e.g., a
click). `position` is the canvas position of the pointer (see
[`MousePosition`](@ref)). `button` is an integer identifying the
button, where 1=left button, 2=middle button, 3=right
button. `clicktype` may be `BUTTON_PRESS` or
`DOUBLE_BUTTON_PRESS`. `modifiers` indicates whether any keys were
held down during the click; they may be any combination of `SHIFT`,
`CONTROL`, or `MOD1` stored as a bitfield (test with `btn.modifiers &
SHIFT`).

The fieldnames are the same as the argument names above.
"""
immutable MouseButton{U<:CairoUnit}
    position::MousePosition{U}
    button::UInt32
    clicktype::typeof(BUTTON_PRESS)
    modifiers::typeof(SHIFT)
end
function MouseButton{U}(pos::MousePosition{U}, button::Integer, clicktype::Integer, modifiers::Integer)
    MouseButton{U}(pos, UInt32(button), oftype(BUTTON_PRESS, clicktype), oftype(SHIFT, modifiers))
end
function (::Type{MouseButton{U}}){U}(w::GtkCanvas, evt::Gtk.GdkEvent)
    MouseButton{U}(MousePosition{U}(w, evt), evt.button, evt.event_type, evt.state)
end

"""
    MouseScroll(position, direction, modifiers)

A type to hold information about a mouse wheel scroll. `position` is the
canvas position of the pointer (see
[`MousePosition`](@ref)). `direction` may be `UP`, `DOWN`, `LEFT`, or
`RIGHT`. `modifiers` indicates whether any keys were held down during
the click; they may be 0 (no modifiers) or any combination of `SHIFT`,
`CONTROL`, or `MOD1` stored as a bitfield.
"""
immutable MouseScroll{U<:CairoUnit}
    position::MousePosition{U}
    direction::typeof(UP)
    modifiers::typeof(SHIFT)
end
function MouseScroll{U}(pos::MousePosition{U}, direction::Integer, modifiers::Integer)
    MouseScroll{U}(pos, oftype(UP, direction), oftype(SHIFT, modifiers))
end
function (::Type{MouseScroll{U}}){U}(w::GtkCanvas, evt::Gtk.GdkEvent)
    MouseScroll{U}(MousePosition{U}(w, evt), evt.direction, evt.state)
end

# immutable KeyEvent
#     keyval
# end

"""
    MouseHandler{U<:CairoUnit}

A type with `Signal` fields for which you can `map` callback actions. The fields are:
  - `button1press` and similar for buttons 2 and 3 (of type [`MouseButton`](@ref));
  - `button1release` and similar for buttons 2 and 3 (of type [`MousePosition`](@ref));
  - `button1motion` and similar for buttons 2 and 3 for drag events (of type [`MousePosition`](@ref));
  - `motion` for tracking continuous movement (of type [`MousePosition`](@ref));
  - `scroll` for wheelmouse or track-pad actions (of type [`MouseScroll`](@ref));

`U` should be either [`DeviceUnit`](@ref) or [`UserUnit`](@ref) and
determines the coordinate system used for reporting mouse positions.
"""
immutable MouseHandler{U<:CairoUnit}
    buttonpress::Signal{MouseButton{U}}
    buttonrelease::Signal{MouseButton{U}}
    motion::Signal{MouseButton{U}}
    scroll::Signal{MouseScroll{U}}
    ids::Vector{Culong}   # for disabling any of these callbacks
    widget::GtkCanvas

    function (::Type{MouseHandler{U}}){U<:CairoUnit}(canvas::GtkCanvas)
        pos = MousePosition(U(-1), U(-1))
        btn = MouseButton(pos, 0, BUTTON_PRESS, SHIFT)
        scroll = MouseScroll(pos, UP, SHIFT)
        ids = Vector{Culong}(0)
        handler = new{U}(Signal(btn), Signal(btn), Signal(btn), Signal(scroll), ids, canvas)
        # Create the callbacks
        push!(ids, Gtk.on_signal_button_press(mousedown_cb, canvas, false, handler))
        push!(ids, Gtk.on_signal_button_release(mouseup_cb, canvas, false, handler))
        push!(ids, Gtk.on_signal_motion(mousemove_cb, canvas, 0, 0, false, handler))
        push!(ids, Gtk.on_signal_scroll(mousescroll_cb, canvas, false, handler))
        handler
    end
end

"""
    GtkReactive.Canvas{U}(w=-1, h=-1)
    canvas(U=DeviceUnit, w=-1, h=-1)

Create a canvas for drawing and interaction. The fields are:
  - `canvas`: the Gtk widget. Access this for purposes of layout.
  - `mouse`: the [`MouseHandler{U}`](@ref) for this canvas.
"""
immutable Canvas{U}
    widget::GtkCanvas
    mouse::MouseHandler{U}
    preserved::Vector{Any}

    function (::Type{Canvas{U}}){U}(w::Integer=-1, h::Integer=-1; own::Bool=true)
        gtkcanvas = GtkCanvas(w, h)
        # Delete the Gtk handlers
        for id in gtkcanvas.mouse.ids
            signal_handler_disconnect(gtkcanvas, id)
        end
        empty!(gtkcanvas.mouse.ids)
        # Initialize our own handlers
        mouse = MouseHandler{U}(gtkcanvas)
        setproperty!(gtkcanvas, :is_focus, true)
        preserved = []
        canvas = new{U}(gtkcanvas, mouse, preserved)
        gc_preserve(gtkcanvas, canvas)
        canvas
    end
end
canvas{U<:CairoUnit}(::Type{U}=DeviceUnit, w::Integer=-1, h::Integer=-1) = Canvas{U}(w, h)
canvas(w::Integer, h::Integer) = canvas(DeviceUnit, w, h)

function Gtk.draw(drawfun::Function, c::Canvas, signals::Signal...)
    draw(c.widget) do widget
        yield()  # allow the Gtk event queue to run
        drawfun(widget, map(value, signals)...)
    end
    drawsig = map((values...)->draw(c.widget), signals...)
    push!(c.preserved, drawsig)
    drawsig
end

# Painting an image to a canvas
function Base.copy!{C<:Union{Colorant,Number}}(ctx::GraphicsContext, img::AbstractArray{C})
    save(ctx)
    reset_transform(ctx)
    Cairo.image(ctx, image_surface(img), 0, 0, Graphics.width(ctx), Graphics.height(ctx))
    restore(ctx)
end
Base.copy!(c::Union{GtkCanvas,Canvas}, img) = copy!(getgc(c), img)
function Base.fill!(c::Union{GtkCanvas,Canvas}, color::Colorant)
    ctx = getgc(c)
    w, h = Graphics.width(c), Graphics.height(c)
    rectangle(ctx, 0, 0, w, h)
    set_source(ctx, color)
    fill(ctx)
end

image_surface(img::Matrix{Gray24}) = Cairo.CairoImageSurface(reinterpret(UInt32, img), Cairo.FORMAT_RGB24)
image_surface(img::Matrix{RGB24})  = Cairo.CairoImageSurface(reinterpret(UInt32, img), Cairo.FORMAT_RGB24)
image_surface(img::Matrix{ARGB32}) = Cairo.CairoImageSurface(reinterpret(UInt32, img), Cairo.FORMAT_ARGB32)

image_surface{T<:Number}(img::AbstractArray{T}) = image_surface(convert(Matrix{Gray24}, img))
image_surface{C<:Color}(img::AbstractArray{C}) = image_surface(convert(Matrix{RGB24}, img))
image_surface{C<:Colorant}(img::AbstractArray{C}) = image_surface(convert(Matrix{ARGB32}, img))


immutable XY{T}
    x::T
    y::T
end
# Coordiantes could be AbstractFloat without an implied step, so let's
# use intervals instead of ranges
immutable ZoomRegion{T}
    fullview::XY{ClosedInterval{T}}
    currentview::XY{ClosedInterval{T}}
end

function ZoomRegion{I<:Integer}(inds::Tuple{AbstractUnitRange{I},AbstractUnitRange{I}})
    ci = map(ClosedInterval{RInt}, inds)
    fullview = XY(ci[2], ci[1])
    ZoomRegion(fullview, fullview)
end
ZoomRegion(img::AbstractMatrix) = ZoomRegion(indices(img))
function ZoomRegion(fullview::XY, bb::BoundingBox)
    xview = oftype(fullview.x, bb.xmin..bb.xmax)
    yview = oftype(fullview.y, bb.ymin..bb.ymax)
    ZoomRegion(fullview, XY(xview, yview))
end

reset(zr::ZoomRegion) = ZoomRegion(zr.fullview, zr.fullview)

function interior(iv::ClosedInterval, limits::AbstractInterval)
    imin, imax = minimum(iv), maximum(iv)
    lmin, lmax = minimum(limits), maximum(limits)
    if imin < lmin
        imin = lmin
        imax = imin + IntervalSets.width(iv)
    elseif imax > lmax
        imax = lmax
        imin = imax - IntervalSets.width(iv)
    end
    oftype(limits, (imin..imax) ∩ limits)
end

function pan(iv::ClosedInterval, frac::Real, limits)
    s = frac*IntervalSets.width(iv)
    interior(minimum(iv)+s..maximum(iv)+s, limits)
end

"""
    pan_x(zr::ZoomRegion, frac) -> zr_new

Pan the x-axis by a fraction `frac` of the current x-view. `frac>0` means
that the coordinates shift right, which corresponds to a leftward
shift of objects.
"""
pan_x(zr::ZoomRegion, s) =
    ZoomRegion(zr.fullview, XY(pan(zr.currentview.x, s, zr.fullview.x), zr.currentview.y))

"""
    pan_y(zr::ZoomRegion, frac) -> zr_new

Pan the y-axis by a fraction `frac` of the current x-view. `frac>0` means
that the coordinates shift downward, which corresponds to an upward
shift of objects.
"""
pan_y(zr::ZoomRegion, s) =
    ZoomRegion(zr.fullview, XY(zr.currentview.x, pan(zr.currentview.y, s, zr.fullview.y)))

function zoom(iv::ClosedInterval, s::Real, limits)
    dw = 0.5*(s - 1)*IntervalSets.width(iv)
    interior(minimum(iv)-dw..maximum(iv)+dw, limits)
end

"""
    zoom(zr::ZoomRegion, scaleview, pos::MousePosition) -> zr_new

Zooms in (`scaleview` < 1) or out (`scaleview` > 1) by a scaling
factor `scaleview`, in a manner centered on `pos`.
"""
function zoom(zr::ZoomRegion, s, pos::MousePosition)
    xview, yview = zr.currentview.x, zr.currentview.y
    xviewlimits, yviewlimits = zr.fullview.x, zr.fullview.y
    centerx, centery = pos.x.val, pos.y.val
    w, h = IntervalSets.width(xview), IntervalSets.width(yview)
    fx, fy = (centerx-minimum(xview))/w, (centery-minimum(yview))/h
    wbb, hbb = s*w, s*h
    xview = interior(ClosedInterval(centerx-fx*wbb,centerx+(1-fx)*wbb), xviewlimits)
    yview = interior(ClosedInterval(centery-fy*hbb,centery+(1-fy)*hbb), yviewlimits)
    ZoomRegion(zr.fullview, XY(xview, yview))
end

"""
    zoom(zr::ZoomRegion, scaleview)

Zooms in (`scaleview` < 1) or out (`scaleview` > 1) by a scaling
factor `scaleview`, in a manner centered around the current view
region.
"""
function zoom(zr::ZoomRegion, s)
    xview, yview = zr.currentview.x, zr.currentview.y
    xviewlimits, yviewlimits = zr.fullview.x, zr.fullview.y
    xview = zoom(xview, s, xviewlimits)
    yview = zoom(yview, s, yviewlimits)
    ZoomRegion(zr.fullview, XY(xview, yview))
end

"""
    signals = init_pan_scroll(canvas::GtkReactive.Canvas,
                              zr::Signal{ZoomRegion},
                              filter_x::Function = evt->evt.modifiers == SHIFT || event.direction == LEFT || event.direction == RIGHT,
                              filter_y::Function = evt->evt.modifiers == 0 || event.direction == UP || event.direction == DOWN,
                              xpanflip = false,
                              ypanflip  = false)

Initialize panning-by-mouse-scroll for `canvas` and update
`zr`. `signals` is a dictionary holding the Reactive.jl signals needed
for scroll-panning; you can push `true/false` to `signals["enabled"]`
to turn scroll-panning on and off, respectively. Your application is
responsible for making sure that `signals` does not get
garbage-collected (which would turn off scroll-panning).

`filter_x` and `filter_y` are functions that return `true` when the
conditions for x- and y-scrolling are met; the argument is a
[`MouseScroll`](@ref) event. The defaults are that vertical scrolling
is triggered with an unmodified scroll, whereas horizontal scrolling
is triggered by scrolling while holding down the SHIFT key.

You can flip the direction of either pan operation with `xpanflip` and
`ypanflip`, respectively.
"""
function init_pan_scroll{U,T}(canvas::Canvas{U},
                              zr::Signal{ZoomRegion{T}},
                              filter_x::Function = evt->evt.modifiers == SHIFT || evt.direction == LEFT || evt.direction == RIGHT,
                              filter_y::Function = evt->evt.modifiers == 0 || evt.direction == UP || evt.direction == DOWN,
                              xpanflip = false,
                              ypanflip  = false)
    enabled = Signal(true)
    dummyscroll = MouseScroll(MousePosition{U}(-1, -1), 0, 0)
    pan = map(filterwhen(enabled, dummyscroll, canvas.mouse.scroll)) do event
        s = 0.1*scrollpm(event.direction)
        if filter_x(event)
            push!(zr, pan_x(value(zr), s))
        elseif filter_y(event)
            push!(zr, pan_y(value(zr), s))
        end
        nothing
    end
    Dict("enabled"=>enabled, "pan"=>pan)
end

"""
    signals = init_zoom_scroll(canvas::GtkReactive.Canvas,
                               zr::Signal{ZoomRegion},
                               filter::Function = evt->evt.modifiers == CONTROL,
                               focus::Symbol = :pointer,
                               factor = 2.0,
                               flip = false)

Initialize zooming-by-mouse-scroll for `canvas` and update
`zr`. `signals` is a dictionary holding the Reactive.jl signals needed
for scroll-zooming; you can push `true/false` to `signals["enabled"]`
to turn scroll-zooming on and off, respectively. Your application is
responsible for making sure that `signals` does not get
garbage-collected (which would turn off scroll-zooming).

`filter` is a function that returns `true` when the conditions for
scroll-zooming are met; the argument is a [`MouseScroll`](@ref)
event. The default is to hold down the CONTROL key while scrolling the
mouse.

The `focus` keyword controls how the zooming progresses as you scroll
the mouse wheel. `:pointer` means that whatever feature of the canvas
is under the pointer will stay there as you zoom in or out. The other
choice, `:center`, keeps the canvas centered on its current location.

You can change the amount of zooming via `factor` and the direction of
zooming with `flip`.
"""
function init_zoom_scroll{U,T}(canvas::Canvas{U},
                               zr::Signal{ZoomRegion{T}},
                               filter::Function = evt->evt.modifiers == CONTROL,
                               focus::Symbol = :pointer,
                               factor = 2.0,
                               flip = false)
    focus == :pointer || focus == :center || error("focus must be :pointer or :center")
    enabled = Signal(true)
    dummyscroll = MouseScroll(MousePosition{U}(-1, -1), 0, 0)
    zm = map(filterwhen(enabled, dummyscroll, canvas.mouse.scroll)) do event
        if filter(event)
            # println("zoom scroll: ", event)
            s = factor
            if event.direction == UP
                s = 1/s
            end
            if flip
                s = 1/s
            end
            if focus == :pointer
                # println("zoom focus: ", event)
                push!(zr, zoom(value(zr), s, event.position))
            else
                # println("zoom center: ", event)
                push!(zr, zoom(value(zr), s))
            end
        end
    end
    Dict("enabled"=>enabled, "zoom"=>zm)
end

scrollpm(direction::Integer) =
    direction == UP ? -1 :
    direction == DOWN ? 1 :
    direction == RIGHT ? 1 :
    direction == LEFT ? -1 : error("Direction ", direction, " not recognized")

##### Callbacks #####
function mousedown_cb{U}(ptr::Ptr, eventp::Ptr, handler::MouseHandler{U})
    evt = unsafe_load(eventp)
    push!(handler.buttonpress, MouseButton{U}(handler.widget, evt))
    Int32(false)
end
function mouseup_cb{U}(ptr::Ptr, eventp::Ptr, handler::MouseHandler{U})
    evt = unsafe_load(eventp)
    push!(handler.buttonrelease, MouseButton{U}(handler.widget, evt))
    Int32(false)
end
function mousemove_cb{U}(ptr::Ptr, eventp::Ptr, handler::MouseHandler{U})
    evt = unsafe_load(eventp)
    pos = MousePosition{U}(handler.widget, evt)
    # This doesn't support multi-button moves well, but those are rare in most GUIs and
    # users can examine `modifiers` directly.
    button = 0
    if evt.state & Gtk.GdkModifierType.BUTTON1 != 0
        button = 1
    elseif evt.state & Gtk.GdkModifierType.BUTTON2 != 0
        button = 2
    elseif evt.state & Gtk.GdkModifierType.BUTTON3 != 0
        button = 3
    end
    push!(handler.motion, MouseButton(pos, button, evt.event_type, evt.state))
    Int32(false)
end
function mousescroll_cb{U}(ptr::Ptr, eventp::Ptr, handler::MouseHandler{U})
    evt = unsafe_load(eventp)
    push!(handler.scroll, MouseScroll{U}(handler.widget, evt))
    Int32(false)
end
