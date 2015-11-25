
module GtkInteract

## TODO:
## * more layout options. (Did formlayout)
## * [DONE] menubars, toolbars
## * GtkMenuButton and toolbar (one isn't there, other isn't working...)
## * [DOne] use formlayout in MainWindow

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
import Interact: widget, signal
import Reactive: foreach, sampleon, value
import Gtk: destroy

## exports (most widgets of `Interact` and the modified `@manipulate` macro)
export slider, button, checkbox, togglebutton, dropdown, radiobuttons, selectlist, textbox, textarea, togglebuttons
export @manipulate
export buttongroup, cairographic,  label, progress
export icon, tooltip, separator
export mainwindow
export foreach, value
export destroy

## Add a non-exclusive set of buttons
## Code is basically the Options code of Interact
type VectorOptions{view,T} <: InputWidget{T} # XXX This is a poor name, but it isn't exported XXX
    signal
    label::AbstractString
    values                       
    options::OrderedDict{AbstractString, T}
end

function VectorOptions{T}(view::Symbol, options::OrderedDict{AbstractString, T};
                          label = "",
                          value=T[],           
                          signal=Signal(value))
    VectorOptions{view, T}(signal, label, value, options)
end

function VectorOptions{T}(view::Symbol, options::AbstractArray{T};
                    kwargs...)
    opts = OrderedDict{AbstractString, T}()
    map(v -> opts[string(v)] = v, options)
    VectorOptions(view, opts; kwargs...)
end

function VectorOptions{K, V}(view::Symbol, options::Associative{K, V};
                             kwargs...)
    opts = OrderedDict{AbstractString, V}()
    map(v->opts[string(v[1])] = v[2], options)
    VectorOptions(view, opts; kwargs...)
end


"""

A `buttongroup` is like `togglebuttons` only one can select 0, 1, or more of the items. (Non-exclusive selection.)

"""
buttongroup(opts; kwargs...) = VectorOptions(:ButtonGroup, opts; kwargs...)





## Output widgets


"""

Output widgets are different from input widgets, in that they do not have signals propogate when they
are changed. Rather, they are for display.

Values are `push!`ed onto the widget to update the display.
"""
abstract OutputWidget <: Widget

Interact.signal(w::OutputWidget) = w.signal
"""
CairoGraphic. 

for a plot window

Replace plot via `push!(cg, winston_plot_object)`
"""
type CairoGraphic <: OutputWidget
    width::Int
    height::Int
    signal
    value
    obj
end

cairographic(;width::Int=480, height::Int=400) = CairoGraphic(width, height,nothing, nothing, nothing)


type ImmerseFigure <: OutputWidget
    width::Int
    height::Int
    signal
    value
    obj
    toolbar
    cnv
end

"""

Add area for an `Immerse` graphic

"""
immersefigure(;width::Int=480, height::Int=400) = ImmerseFigure(width, height, nothing, nothing, nothing,nothing, nothing)

"""
Textarea for output
 
Replace text via `push!(obj, value)`
"""
type Textarea{T <: AbstractString} <: OutputWidget
    width::Int
    height::Int
    signal
    value::T
    buffer
    obj
end

function textarea(;width::Int=480, height::Int=400, value::AbstractString="")
    Textarea(width, height, Signal(Any),  value, nothing, nothing)
end

textarea(value; kwargs...) = textarea(value=value, kwargs...)


type Label <: OutputWidget
    signal
    value::AbstractString
    obj
end
"""
label. 

Like text area, but is clearly not editable and allows for PANGO markup.
Replace text via `push!(obj, value)`
"""
label(;value="") = Label(Signal{Any}, string(value), nothing)
label(lab; kwargs...) = label(value=lab, kwargs...)

type Image <: OutputWidget
    signal
    value::AbstractString
    obj
end

"""

Show an image from a file

"""
image(;value="") = Image(Signal{Any}, string(value), nothing)
image(fname; kwargs...) = image(value=fname, kwargs...)

type Progress <: OutputWidget
    signal
    value
    range::Range
    obj
end

