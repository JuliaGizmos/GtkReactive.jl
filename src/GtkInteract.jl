module GtkInteract


## Bring in some of the easy features of Interact to work with Gtk and Winston

## TODO:
## * work on sizing, layout
## * once `Interact` works out layout containers, include these



using Gtk
using Reactive
using DataStructures
using Requires


## selectively import pieces of `Interact`
import Interact
import Interact: Button,  button
import Interact: ToggleButton, togglebutton
import Interact: Slider, slider
import Interact: Options, dropdown, radiobuttons, togglebuttons, select
import Interact: Checkbox, checkbox
import Interact: Textbox, textbox
import Interact: Widget, InputWidget
import Interact: widget


## exports (most widgets of `Interact` and the modified `@manipulate` macro)
export slider, button, checkbox, togglebutton, dropdown, radiobuttons, select, textbox, textarea, togglebuttons
export @manipulate
export buttongroup, cairographic,  label, progress
export mainwindow

## Add a non-exclusive set of buttons
## Code is basically the Options code of Interact
type VectorOptions{view,T} <: InputWidget{T} # XXX This is a poor name, but it isn't exported XXX
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

## A `buttongroup` is like `togglebuttons` only one can select 0, 1, or more of the items.
buttongroup(opts; kwargs...) = VectorOptions(:ButtonGroup, opts; kwargs...)

### Output widgets
##
## These have values `push!`ed onto them. They do not accept user input like controls do.

## CairoGraphic. 
##
## for a plot window
##
## Replace plot via `push!(cg, winston_plot_object)`
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
## Replace text via `push!(obj, value)`
type Textarea{T <: String} <: Widget
    width::Int
    height::Int
    signal
    value::T
    buffer
    obj
end

function textarea(;width::Int=480, height::Int=400, value::String="")
    Textarea(width, height, Input(Any),  value, nothing, nothing)
end

textarea(value; kwargs...) = textarea(value=value, kwargs...)


## label. 
##
## Like text area, but is clearly not editable and allows for PANGO markup.
## Replace text via `push!(obj, value)`
type Label <: Widget
    signal
    value::String
    obj
end

label(;value="") = Label(Input{Any}, string(value), nothing)
label(lab; kwargs...) = label(value=lab, kwargs...)

## Progress creates a progress bar
##
## `push!` values onto it where `value` is within `[first(range), last(range)]`
type Progress <: Widget
    signal
    value
    range::Range
    obj
end

progress(args...) = Progress(args...)
function progress(;label="", value=0, range=0:100)
    Progress(nothing, value, range, nothing)
end

Reactive.signal(x::Widget) = x.signal

## We add these output widgets to `widget`
function widget(x::Symbol, args...)
    fns = [:plot=>cairographic,
           :text=>textarea,
           :label=>label,
           :progress=>progress
           ]
    fns[x]()
end

### Container(s)

## MainWindow
##
## A top-level window
type MainWindow
    width::Int
    height::Int
    title::String
    window
    label
    cg
    obj
    nrows::Int
end

function mainwindow(;width::Int=300, height::Int=200, title::String="") 
    w = MainWindow(width, height, title, nothing, nothing, nothing, nothing, 1)
    init_window(w)
end



## Modifications for @manipulate

## Main changes come from needing to pass through a parent container in order to "display" objects
## in "display_widgets" we just use `push!` though we could define `display` methods but passing in the 
## parent container makes that awkward.
function display_widgets(win, widgetvars)
    map(v -> Expr(:call, esc(:push!), win, esc(v)), widgetvars)
end

## In `@manipulate` the macro builds up an expression, a. The `display` method is used to access the runtime
## value. Here we add a special type to couple the expression with a parent container, the main window.

type ManipulateWidget
    a
    w
end

macro manipulate(expr)
    if expr.head != :for
        error("@manipulate syntax is @manipulate for ",
              " [<variable>=<domain>,]... <expression> end")
    end
    block = expr.args[2]
    if expr.args[1].head == :block
        bindings = expr.args[1].args
    else
        bindings = [expr.args[1]]
    end
    syms = Interact.symbols(bindings)


    ## Modifications
    w = mainwindow(title="@manipulate")
    a = Expr(:let, Expr(:block,
                        display_widgets(w, syms)...,
                        esc(Interact.lift_block(block, syms))),
             map(Interact.make_widget, bindings)...)

    b = Expr(:call, :ManipulateWidget, a, w)
    b

end


## load Gtk specific things
include("Gtk/gtkwidget.jl")




end # module
