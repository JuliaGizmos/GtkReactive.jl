# Much of this is event-handling to support interactivity

using Gtk.GConstants: GDK_KEY_Left, GDK_KEY_Right, GDK_KEY_Up, GDK_KEY_Down
using Gtk.GConstants.GdkEventMask: KEY_PRESS, SCROLL

@compat abstract type CairoUnit <: Real end

Base.:+{U<:CairoUnit}(x::U, y::U) = U(x.val + y.val)
Base.:-{U<:CairoUnit}(x::U, y::U) = U(x.val - y.val)
Base.:<{U<:CairoUnit}(x::U, y::U) = Bool(x.val < y.val)
Base.:>{U<:CairoUnit}(x::U, y::U) = Bool(x.val > y.val)
Base.abs{U<:CairoUnit}(x::U) = U(abs(x.val))
Base.min{U<:CairoUnit}(x::U, y::U) = U(min(x.val, y.val))
Base.max{U<:CairoUnit}(x::U, y::U) = U(max(x.val, y.val))
# Most of these are for ambiguity resolution
Base.convert{T<:CairoUnit}(::Type{T}, x::T) = x
Base.convert(::Type{Bool}, x::CairoUnit) = convert(Bool, x.val)
Base.convert(::Type{Integer}, x::CairoUnit) = convert(Integer, x.val)
Base.convert{T<:RInteger}(::Type{T}, x::CairoUnit) =
    convert(T, convert(RoundingIntegers.itype(T), x.val))
Base.convert{T<:FixedPointNumbers.Normed}(::Type{T}, x::CairoUnit) = convert(T, x.val)
Base.convert{T<:Real}(::Type{T}, x::CairoUnit) = convert(T, x.val)
# The next three are for ambiguity resolution
Base.promote_rule{U<:CairoUnit}(::Type{Bool}, ::Type{U}) = Float64
Base.promote_rule{U<:CairoUnit}(::Type{BigFloat}, ::Type{U}) = BigFloat
Base.promote_rule{T<:Irrational,U<:CairoUnit}(::Type{T}, ::Type{U}) = promote_type(T, Float64)
Base.promote_rule{T<:Real,U<:CairoUnit}(::Type{T}, ::Type{U}) = promote_type(T, Float64)

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
have been established with calls that affect the transformation
matrix, e.g., [`Graphics.set_coordinates`](@ref) or
[`Cairo.set_matrix`](@ref).
"""
immutable UserUnit <: CairoUnit
    val::Float64
end

showtype(::Type{UserUnit}) = "UserUnit"
showtype(::Type{DeviceUnit}) = "DeviceUnit"

Base.show(io::IO, x::CairoUnit) = print(io, showtype(typeof(x)), '(', x.val, ')')

Base.promote_rule{U<:UserUnit,D<:DeviceUnit}(::Type{U}, ::Type{D}) =
    error("UserUnit and DeviceUnit are incompatible, promotion not defined")

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

"""
    XY(x, y)

A type to hold `x` (horizontal), `y` (vertical) coordinates, where the
number increases to the right and downward. If used to encode mouse
pointer positions, the units of `x` and `y` are either
[`DeviceUnit`](@ref) or [`UserUnit`](@ref).
"""
immutable XY{T}
    x::T
    y::T

    (::Type{XY{T}}){T}(x, y) = new{T}(x, y)
    (::Type{XY{U}}){U<:CairoUnit}(x::U, y::U) = new{U}(x, y)
    (::Type{XY{U}}){U<:CairoUnit}(x::Real, y::Real) = new{U}(U(x), U(y))
end
(::Type{XY}){T}(x::T, y::T) = XY{T}(x, y)
(::Type{XY})(x, y) = XY(promote(x, y)...)

function (::Type{XY{U}}){U<:CairoUnit}(w::GtkCanvas, evt::Gtk.GdkEvent)
    XY{U}(convertunits(U, w, DeviceUnit(evt.x), DeviceUnit(evt.y))...)
end

function Base.show{T<:CairoUnit}(io::IO, xy::XY{T})
    print(io, "XY{$(showtype(T))}(", Float64(xy.x), ", ", Float64(xy.y), ')')
end
Base.show(io::IO, xy::XY) = print(io, "XY(", xy.x, ", ", xy.y, ')')

Base.convert{T}(::Type{XY{T}}, xy::XY{T}) = xy
Base.convert{T}(::Type{XY{T}}, xy::XY) = XY(T(xy.x), T(xy.y))

Base.:+{T}(xy1::XY{T}, xy2::XY{T}) = XY{T}(xy1.x+xy2.x,xy1.y+xy2.y)
Base.:-{T}(xy1::XY{T}, xy2::XY{T}) = XY{T}(xy1.x-xy2.x,xy1.y-xy2.y)

"""
    MouseButton(position, button, clicktype, modifiers)