## Progress creates a progress bar
##
## `push!` values onto it where `value` is within `[first(range), last(range)]`
progress(args...) = Progress(args...)
function progress(;label="", value=0, range=0:100)
    Progress(nothing, value, range, nothing)
end

## Decorative widgets
abstract DecorativeWidget <: Widget

## An icon
type Icon <: DecorativeWidget
    stock_id
    tile
    obj
end


"""

Add a static icon to a display or
add an icon to a GUI element, such as a button.

```
icon("window-close", nothing) # creates an image to be added to a GUI
icon("window-close", btn) # adds icon to button
button("button") |> icon("window-close")  # Curried form
```

Idea is `icon(id, button("text"))` will decorate button

A list of [icons](https://docs.google.com/spreadsheets/d/1HavJQRPpMuq-N0GoN1wJR-9KEGXpKy3-NEPpZZkUGJY/pub?output=html).
"""
icon(id::AbstractString, tile) = Icon(id, tile, nothing)
icon(id::AbstractString) = tile -> Icon(id, tile, nothing)

## tooltip
immutable Tooltip <: DecorativeWidget
    text
    tile
end
"""

Add a tooltip to a widget

```
tooltip("message", widget)
widget |> tooltip("message")
```
"""
tooltip(msg::AbstractString, tile::Widget) = Tooltip(msg, tile)
tooltip(msg::AbstractString) = tile -> tooltip(msg, tile)

## Separator
immutable Separator <: DecorativeWidget
    orient
end
"""

A simple separator between text. [Currently implemented in an old school way...]

"""
separator(orient::Symbol=:horizontal) = Separator(orient)
##################################################
### Container(s) and Layout
##
## We have some exports here to trim down. These kinda follow the layout of Escher
## but Gtk is not as rich as HTML
##
## Our main containers are: window, vbox, hbox, tabs
##
## our attributes work on children and are pad, align, grow, width, height

export size,
       width, #minwidth, maxwidth,
       height, #minheight, maxheight,
       vskip, hskip,
       grow, shrink, flex,
       align, halign, valign,
       padding,
       vbox, hbox,
       tabs,
       formlayout,
       toolbar,
       menu, 
       window,
       messagebox, confirmbox, inputbox,
       openfile, savefile, selectdir

## We follow Escher layout here
immutable Length{unit}
    value::Float64
end



abstract Layout <: Widget
abstract LayoutAttribute <: Layout

immutable Size <: LayoutAttribute
    tile
    w_prefix
    h_prefix
    w_px::Length
    h_px::Length
end

Base.size(w::Int, h::Int, lyt) = Size(lyt, "", "", Length{:px}(w), Length{:px}(h))
Base.size(w::Int, h::Int) = lyt -> size(w, h, lyt)

"Width of widget"
function width(prefix::AbstractString, px::Int, lyt::Layout)
    Size(lyt, prefix, "", Length{:px}(px), Length{:px}(-1))
end
width(prefix::AbstractString, px::Int) = lyt -> width(prefix, px, lyt)
width(px::Int, w) = width("", px, w)
width(px::Int) = w -> width(px, w)
#minwidth(w, x...) = width("min", w, x...)
#maxwidth(w, x...) = width("max", w, x...)

"Height of widget"
function height(prefix::AbstractString, px::Int, lyt::Layout)
    Size(lyt, "", prefix, Length{:px}(-1), Length{:px}(px))
end
height(prefix::AbstractString, px::Int) = lyt -> height(prefix, px, lyt)
height(px::Int, w) = height("", px, w)
height(px::Int) = w -> height(px, w)
#minheight(w, x...) = height("min", w, x...)
#maxheight(w, x...) = height("max", w, x...)


vksip(y) = size(0, y, empty)
hskip(y) = size(y, 0, empty)

## flex
immutable Grow <: LayoutAttribute
    tile
    factor
    direction
end

