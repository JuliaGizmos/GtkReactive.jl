module GtkInteract


## Bring in some of the easy features of Interact to work with Gtk and Winston

## TODO:
## * work on sizing
## * tidy up code
## * examples
## * copy other pieces of interact


## we use gtk -- not Tk. This is before loading Winston
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

## exports (most widgets of interact and @manipulate macro)
export button, slider, togglebutton, dropdown, radiobuttons, checkbox, textbox
export cairographic, textarea
export mainwindow
export @manipulate


### InputWidgets

## label
type Label{T} <: InputWidget{T}
    signal::Input{T}
    value::T
end

label(;value=nothing,  signal=Input(value)) = label(signal, value)
label(lab; kwargs...) = label(value=lab, kwargs...)

function gtk_widget(widget::Label) 
    obj = @GtkLabel(widget.value)
    lift(x -> Gtk.G_.text(obj, x), widget.signal)
    obj
end

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
Base.push!(obj::GtkCanvas, pc::FramedPlot) = Winston.display(obj, pc)
Reactive.signal(x::CairoGraphic) = x.signal

function gtk_widget(widget::CairoGraphic)
    if widget.obj != nothing
        return widget
    end

    obj = @GtkCanvas(widget.width, widget.height)
    ## how to make winston draw here? Here we store canvas in obj and override push!
    ## is there a more natural way??
    widget.obj = obj
    widget.signal = Input(obj)
    widget
end

## Textarea for output
## 
## Add text via `push!(ta, values)`
type Textarea{T <: String} <: Widget
    width::Int
    height::Int
    signal
    value::T
    buffer
    obj
end

textarea(;width::Int=480, height::Int=400, value::String="") = Textarea(width, height, Input(Any), value, nothing, nothing)
textarea(value; kwargs...) = textarea(value=value, kwargs...)
Reactive.signal(x::Textarea) = x.signal

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
    widget.signal = Input(obj)
    widget
end

function Base.push!(obj::Textarea, value) 
    setproperty!(obj.buffer, :text, join(sprint(io->writemime(io, "text/plain", value))))
end
function Base.push!(obj::GtkTextViewLeaf, value) 
    buffer = getproperty(obj, :buffer, GtkTextBuffer)
    setproperty!(buffer, :text, join(sprint(io->writemime(io, "text/plain", value))))
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

mainwindow(;width::Int=600, height::Int=480, title::String="") = gtk_widget(MainWindow(width, height, title, nothing, nothing, 1))

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


### SHortcuts for Manipulate
# Make a widget out of a domain
widget(x::Signal, label="") = x
widget(x::Widget, label="") = x
widget(x::Range, label="") = slider(x, label=label)
widget(x::AbstractVector, label="") = radiobuttons(x, label=label)
widget(x::Associative, label="") = radiobuttons(x, label=label)
widget(x::Bool, label="") = checkbox(x, label=label)
widget(x::String, label="") = textbox(x, label=label)
widget{T <: Number}(x::T, label="") = textbox(typ=T, value=x, label=label)
function widget(x::Symbol, label="")
    if x == :plot
        cairographic()
    elseif x==:text
        textarea()
    end
end


### Manipulate code. Taken from Interact.@manipulate
function make_widget(binding)
    if binding.head != :(=)
        error("@manipulate syntax error.")
    end
    sym, expr = binding.args
    Expr(:(=), esc(sym),
         Expr(:call, widget, esc(expr), string(sym)))
end

function display_widgets(widgetvars)
    ww = mainwindow(title="@manipulate")
    map(v -> Expr(:call, esc(:push!), ww, esc(v)),
        widgetvars)
end

function lift_block(block, symbols)
    lambda = Expr(:(->), Expr(:tuple, symbols...),
                  block)
    out = Expr(:call, Reactive.lift, lambda, symbols...)
    out
end

function symbols(bindings)
    map(x->x.args[1], bindings)
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
    syms = symbols(bindings)
    Expr(:let, Expr(:block,
                    display_widgets(syms)...,
                    esc(lift_block(block, syms))),
         map(make_widget, bindings)...)
end



end # module