A type to hold information about a mouse button event (e.g., a
click). `position` is the canvas position of the pointer (see
[`XY`](@ref)). `button` is an integer identifying the
button, where 1=left button, 2=middle button, 3=right
button. `clicktype` may be `BUTTON_PRESS` or
`DOUBLE_BUTTON_PRESS`. `modifiers` indicates whether any keys were
held down during the click; they may be any combination of `SHIFT`,
`CONTROL`, or `MOD1` stored as a bitfield (test with `btn.modifiers &
SHIFT`).

The fieldnames are the same as the argument names above.


    MouseButton{UserUnit}()
    MouseButton{DeviceUnit}()

Create a "dummy" MouseButton event. Often useful for the fallback to
Reactive's `filterwhen`.
"""
immutable MouseButton{U<:CairoUnit}
    position::XY{U}
    button::UInt32
    clicktype::typeof(BUTTON_PRESS)
    modifiers::typeof(SHIFT)
    gtkevent
end
function MouseButton{U}(pos::XY{U}, button::Integer, clicktype::Integer, modifiers::Integer, gtkevent=nothing)
    MouseButton{U}(pos, UInt32(button), oftype(BUTTON_PRESS, clicktype), oftype(SHIFT, modifiers), gtkevent)
end
function (::Type{MouseButton{U}}){U}(w::GtkCanvas, evt::Gtk.GdkEvent)
    MouseButton{U}(XY{U}(w, evt), evt.button, evt.event_type, evt.state, evt)
end
function (::Type{MouseButton{U}}){U}()
    MouseButton(XY(U(-1), U(-1)), 0, 0, 0, nothing)
end

"""
    MouseScroll(position, direction, modifiers)

A type to hold information about a mouse wheel scroll. `position` is the
canvas position of the pointer (see
[`XY`](@ref)). `direction` may be `UP`, `DOWN`, `LEFT`, or
`RIGHT`. `modifiers` indicates whether any keys were held down during
the click; they may be 0 (no modifiers) or any combination of `SHIFT`,
`CONTROL`, or `MOD1` stored as a bitfield.


    MouseScroll{UserUnit}()
    MouseScroll{DeviceUnit}()

Create a "dummy" MouseScroll event. Often useful for the fallback to
Reactive's `filterwhen`.
"""
immutable MouseScroll{U<:CairoUnit}
    position::XY{U}
    direction::typeof(UP)
    modifiers::typeof(SHIFT)
end
function MouseScroll{U}(pos::XY{U}, direction::Integer, modifiers::Integer)
    MouseScroll{U}(pos, oftype(UP, direction), oftype(SHIFT, modifiers))
end
function (::Type{MouseScroll{U}}){U}(w::GtkCanvas, evt::Gtk.GdkEvent)
    MouseScroll{U}(XY{U}(w, evt), evt.direction, evt.state)
end
function (::Type{MouseScroll{U}}){U}()
    MouseScroll(XY(U(-1), U(-1)), 0, 0)
end

# immutable KeyEvent
#     keyval
# end

"""
    MouseHandler{U<:CairoUnit}

A type with `Signal` fields for which you can `map` callback actions. The fields are:
  - `buttonpress` for clicks (of type [`MouseButton`](@ref));
  - `buttonrelease` for release events (of type [`MouseButton`](@ref));
  - `motion` for move and drag events (of type [`MouseButton`](@ref));
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
        pos = XY(U(-1), U(-1))
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
    GtkReactive.Canvas{U}(w=-1, h=-1, own=true)

Create a canvas for drawing and interaction. The relevant fields are:
  - `canvas`: the "raw" Gtk widget (from Gtk.jl)
  - `mouse`: the [`MouseHandler{U}`](@ref) for this canvas.

See also [`canvas`](@ref).
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