## factor in [0,1]
"""

Have widget expand if space is available

* `grow(widget)` expand
* `grow(factor, widget)` use factor to determine growth. Only 0 and 1 are used

Use a direction to constrain growth to one direction:

* `grow(:horizontal, widget)` (also `:vertical`)

"""
grow(factor::Real, tile) = Grow(tile, factor, [:horizontal,:vertical])
grow(factor::Real) = tile -> grow(factor, tile)
grow(tile) = grow(1.0, tile)
grow(direction::Vector{Symbol}, factor::Real, tile) = Grow(tile, factor, direction)
grow(direction::Symbol, factor::Real, tile) = grow([direction;], factor, tile)
grow(direction::Symbol, tile) = grow([direction;], 1, tile)

immutable Shrink <: LayoutAttribute
    tile
    factor
end
## factor in [0,1]
shrink(factor::Real, tile) = Shrink(tile, factor)
shrink(factor::Real) = tile -> shrink(factor, tile)
shrink(tile) = shrink(1.0, tile)

immutable Flex <: LayoutAttribute
    tile
    factor
end
## factor in [0,1]
flex(factor::Real, tile) = Flex(tile, factor)
flex(factor::Real) = tile -> flex(factor, tile)
flex(tile) = flex(1.0, tile)


## alignment
Alignments =Dict(:fill      => Gtk.GConstants.GtkAlign.FILL,
                 :axisstart => Gtk.GConstants.GtkAlign.START,
                 :start     => Gtk.GConstants.GtkAlign.START,
                 :axisend   => Gtk.GConstants.GtkAlign.END,
                 :end       => Gtk.GConstants.GtkAlign.END,
                 :center    => Gtk.GConstants.GtkAlign.CENTER,
                 :baseline  => Gtk.GConstants.GtkAlign.BASELINE)

immutable Align <: LayoutAttribute
    tile
    halign
    valign
end


"""

Align child if more space is needed than requested.

* `align(h,v,lyt)` where `h` and `v` are in `[:fill, :axisstart, :start, :axisend, :end, :center,:baseline]`

"""
align(h::Symbol, v::Symbol, lyt) = Align(lyt, Alignments[h], Alignments[v])
align(h::Symbol, v::Symbol) = lyt -> align(h, v, lyt)

"""
Align horizonatally. See `align`.
"""
halign(a::Symbol, lyt) = align(a, :fill, lyt)
halign(a::Symbol) = lyt -> halign(a, lyt)

"""
Align vertically. See `align`.
"""
valign(a::Symbol, lyt) = align(:fill, a, lyt)
valign(a::Symbol) = lyt -> valign(a, lyt)


## padding
immutable Pad <: LayoutAttribute
    tile
    sides
    len::Length
end
## what to put for sides?
padcontent(len, tile, sides=[:left, :right, :top, :bottom]) = Pad(tile, sides, Length{:px}(len))

"""

Add padding to a widget.


* `padding(n, widget)` add n pixels of space around each side
* `padding([:left, :right, :top, :bottom], n, widget)` specify which sides with a vector.

"""
padding(len::Int, widget) = padcontent(len, widget)
padding(len::Int) = widget -> padding(len, widget)
padding(sides::AbstractVector, len, tile) =
    padcontent(sides, len, Container(tile))


##################################################
## Boxes
type FlowContainer <: Layout
    obj
    direction
    children
end

"""

vertical box for packing in children

```
vbox(child1, child2, ...)
```

Use attributes before packing to get spacing:

```
vbox(grow(child1), padding(10, child2))
```

"""
vbox(children...) = FlowContainer(nothing, "vertical", [children...])

"""

Horizontal box container. See `vbox`.

"""
hbox(children...) = FlowContainer(nothing, "horizontal", [children...])

"""

An empty container for spacing purposes

"""
const empty = vbox()


## Tabs...
immutable Tabs <: Layout
    children
    labels
    initial::Int
end

"""

Use a notebook to organize pages

The tab labels are specified at construction time using "pairs:"


*  `tabs("label"=>tile, "label1"=>tile, ...; selected=1)`

"""
function tabs(tiles...; selected::Int=1)
    labels = [label for (label, child) in tiles]
    children = [child for (label, child) in tiles]
    Tabs(children, labels, selected)
end

immutable FormLayout <: Layout
    children
end

