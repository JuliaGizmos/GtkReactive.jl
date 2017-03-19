__precompile__(true)

module GtkReactive

using Compat

using Gtk, Colors, Reexport
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
export canvas, DeviceUnit, UserUnit
export player
export signal, frame
# Zoom/pan
export ZoomRegion, zoom, pan_x, pan_y, init_zoom_rubberband, init_zoom_scroll,
       init_pan_scroll, init_pan_drag

# The generic Widget interface
@compat abstract type Widget end

# A widget that gives out a signal of type T
@compat abstract type InputWidget{T}  <: Widget end

signal(w::Widget) = w.signal
signal(x::Signal) = x

Base.show(io::IO, w::Widget) = print(io, typeof(w.widget), " with ", signal(w))
Gtk.destroy(w::Widget) = destroy(w.widget)
Base.push!(container::Gtk.GtkContainer, child::Widget) = push!(container, child.widget)
Reactive.value(w::Widget) = value(signal(w))
Base.map(f, w::Widget) = map(f, signal(w))

# Define specific widgets
include("widgets.jl")
include("extrawidgets.jl")
include("graphics_interaction.jl")
include("rubberband.jl")

# More convenience functions
(::Type{GtkWindow})(c::Canvas) = GtkWindow(c.widget)
(::Type{GtkFrame})(c::Canvas) = GtkFrame(c.widget)
(::Type{GtkAspectFrame})(c::Canvas) = GtkAspectFrame(c.widget)

Graphics.getgc(c::Canvas) = getgc(c.widget)
Graphics.width(c::Canvas) = Graphics.width(c.widget)
Graphics.height(c::Canvas) = height(c.widget)

Graphics.set_coords(c::Union{GtkCanvas,Canvas}, device::BoundingBox, user::BoundingBox) =
    set_coords(getgc(c), device, user)
Graphics.set_coords(c::Union{GtkCanvas,Canvas}, user::BoundingBox) =
    set_coords(c, BoundingBox(0, Graphics.width(c), 0, Graphics.height(c)), user)
function Graphics.set_coords(c::Union{Canvas,GtkCanvas}, zr::ZoomRegion)
    xy = zr.currentview
    bb = BoundingBox(minimum(xy.x), maximum(xy.x), minimum(xy.y), maximum(xy.y))
    set_coords(c, bb)
end
function Graphics.set_coords(c::Union{Canvas,GtkCanvas}, inds::Tuple{AbstractUnitRange,AbstractUnitRange})
    y, x = inds
    bb = BoundingBox(first(x), last(x), first(y), last(y))
    set_coords(c, bb)
end

Gtk.reveal(c::Canvas, args...) = reveal(c.widget, args...)

# Prevent garbage collection until the on-screen widget has been destroyed
const _ref_dict = ObjectIdDict()
function gc_preserve(widget::Union{GtkWidget,GtkCanvas}, obj)
    _ref_dict[obj] = true
    signal_connect(widget, :destroy) do w
        delete!(_ref_dict, obj)
    end
end

end # module
