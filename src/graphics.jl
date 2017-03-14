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

Graphics.getgc(c::Canvas) = Graphics.getgc(c.canvas)
Graphics.width(c::Canvas) = Graphics.width(c.canvas)
Graphics.height(c::Canvas) = Graphics.height(c.canvas)


# # Coordiantes could be AbstractFloat without an implied step, so let's
# # use intervals instead of ranges
# immutable ZoomInfo{T}
#     fullview::Tuple{ClosedInterval{T},ClosedInterval{T}}
#     currentview::Tuple{ClosedInterval{T},ClosedInterval{T}}
# end

# function ZoomInfo{I<:Integer}(inds::Tuple{AbstractUnitRange{I},AbstractUnitRange{I}})
#     fullview = map(ClosedInterval{RInt}, inds)
#     current = Signal(fullview)
#     ZoomInfo(fullview, current)
# end
# ZoomInfo(img::AbstractMatrix) = ZoomInfo(indices(img))

# reset(zi::ZoomInfo) = ZoomInfo(zi.fullview, zi.fullview)

# function panzoom_scroll(zi::ZoomInfo, event::MouseScroll;
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
#     yview, xview = zi.currentview
#     yviewlimits, xviewlimits = zi.fullview
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
#         return zoom_focus(zi, s, event.position; focus=focus)
#     end
#     ZoomInfo(zi.fullview, (yview, xview))
# end

# function zoom_click(zi::ZoomInfo, event::MouseButton;
#                     initiate = BUTTON_PRESS,
#                     reset = DOUBLE_BUTTON_PRESS)
#     if event.clicktype == initiate
#         # FIXME
#         rubberband_start(widget, event.x, event.y, (widget, bb) -> zoom_bb(widget, bb, user_to_data))
#     elseif event.clicktype == reset
#         reset(zi)
#     end
# end


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