"""

Form layout container. There are two columns. The children are
arranged in the second. Their `label` property runs down the first.

Example:
```
sl = slider(1:10, label="slider")
rb = radiobuttons(["one", "two", "three"], label="radio buttons")
btn = button("click me")
fl = formlayout(sl, rb, separator(), btn)
fl |> padding(5) |> window(title="formlayout example")
```
"""
formlayout(children...) = FormLayout(children)
formlayout() = FormLayout(Any[])
Base.push!(lyt::FormLayout, child) = push!(lyt.children, child)
Base.append!(lyt::FormLayout, children) = append!(lyt.children, children)


##################################################
## Toolbar
immutable Toolbar <: Layout
    children
end

"""

Toolbar container. Holds buttons, togglebuttons, separators

"""
function toolbar(children...)
    Toolbar(children)
end

## Menubar
immutable Menu <: Layout
    label
    children
end


"""

A menu bar. Children are items (buttons, separators, or other menu items)

Example:
```
btn1 = button("one")
btn2 = button("two")

mb =menu(menu(btn1, separator(), btn2,
menu(btn1, btn2, label="submenu"),   
label="File"),                       
menu(btn1, btn2, label="Edit"))

do_something(args...) = println("hi")
map(do_something, btn1)            # give some action
w = window(mb, grow(label("space")))
```


Note: toggle buttons can be supported when Gtk does.

"""
menu(children...; label="") = Menu(label, children)


## XXX This isn't working, but should be
immutable MenuButton <: Layout
    label
    children
end
"""

A menu button is used like a combobox, but we can put in menu items. It can also be in a toolbar.

"""
menubutton(children...; label::AbstractString="") = MenuButton(label, children)

type Window <: Layout
    width::Int
    height::Int
    title
    children
    obj
end
    
    """
A parentless container, like MainWindow, but less fuss.

Child widgets are packed into a `vbox`.

* `window(child1, child2, ...; title="some title")`

There is no curried form. Rather, `window(kwargs...)` creates a window
object onto which children may be pushed or appended. The window will render when
its `display` method is called.

```
w = window(title="Title");
push!(w, button("button"))
append!(w, [slider(1:10), slider(1:20)])
w
## to destroy
destroy(w)
```

"""
window(children...; width::Int=-1, height::Int=-1, title::AbstractString="") = Window(width, height, title, [children...;], nothing)
#window(;kwargs...) = tile -> window(tile; kwargs...)
Base.push!(widget::Window, child::Widget) = push!(widget.children, child)
Base.append!(widget::Window, children) = append!(widget.children, children)
Gtk.destroy(widget::Window) = destroy(widget.obj)
##
## MainWindow
##
## A top-level window
type MainWindow <: Layout
    width::Int
    height::Int
    title::AbstractString
    children
    obj
    window
    out
end

"""

Mainwindow for manipulate or easy layout of widgets with label.

The main window uses a "form" layout. That is, a two-column
format. The first column to hold labels, the second the controls. The
label comes from the label property of the control specified through
the `label=` keyword argument.

Example

```
sl = slider(1:10, label="slider")
rb = radiobuttons(["one", "two", "three"], label="radio")
w = mainwindow(title="a main window");
append!(w, [sl, rb])
w                                       # when displayed, creates window.  Call destroy(w) to close.
```

"""
function mainwindow(children...;width::Int=300, height::Int=200, title::AbstractString="")
    widget = MainWindow(width, height, title, [children...;],
                        nothing, nothing, nothing) # obj, window, label, nothing
    widget
end

Base.display(widget::MainWindow) = Gtk.showall(gtk_widget(widget))
Gtk.destroy(widget::MainWindow) = destroy(widget.obj)
##################################################
    ## dialogs
"""

Dialogs are modal so that hye block until there is a returned value


"""
abstract Dialog <: Widget

immutable MessageBox <: Dialog
    msg
    style
end

"""

A simple modal message with a dismiss button.

* `msg`: a string
* `style`: a symbol. One of `:info`, `:warn`, `:error`

```
messagebox("my message", :info)
```
"""
messagebox(msg::AbstractString, style::Symbol=:ask) = MessageBox(msg, style) |> gtk_widget

immutable ConfirmBox <: Dialog
    msg
end