"""
    canvas(U=DeviceUnit, w=-1, h=-1) - c::GtkReactive.Canvas

Create a canvas for drawing and interaction. Optionally specify the
width `w` and height `h`. `U` refers to the units for the canvas (for
both drawing and reporting mouse pointer positions), see
[`DeviceUnit`](@ref) and [`UserUnit`](@ref). See also [`GtkReactive.Canvas`](@ref).
"""
canvas{U<:CairoUnit}(::Type{U}=DeviceUnit, w::Integer=-1, h::Integer=-1) = Canvas{U}(w, h)
canvas(w::Integer, h::Integer) = canvas(DeviceUnit, w, h)

"""
    draw(f, c::GtkReactive.Canvas, signals...)

Supply a draw function `f` for `c`. This will be called whenever the
canvas is resized or whenever any of the input `signals` update. `f`
should be of the form `f(cnvs, sigs...)`, where the number of
arguments is equal to 1 + `length(signals)`.

`f` can be defined as a named function, an anonymous function, or
using `do`-block notation:

    using Graphics, Colors

    draw(c, imgsig, xsig, ysig) do cnvs, img, x, y
        copy!(cnvs, img)
        ctx = getgc(cnvs)
        set_source(ctx, colorant"red")
        set_line_width(ctx, 2)
        circle(ctx, x, y, 5)
        stroke(ctx)
    end

This would paint an image-Signal `imgsig` onto the canvas and then
draw a red circle centered on `xsig`, `ysig`.
"""
function Gtk.draw(drawfun::Function, c::Canvas, signals::Signal...)
    @guarded draw(c.widget) do widget
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

image_surface(img::Matrix{Gray24}) =
    Cairo.CairoImageSurface(reinterpret(UInt32, img), Cairo.FORMAT_RGB24)
image_surface(img::Matrix{RGB24})  =
    Cairo.CairoImageSurface(reinterpret(UInt32, img), Cairo.FORMAT_RGB24)
image_surface(img::Matrix{ARGB32}) =
    Cairo.CairoImageSurface(reinterpret(UInt32, img), Cairo.FORMAT_ARGB32)

image_surface{T<:Number}(img::AbstractArray{T}) =
    image_surface(convert(Matrix{Gray24}, img))
image_surface{T<:ColorTypes.AbstractGray}(img::AbstractArray{T}) =
    image_surface(convert(Matrix{Gray24}, img))
image_surface{C<:Color}(img::AbstractArray{C}) =
    image_surface(convert(Matrix{RGB24}, img))
image_surface{C<:Colorant}(img::AbstractArray{C}) =
    image_surface(convert(Matrix{ARGB32}, img))


# Coordiantes could be AbstractFloat without an implied step, so let's
# use intervals instead of ranges
immutable ZoomRegion{T}
    fullview::XY{ClosedInterval{T}}
    currentview::XY{ClosedInterval{T}}
end

"""
    ZoomRegion(fullinds) -> zr
    ZoomRegion(fullinds, currentinds) -> zr
    ZoomRegion(img::AbstractMatrix) -> zr

Create a `ZoomRegion` object `zr` for selecting a rectangular
region-of-interest for zooming and panning. `fullinds` should be a
pair `(yrange, xrange)` of indices, an [`XY`](@ref) object, or pass a
matrix `img` from which the indices will be taken.

`zr.currentview` holds the currently-active region of
interest. `zr.fullview` stores the original `fullinds` from which `zr` was
constructed; these are used to reset to the original limits and to
confine `zr.currentview`.
"""
function ZoomRegion{I<:Integer}(inds::Tuple{AbstractUnitRange{I},AbstractUnitRange{I}})
    ci = map(ClosedInterval{RInt}, inds)
    fullview = XY(ci[2], ci[1])
    ZoomRegion(fullview, fullview)
end
function ZoomRegion{I<:Integer}(fullinds::Tuple{AbstractUnitRange{I},AbstractUnitRange{I}},
                                curinds::Tuple{AbstractUnitRange{I},AbstractUnitRange{I}})
    fi = map(ClosedInterval{RInt}, fullinds)
    ci = map(ClosedInterval{RInt}, curinds)
    ZoomRegion(XY(fi[2], fi[1]), XY(ci[2], ci[1]))
end
ZoomRegion(img) = ZoomRegion(indices(img))
function ZoomRegion(fullview::XY, bb::BoundingBox)
    xview = oftype(fullview.x, bb.xmin..bb.xmax)
    yview = oftype(fullview.y, bb.ymin..bb.ymax)
    ZoomRegion(fullview, XY(xview, yview))
end

reset(zr::ZoomRegion) = ZoomRegion(zr.fullview, zr.fullview)

