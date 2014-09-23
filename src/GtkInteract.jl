module GtkInteract


## Bring in some of the easy features of Interact to work with Gtk and Winston

## TODO:
## * work on sizing, layout
## * once INteract works out layout containers, include these



## we use gtk -- not Tk for Winston. This is specified *before* loading Winston
ENV["WINSTON_OUTPUT"] = :gtk
using Gtk, Winston
using Reactive
using DataStructures


## selectively import pieces of Interact
import Interact: Button, button, ToggleButton, togglebutton
import Interact: Slider, slider
import Interact: Options, dropdown, radiobuttons, togglebuttons, select
import Interact: Checkbox, checkbox
import Interact: Textbox, textbox
import Interact: Widget, InputWidget
import Interact: make_widget, display_widgets, @manipulate
import Interact: widget


## exports (most widgets of interact and @manipulate macro)
export slider, button, checkbox, togglebutton, dropdown, radiobuttons, select, togglebuttons, textbox, buttongroup
export cairographic, textarea, label
export mainwindow
export @manipulate

## Add an non-exclusive set of buttons
## Code basically is Options code
## XXX This is a poor name, but it isn't exported XXX
type VectorOptions{view,T} <: InputWidget{T}
    signal
    label::String
    values                       
    options::OrderedDict{String, T}
end

function VectorOptions{T}(view::Symbol, options::OrderedDict{String, T};
                          label = "",
                          value=T[],           
                          signal=Input(value))
    VectorOptions{view, T}(signal, label, value, options)
end

function VectorOptions{T}(view::Symbol, options::AbstractArray{T};
                    kwargs...)
    opts = OrderedDict{String, T}()
    map(v -> opts[string(v)] = v, options)
    VectorOptions(view, opts; kwargs...)
end

function VectorOptions{K, V}(view::Symbol, options::Associative{K, V};
                    kwargs...)
    opts = OrderedDict{String, V}()
    map(v->opts[string(v[1])] = v[2], options)
    VectorOptions(view, opts; kwargs...)
end


buttongroup(opts; kwargs...) = VectorOptions(:ButtonGroup, opts; kwargs...)

### Output widgets
##
## Basically just a few. Here we "trick" the macro that creates a
## function that map (vars...) -> expr created by @manipulate. The var
## for output widgets pass in the output widget itself, so that values
## can be `push!`ed onto them within the expression. This requires two
## things: 
## * `widget.obj=obj` (for positioning) and
## * `widget.signal=Input(widget)` for `push!`ing.

Reactive.signal(x::Widget) = x.signal

## CairoGraphic. 
##
## for a plot window
##
## add plot via `push!(cg, plot_call)`
type CairoGraphic <: Widget
    width::Int
    height::Int
    signal
    value
    obj
end

cairographic(;width::Int=480, height::Int=400) = CairoGraphic(width, height, Input{Any}(nothing), nothing, nothing)


## Textarea for output
## 
## Add text via `push!(obj, values)`
type Textarea{T <: String} <: Widget
    width::Int
    height::Int
    signal
    value::T
    buffer
    obj
end

function textarea(;width::Int=480, height::Int=400, value::String="")
    Textarea(width, height, Input(Any), value, nothing, nothing)
end

textarea(value; kwargs...) = textarea(value=value, kwargs...)


## label. Like text area, but is clearly not editable and allows for PANGO markup.
type Label <: Widget
    signal
    value::String
    obj
end

label(;value="") = Label(Input{Any}, string(value), nothing)
label(lab; kwargs...) = label(value=lab, kwargs...)

### Container(s)

## MainWindow
type MainWindow
    width::Int
    height::Int
    title
    window
    obj
    nrows::Int
end

function mainwindow(;width::Int=600, height::Int=480, title::String="") 
    w = MainWindow(width, height, title, nothing, nothing, 1)
    init_window(w)
end


## Modifications to Manipulate

## We add these output widgets to `widget`
function widget(x::Symbol, args...)
    fns = [:plot=>cairographic,
           :text=>textarea,
           :label=>label
           ]
    fns[x]()
end



## This needs changing from Interact, as we need a parent container and a different
## means to append child widgets.
## Question: the warning message is annoying, can it be fixed?
function display_widgets(widgetvars)
    w = mainwindow(title="@manipulate")
    map(v -> Expr(:call, esc(:push!), w, esc(v)),
        widgetvars)
end



## Gtk specific things
include("Gtk/gtkwidget.jl")




end # module
