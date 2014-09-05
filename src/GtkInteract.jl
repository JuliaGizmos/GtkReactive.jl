module GtkInteract


## Bring in some of the easy features of Interact to work with Gtk and Winston

## TODO:
## * work on sizing, layout
## * what else from Interact can come along?



## we use gtk -- not Tk for Winston. This is specified *before* loading Winston
ENV["WINSTON_OUTPUT"] = :gtk
using Gtk, Winston
using Reactive

## selectively import pieces of Interact
import Interact: Button
import Interact: Slider, slider, ToggleButton, togglebutton
import Interact: Options, dropdown, radiobuttons
import Interact: Checkbox, checkbox
import Interact: Textbox, textbox
import Interact: Widget, InputWidget
import Interact: make_widget, display_widgets, @manipulate


## exports (most widgets of interact and @manipulate macro)
export button, slider, togglebutton, dropdown, radiobuttons, checkbox, textbox
export cairographic, textarea, label
export mainwindow
export @manipulate


### InputWidgets

## button
button(; value="", label="", signal=Input(value)) =
    Button(signal, label, value)

button(label; kwargs...) =
    button(value=label; kwargs...)

function gtk_widget(widget::Button)
    obj = @GtkButton(widget.label)
    lift(x -> setproperty!(obj, :label, string(x)), widget.signal)
    signal_connect(obj, :clicked) do obj, args...
        push!(widget.signal, widget.signal.value) # call
    end
    obj
end

## checkbox
function gtk_widget(widget::Checkbox)
    obj = @GtkCheckButton()
    setproperty!(obj, :active, widget.value)
    ## widget -> signal
    signal_connect(obj, :toggled) do obj, args...
        push!(widget.signal, getproperty(obj, :active, Bool))
    end
    obj
end


## slider
function gtk_widget(widget::Slider)
    obj = @GtkScale(false, first(widget.range), last(widget.range), step(widget.range))
    Gtk.G_.size_request(obj, 200, -1)
    Gtk.G_.value(obj, widget.value)

    ## widget -> signal
    signal_connect(obj, :value_changed) do obj, args...
        val = Gtk.G_.value(obj)
        push!(widget.signal, val)
    end
    obj
end

## togglebutton
function gtk_widget(widget::ToggleButton)
    obj = @GtkToggleButton("")
    setproperty!(obj, :active, widget.value)
    ## widget -> signal
    signal_connect(obj, :toggled) do btn, args...
        push!(widget.signal, getproperty(btn, :active, Bool))
    end
    obj
end


## textbox
function gtk_widget(widget::Textbox)
    obj = @GtkEntry
    setproperty!(obj, :text, string(widget.signal.value))

    ## widget -> signal
    signal_connect(obj, :key_release_event) do obj, e, args...
        txt = getproperty(obj, :text, String)
        push!(widget.signal, txt)
    end

    obj
end

## dropdown
function gtk_widget(widget::Options{:Dropdown})
    obj = @GtkComboBoxText(false)
    for key in keys(widget.options)
        push!(obj, key)
    end
    index = findfirst(collect(keys(widget.options)), widget.value_label)
    setproperty!(obj, :active, index - 1)

    ## widget -> signal
    signal_connect(obj, :changed) do obj, args...
        index = getproperty(obj, :active, Int) + 1
        push!(widget.signal, collect(values(widget.options))[index])
    end

    obj

end

## radiobuttons
function gtk_widget(widget::Options{:RadioButtons})
    obj = @GtkBox(false)
    choices = collect(keys(widget.options))
    btns = [@GtkRadioButton(shift!(choices))]
    while length(choices) > 0
        push!(btns, @GtkRadioButton(btns[1], shift!(choices)))
    end
    map(u->push!(obj, u), btns)

    selected = findfirst(collect(values(widget.options)), widget.value)
    setproperty!(btns[selected], :active, true)

    for btn in btns
        signal_connect(btn, :toggled) do obj, args...
            if getproperty(obj, :active, Bool)
                label = getproperty(obj, :label, String)
                push!(widget.signal, widget.options[label])
            end
        end
    end
    setproperty!(obj, :visible, true)
    showall(obj)

    obj
    
end

## toggle buttons... XXX


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
Base.push!(obj::CairoGraphic, pc::Winston.PlotContainer) = Winston.display(obj.obj, pc)