Base.indices(zr::ZoomRegion) = map(UnitRange, (zr.currentview.y, zr.currentview.x))

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
    zoom(zr::ZoomRegion, scaleview, pos::XY) -> zr_new

Zooms in (`scaleview` < 1) or out (`scaleview` > 1) by a scaling
factor `scaleview`, in a manner centered on `pos`.
"""
function zoom(zr::ZoomRegion, s, pos::XY)
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
                              filter_x::Function = evt->(evt.modifiers & 0x0f) == SHIFT || evt.direction == LEFT || evt.direction == RIGHT,
                              filter_y::Function = evt->(evt.modifiers & 0x0f) == 0 && (evt.direction == UP || evt.direction == DOWN),
                              xpanflip = false,
                              ypanflip  = false)
    enabled = Signal(true)
    dummyscroll = MouseScroll{U}()
    pan = map(filterwhen(enabled, dummyscroll, canvas.mouse.scroll)) do event
        s = 0.1*scrollpm(event.direction)
        if filter_x(event)
            # println("pan_x: ", event)
            push!(zr, pan_x(value(zr), s))
        elseif filter_y(event)
            # println("pan_y: ", event)
            push!(zr, pan_y(value(zr), s))
        end
        nothing
    end
    Dict("enabled"=>enabled, "pan"=>pan)
end

"""
    signals = init_pan_drag(canvas::GtkReactive.Canvas,
                            zr::Signal{ZoomRegion},
                            initiate = btn->(btn.button == 1 && btn.clicktype == BUTTON_PRESS && btn.modifiers == 0))

Initialize click-drag panning that updates `zr`. `signals` is a
dictionary holding the Reactive.jl signals needed for pan-drag; you
can push `true/false` to `signals["enabled"]` to turn it on and off,
respectively. Your application is responsible for making sure that
`signals` does not get garbage-collected (which would turn off
pan-dragging).

`initiate(btn)` returns `true` when the condition for starting
click-drag panning has been met (by default, clicking mouse button
1). The argument `btn` is a [`MouseButton`](@ref) event.
"""
function init_pan_drag{U,T}(canvas::Canvas{U},
                            zr::Signal{ZoomRegion{T}},
                            initiate::Function = pandrag_init_default)
    enabled = Signal(true)
    active = Signal(false)
    dummybtn = MouseButton{U}()
    local pos1, zr1, mtrx
    init = map(filterwhen(enabled, dummybtn, canvas.mouse.buttonpress)) do btn
        if initiate(btn)
            push!(active, true)
            # Because the user coordinates will change during panning,
            # convert to absolute position
            pos1 = XY(convertunits(DeviceUnit, canvas, btn.position.x, btn.position.y)...)
            zr1 = value(zr).currentview
            m = Cairo.get_matrix(getgc(canvas))
            mtrx = inv([m.xx m.xy 0; m.yx m.yy 0; m.x0 m.y0 1])
        end
        nothing
    end
    drag = map(filterwhen(active, dummybtn, canvas.mouse.motion)) do btn
        btn.button == 0 && return nothing
        xd, yd = convertunits(DeviceUnit, canvas, btn.position.x, btn.position.y)
        dx, dy, _ = mtrx*[xd-pos1.x, yd-pos1.y, 1]
        fv = value(zr).fullview
        cv = XY(interior(minimum(zr1.x)-dx..maximum(zr1.x)-dx, fv.x),
                interior(minimum(zr1.y)-dy..maximum(zr1.y)-dy, fv.y))
        if cv != value(zr).currentview
            push!(zr, ZoomRegion(fv, cv))
        end
    end
    finish = map(filterwhen(active, dummybtn, canvas.mouse.buttonrelease)) do btn
        btn.button == 0 && return nothing
        push!(active, false)
    end
    Dict("enabled"=>enabled, "active"=>active, "init"=>init, "drag"=>drag, "finish"=>finish)
end
pandrag_button(btn) = btn.button == 1 && (btn.modifiers & 0x0f) == 0
pandrag_init_default(btn) = btn.clicktype == BUTTON_PRESS && pandrag_button(btn)

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
                               filter::Function = evt->(evt.modifiers & 0x0f) == CONTROL,
                               focus::Symbol = :pointer,
                               factor = 2.0,
                               flip = false)
    focus == :pointer || focus == :center || error("focus must be :pointer or :center")
    enabled = Signal(true)
    dummyscroll = MouseScroll{U}()
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
    pos = XY{U}(handler.widget, evt)
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
