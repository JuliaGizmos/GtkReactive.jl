# Much of this is event-handling to support interactivity

using Gtk.GConstants: GDK_KEY_Left, GDK_KEY_Right, GDK_KEY_Up, GDK_KEY_Down
using Gtk.GConstants.GdkEventMask: KEY_PRESS, SCROLL

@compat abstract type CairoUnit end
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
    xu, yu = Graphics.device_to_user(Graphics.getgc(c), x.val, y.val)
    UserUnit(xu), UserUnit(yu)
end
function convertunits(::Type{UserUnit}, c, x::UserUnit, y::UserUnit)
    x, y
end
function convertunits(::Type{DeviceUnit}, c, x::DeviceUnit, y::DeviceUnit)
    x, y
end
function convertunits(::Type{DeviceUnit}, c, x::UserUnit, y::UserUnit)
    xd, yd = Graphics.user_to_device(Graphics.getgc(c), x.val, y.val)
    DeviceUnit(xd), DeviceUnit(yd)
end
convert{T<:Number}(::Type{T}, x::CairoUnit) = T(x.val)
Base.promote_rule{T<:Number,C<:CairoUnit}(::Type{T}, ::Type{C}) = promote_type(T, Float64)

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
    canvas::GtkCanvas
    mouse::MouseHandler{U}

    function (::Type{Canvas{U}}){U}(w::Integer=-1, h::Integer=-1)
        canvas = GtkCanvas(w, h)
        # Delete the Gtk handlers
        for id in canvas.mouse.ids
            signal_handler_disconnect(canvas, id)
        end
        empty!(canvas.mouse.ids)
        # Initialize our own handlers
        mouse = MouseHandler{U}(canvas)
        setproperty!(canvas, :is_focus, true)
        new{U}(canvas, mouse)
    end
end
canvas{U<:CairoUnit}(::Type{U}=DeviceUnit, w::Integer=-1, h::Integer=-1) = Canvas{U}(w, h)
canvas(w::Integer, h::Integer) = canvas(DeviceUnit, w, h)


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
    fullview = XY(map(ClosedInterval{RInt}, inds)...)
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
    zoom_rubberband!(zr::Signal{ZoomRegion}, canvas::Canvas, event::MouseButton)

Initiate a rubber-band selection and, when finished, update `zr`.
"""
function zoom_rubberband!(zr::Signal{ZoomRegion}, canvas::Canvas, event::MouseButton)
    rubberband_start(canvas, event.position, (widget, bb) -> push!(zr, ZoomRegion(value(zr).fullview, bb)))
    zr
end


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

## Junk

# function panzoom_scroll(zr::ZoomRegion, event::MouseScroll;
#                         # Panning
#                         xpan = SHIFT,
#                         ypan  = 0,
#                         xpanflip = false,
#                         ypanflip  = false,
#                         # Zooming
#                         zoom = CONTROL,
#                         focus::Symbol = :pointer,
#                         factor = 2.0)
#     focus == :pointer || focus == :center || error("focus must be :pointer or :center")
#     xview, yview = zr.currentview.x, zr.currentview.y
#     xviewlimits, yviewlimits = zr.fullview.x, zr.fullview.y
#     s = 0.1*scrollpm(event.direction)
#     xscroll = (event.direction == LEFT) || (event.direction == RIGHT)
#     if xpan != nothing && (xscroll || event.modifiers == UInt32(xpan))
#         xview = pan(xview, (xpanflip ? -1 : 1) * s, xviewlimits)
#     elseif ypan != nothing && event.modifiers == UInt32(ypan)
#         yview = pan(yview, (ypanflip  ? -1 : 1) * s, yviewlimits)
#     elseif zoom != nothing && event.modifiers == UInt32(zoom)
#         s = factor
#         if event.direction == UP
#             s = 1/s
#         end
#         return zoom_focus(zr, s, event.position; focus=focus)
#     end
#     ZoomRegion(zr.fullview, XY(xview, yview))
# end