"""

A simple modal message with a yes/no pair of buttons. Returns boolean.

* `msg`: a string

```
confirmbox("my message")
```
"""
confirmbox(msg::AbstractString) = ConfirmBox(msg)  |> gtk_widget

immutable InputBox <: Dialog
    msg
    default
end

"""

Modal dialog to gather user input. Returns `""` for a cancelled query.

Example:
```
inputbox("What is your name", "John Doe")
```
"""
inputbox(msg::AbstractString, default::AbstractString="")  = InputBox(msg, default)  |> gtk_widget

immutable OpenFile <: Dialog
    title
end

"""

File open dialog

Example
```
fname = openfile("Select a file")
```
"""
openfile(title::AbstractString="Select a file") = OpenFile(title)  |> gtk_widget

immutable SaveFile <: Dialog
    title
end

"""

Modal dialog to select a filename for saving a file

Example
```
fname = savefile("Select a file")
length(fname) > 0 && "save the file to fname ..."
```
"""
savefile(title::AbstractString="Save file") = SaveFile(title)  |> gtk_widget

immutable SelectDir <: Dialog
    title
end

"""

Modal dialog to select a directory.

Example
```
d = selectdir("Select a directory...")
```
"""
selectdir(title::AbstractString="Save file") = SelectDir(title)  |> gtk_widget


    



    
    
    
    
##################################################
## Typography
## If these are useful, they could easily be expanded
immutable Bold <: Layout label end
"""
Make bold text in label
"""
bold(label::AbstractString) = Bold(label)

immutable Emph <: Layout label end
"""
Make emphasized test in a label
"""
emph(label::AbstractString) = Emph(label)

immutable Code <: Layout label end
"""
Use typewriter font in text for a label
"""
code(label::AbstractString) = Code(label)


##################################################
## Manipulate


## Modifications for @manipulate

## We add these output widgets to `widget`
widget_dict = Dict{Symbol, Function}()
widget_dict[:plot]=cairographic
widget_dict[:text] =textarea
widget_dict[:label]=label
widget_dict[:progress]=progress

function widget(x::Symbol, args...)
    widget_dict[x]()
end


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
                        esc(Interact.map_block(block, syms))),
             map(Interact.make_widget, bindings)...)

    b = Expr(:call, :ManipulateWidget, a, w)
    b
end


## connnect up Reactive with GtkInteract
Base.push!(w::Interact.InputWidget, value) = push!(w.signal, value)
Base.push!(w::OutputWidget, value::Interact.Signal) = push!(w, Reactive.value(value))

"""

The `Reactive.map(function, signals...)` function takes the signals
passed to it and passes their values to the function each time a
signal is changed through the GUI. (Signals are not emitted when a
value is `push!`ed to them)

This is a convenience extending the values to input widgets, as
otherwise, their signal must be pulled out before passing to `map`
using the `Interact.signal` function.

```
sl = slider(1:10)
sl1 = slider(1:10)
append!(mainwindow(), [sl, sl1])
map(println, sl, sl1)
```

"""


Base.map(f::Function, ws::Interact.InputWidget...) = map(f, map(Interact.signal, ws)...)

"""

The `sampleon` function of `Reactive.jl` passes on the values of the signals (as a
tuple) when the button is pressed. This can be used when the effects
of changing a GUI element can take a long time to propogate. In that
case, a GUI can be come unresponsive. This allows the effects to be
called only when the button is pressed.

```
sl = slider(1:10)
sl1 = slider(1:10)
btn = button("click me")
w = mainwindow()
append!(w, [sl, sl1, btn])

map(println, sampleon(btn, sl, sl1))
```

This function is a convenience for the following composition:

`Reactive.sampleon(btn.signal, map(tuple, map(Interact.signal, ws...)))`
"""
function Reactive.sampleon(btn::Button, ws::Interact.InputWidget...)
    Reactive.sampleon(btn.signal, map(tuple, ws...))
end


"""

Find current value of a widget. Short hand for `Reactive.value(w.signal)`.

"""
value(w::Widget) = Reactive.value(w.signal)
## load Gtk specific things
include("Gtk/gtkwidget.jl")




end # module