function gtk_widget(widget::CairoGraphic)
    if widget.obj != nothing
        return widget
    end

    obj = @GtkCanvas(widget.width, widget.height)
    ## how to make winston draw here? Here we store canvas in obj and override push!
    ## is there a more natural way??
    widget.obj = obj
    widget.signal = Input(widget)
    widget
end

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

function gtk_widget(widget::Textarea)
    obj = @GtkTextView()
    block = @GtkScrolledWindow()
    [setproperty!(obj, x, true) for  x in [:hexpand, :vexpand]]
    push!(block, obj)
    setproperty!(obj, :editable, false)

    if widget.buffer == nothing
        widget.buffer = getproperty(obj, :buffer, GtkTextBuffer)
    else
        setproperty!(obj, :buffer, widget.buffer)
    end

    widget.obj = block
    widget.signal = Input(widget)
    widget
end

function Base.push!(obj::Textarea, value) 
    setproperty!(obj.buffer, :text, join(sprint(io->writemime(io, "text/plain", value)))) ## ?? easier way?
    nothing
end


## label. Like text area, but is clearly not editable and allows for PANGO markup.
type Label <: Widget
    signal
    value::String
    obj
end

label(;value="") = Label(Input{Any}, string(value), nothing)
label(lab; kwargs...) = label(value=lab, kwargs...)

function gtk_widget(widget::Label) 
    obj = @GtkLabel(widget.value)
    setproperty!(obj, :selectable, true)
    setproperty!(obj, :use_markup, true)

    widget.obj = obj
    widget.signal = Input(widget)
    widget
end

function Base.push!(obj::Label, value) 
    value = string(value)
    Gtk.G_.text(obj.obj, value)
    setproperty!(obj.obj, :use_markup, true)
    obj.value = value
end

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
    gtk_widget(w)
end

function gtk_widget(widget::MainWindow)
    if widget.obj != nothing
        return widget
    end

    widget.window = @GtkWindow()
    setproperty!(widget.window, :title, widget.title)
    Gtk.G_.default_size(widget.window, widget.width, widget.height)

    widget.obj = @GtkGrid()
    push!(widget.window, widget.obj)
    widget                      # return widget here...
end
  
function Base.push!(parent::MainWindow, obj::InputWidget) 
    lab, widget = obj.label, gtk_widget(obj)
    al = @GtkAlignment(1.0, 0.0, 1.0, 1.0)
    setproperty!(al, :right_padding, 2)
    push!(al, @GtkLabel(lab))
    parent.obj[1, parent.nrows] = al
    parent.obj[2, parent.nrows] = widget
    parent.nrows = parent.nrows + 1
    showall(parent.window)
end


function Base.push!(parent::MainWindow, obj::Widget) 
    widget = gtk_widget(obj)
    parent.obj[2, parent.nrows] = (:obj in names(obj)) ? obj.obj : widget
    parent.nrows = parent.nrows + 1
    showall(parent.window)
end


### Shortcuts for Manipulate. Override some from
### Interact.jl, but can't seem to get just those to be found where this is called
### so we bring them all in here.

## Make a widget out of a domain
widget(x::Signal, label="") = x
widget(x::Widget, label="") = x
widget(x::Range, label="") = slider(x, label=label)
widget(x::AbstractVector, label="") = radiobuttons(x, label=label)
widget(x::Associative, label="") = radiobuttons(x, label=label)
widget(x::Bool, label="") = checkbox(x, label=label)
widget(x::String, label="") = textbox(x, label=label)
widget{T <: Number}(x::T, label="") = textbox(typ=T, value=x, label=label)

## output widgets
function widget(x::Symbol, args...)
    fns = [:plot=>cairographic,
           :text=>textarea,
           :label=>label
           ]
    fns[x]()
end


### Manipulate code. Taken from Interact.@manipulate ###


## This needs changing from Interact, as we need a parent container and a different
## means to append child widgets.
## Question: the warning message is annoying.
function display_widgets(widgetvars)
    w = mainwindow(title="@manipulate")
    map(v -> Expr(:call, esc(:push!), w, esc(v)),
        widgetvars)
end

## Saddly, this call to `widget` won't find our additions unless we copy the code here.
## So we copy and pay the price of the warning
function make_widget(binding)
    if binding.head != :(=)
        error("@manipulate syntax error.")
    end
    sym, expr = binding.args
    Expr(:(=), esc(sym),
         Expr(:call, widget, esc(expr), string(sym)))
end


end # module
