__precompile__(true)

module GtkReactive

using Compat

using Gtk, Colors, FixedPointNumbers, Reexport
@reexport using Reactive
using Graphics
using Graphics: set_coords, BoundingBox
using IntervalSets, RoundingIntegers
# There's a conflict for width, so we have to scope those calls
import Cairo

using Gtk: GtkWidget
# Constants for event analysis
using Gtk.GConstants.GdkModifierType: SHIFT, CONTROL, MOD1
using Gtk.GConstants.GdkScrollDirection: UP, DOWN, LEFT, RIGHT
using Gtk.GdkEventType: BUTTON_PRESS, DOUBLE_BUTTON_PRESS, BUTTON_RELEASE

# Re-exports
export set_coords, BoundingBox, SHIFT, CONTROL, MOD1, UP, DOWN, LEFT, RIGHT,
       BUTTON_PRESS, DOUBLE_BUTTON_PRESS, destroy

## Exports
export slider, button, checkbox, togglebutton, dropdown, textbox, textarea
export label
export canvas, DeviceUnit, UserUnit, XY, MouseButton, MouseScroll
export player
export signal, widget, frame
# Zoom/pan
export ZoomRegion, zoom, pan_x, pan_y, init_zoom_rubberband, init_zoom_scroll,
       init_pan_scroll, init_pan_drag

# The generic Widget interface
@compat abstract type Widget end

# A widget that gives out a signal of type T
@compat abstract type InputWidget{T}  <: Widget end

"""
    signal(w) -> s

Return the Reactive.jl Signal `s` associated with widget `w`.
"""
signal(w::Widget) = w.signal
signal(x::Signal) = x

"""
    widget(w) -> gtkw::GtkWidget

Return the GtkWidget `gtkw` associated with widget `w`.
"""
widget(w::Widget) = w.widget

Base.push!(w::Widget, val) = push!(signal(w), val)

Base.show(io::IO, w::Widget) = print(io, typeof(widget(w)), " with ", signal(w))
Gtk.destroy(w::Widget) = destroy(widget(w))
Reactive.value(w::Widget) = value(signal(w))
Base.map(f, w::Widget) = map(f, signal(w))

# Define specific widgets
include("widgets.jl")
include("extrawidgets.jl")
include("graphics_interaction.jl")
include("rubberband.jl")

## More convenience functions
# Containers
(::Type{GtkWindow})(w::Union{Widget,Canvas}) = GtkWindow(widget(w))
(::Type{GtkFrame})(w::Union{Widget,Canvas}) = GtkFrame(widget(w))
(::Type{GtkAspectFrame})(w::Union{Widget,Canvas}) = GtkAspectFrame(widget(w))

Base.push!(container::Union{Gtk.GtkBin,GtkBox}, child::Widget) =
    push!(container, widget(child))
Base.push!(container::Union{Gtk.GtkBin,GtkBox}, child::Canvas) =
    push!(container, widget(child))

widget(c::Canvas) = c.widget

Gtk.setproperty!(w::Union{Widget,Canvas}, key, val) = setproperty!(widget(w), key, val)
Gtk.getproperty(w::Union{Widget,Canvas}, key) = getproperty(widget(w), key)
Gtk.getproperty{T}(w::Union{Widget,Canvas}, key, ::Type{T}) = getproperty(widget(w), key, T)

Graphics.getgc(c::Canvas) = getgc(c.widget)
Graphics.width(c::Canvas) = Graphics.width(c.widget)
Graphics.height(c::Canvas) = height(c.widget)

Graphics.set_coords(c::Union{GtkCanvas,Canvas}, device::BoundingBox, user::BoundingBox) =
    set_coords(getgc(c), device, user)
Graphics.set_coords(c::Union{GraphicsContext,GtkCanvas,Canvas}, user::BoundingBox) =
    set_coords(c, BoundingBox(0, Graphics.width(c), 0, Graphics.height(c)), user)
function Graphics.set_coords(c::Union{GraphicsContext,Canvas,GtkCanvas}, zr::ZoomRegion)
    xy = zr.currentview
    bb = BoundingBox(xy)
    set_coords(c, bb)
end
function Graphics.set_coords(c::Union{Canvas,GtkCanvas}, inds::Tuple{AbstractUnitRange,AbstractUnitRange})
    y, x = inds
    bb = BoundingBox(first(x), last(x), first(y), last(y))
    set_coords(c, bb)
end
function Graphics.BoundingBox(xy::XY)
    BoundingBox(minimum(xy.x), maximum(xy.x), minimum(xy.y), maximum(xy.y))
end

function Base.push!{T}(zr::Signal{ZoomRegion{T}}, cv::XY{ClosedInterval{T}})
    fv = value(zr).fullview
    push!(zr, ZoomRegion(fv, cv))
end

function Base.push!{T}(zr::Signal{ZoomRegion{T}}, inds::Tuple{ClosedInterval,ClosedInterval})
    push!(zr, XY{ClosedInterval{T}}(inds[2], inds[1]))
end

function Base.push!{T}(zr::Signal{ZoomRegion{T}}, inds::Tuple{AbstractUnitRange,AbstractUnitRange})
    push!(zr, map(ClosedInterval{T}, inds))
end

Gtk.reveal(c::Canvas, args...) = reveal(c.widget, args...)

const _ref_dict = ObjectIdDict()

"""
    gc_preserve(widget::GtkWidget, obj)

Preserve `obj` until `widget` has been [`destroy`](@ref)ed.
"""
function gc_preserve(widget::Union{GtkWidget,GtkCanvas}, obj)
    _ref_dict[obj] = true
    signal_connect(widget, :destroy) do w
        delete!(_ref_dict, obj)
    end
end

end # module
