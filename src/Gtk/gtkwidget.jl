## Code that is Gtk specific

## Plotting code is package dependent
## Plots should dispatch to underlying code for Immerse, Winston or PyPlot


## Plots package

## show_outwidget makes a display widget for a plot

## ## For unicode plots we try a label, but doesn't work...
## function show_outwidget(w, p::Plots.Plot{Plots.UnicodePlotsPackage})
##      if w.label == nothing
##         w.label = @GtkLabel("")
##         setproperty!(w.label, :selectable, true)
##         setproperty!(w.label, :use_markup, true)
##         push!(w.window[1], w.label)
##         showall(w.window)
##     end

##     ## Fails!
##     Plots.rebuildUnicodePlot!(p)
##     out = sprint(io -> writemime(io, "text/plain", p.o))
##     setproperty!(w.label, :label, out)

## end

## In general use a canvas to display a plot in the main window
function make_canvas(w::MainWindow, x)
    if w.cg == nothing
        box = w.window[1]
        w.cg = @GtkCanvas(480, 400)
        setproperty!(w.cg, :vexpand, true)
        push!(box, w.cg)
        showall(w.window)
    end
    push!(w.cg, x)    
end
show_outwidget(w, x::Plots.Plot) = make_canvas(w, x)
    
Base.push!(obj::CairoGraphic, p::Plots.Plot) = push!(obj.obj, p)
Base.push!(c::GtkCanvas, p::Plots.Plot) = push!(c, p.o[2])


## Individual Packages


## Immerse
Requires.@require Immerse begin
    eval(Expr(:using, :Gadfly))
    eval(Expr(:using, :Compose))

    ## same as Plots.Plot, make canvas window
    show_outwidget(w::GtkInteract.MainWindow, x::Gadfly.Plot) = make_canvas(w, x)

    Base.push!(obj::CairoGraphic, p::Gadfly.Plot) = Winston.display(obj.obj, p)    
    function Base.push!(c::GtkCanvas, p::Gadfly.Plot)
        out = Immerse.render_finish(Gadfly.render_prepare(p); dynamic=false)
        c.draw = let bad=false
            function (_)
                bad && return
                # Render
                backend = Immerse.render_backend(c)
                try
                    Compose.draw(backend, out)
                catch e
                    bad = true
                    rethrow(e)
                end
            end
        end
        Gtk.draw(c)
    end

end



## Winston
## Winston is a problem if `ENV["WINSTON_OUTPUT"] = :gtk` is not set *beforehand*
Requires.@require Winston begin
    ENV["WINSTON_OUTPUT"] = :gtk    

    show_outwidget(w, x::Winston.FramedPlot) = make_canvas(w, x)
    
    Base.push!(obj::CairoGraphic, pc::Winston.PlotContainer) = Winston.display(obj.obj, pc)    
    Base.push!(c::GtkCanvas, pc::Winston.PlotContainer) = Winston.display(c, pc)
end

## Gadfly 
Requires.@require Gadfly begin
    info("Gadfly support is through Immerse")

end


Requires.@require PyPlot begin
    info("PyPlot support is very buggy!")
    
    PyPlot.pygui(false)
    
""" 
    
Overwrite `withfig` from `PyPlot` to work here. This code snippet is
found in PyPlot, save the comment. It is licensed under the MIT
license.

We use this as with `Interact`:

```
f = figure()
@manipulate for n in 1:5
    GtkInteract.withfig(f) do
        xs = linspace(0, n*pi)
        PyPlot.plot(xs, map(sin, xs))
    end
end
```
"""
function withfig(actions::Function, f::PyPlot.Figure; clear=true)
    ax_save = PyPlot.gca()
    PyPlot.figure(f[:number])
    finalizer(f, close)
    try
        if clear && !isempty(f)
            PyPlot.clf()
        end
        actions()
    catch
        rethrow()
    finally
        try
            PyPlot.sca(ax_save) # may fail if axes were overwritten
        end
        ##Main.IJulia.undisplay(f) ## IJulia display queue
    end
    return f
end
export withfig

    " How to show a pyplot figure "
    function show_outwidget(w, x::PyPlot.Figure) 
        if w.label == nothing
            w.label = @GtkImage()
            push!(w.window[1], w.label)
            showall(w.window)
        end
        
        f = tempname() * ".png"
        io = open(f, "w")
        writemime(io, "image/png", x)
        close(io)
        Gtk.G_.from_file(w.label, f)
        rm(f)
        x[:clear]()
        nothing
    end
end

##################################################
## Controls

## button
##
## button("label") is constructor
##
function gtk_widget(widget::Button)
    obj = @GtkButton(widget.label)
    widget.label = ""

    ## widget -> signal
    id = signal_connect(obj, :clicked) do obj, args...
        push!(widget.signal, widget.signal.value) # call
    end

    obj
end

## checkbox
function gtk_widget(widget::Checkbox)
    obj = @GtkCheckButton()
    setproperty!(obj, :active, widget.value)

    ## widget -> signal
    id = signal_connect(obj, :toggled) do obj, args...
        push!(widget.signal, getproperty(obj, :active, Bool))
    end

    Reactive.foreach(widget.signal) do val
        signal_handler_block(obj, id)
        setproperty!(obj, :active, val)
        signal_handler_unblock(obj, id)
    end
        

    obj
end


## slider
function gtk_widget(widget::Slider)
    obj = @GtkScale(false, first(widget.range), last(widget.range), step(widget.range))
    Gtk.G_.size_request(obj, 200, -1)
    Gtk.G_.value(obj, widget.value)

    ## This *should* work, but doesn't seem to...
    ## ## https://github.com/JuliaLang/Gtk.jl/blob/master/doc/more_signals.md
    ## function scale_cb(scaleptr::Ptr, user_data)
    ##     val = G_.value(obj)
    ##     push!(widget.signal, val)
    ##     nothing
    ## end
    ## id = signal_connect(scale_cb, obj, "value-changed", Void, (), false, nothing)

    
    ## widget -> signal
    ## this might be an issue #161
    id = signal_connect(obj, :value_changed) do obj, args...
        val = Gtk.G_.value(obj)
        push!(widget.signal, val)
    end
    
    ## 
    Reactive.foreach(widget.signal) do val
        signal_handler_block(obj, id)
        Gtk.G_.value(obj, val)
        signal_handler_unblock(obj, id)
    end
    
    obj
end

## togglebutton (single one. XXX is label on button or a label? XXX)
function gtk_widget(widget::ToggleButton)
    obj = @GtkToggleButton(string(widget.value))
    setproperty!(obj, :active, widget.value)
    
    ## widget -> signal
    id = signal_connect(obj, :toggled) do btn, args...
        value = getproperty(btn, :active, Bool)
        push!(widget.signal, value)
        setproperty!(obj, :label, string(value))
    end

    ## signal -> widget
    Reactive.foreach(widget.signal) do val
        signal_handler_block(obj, id)
        setproperty!(obj, :active, val)
        signal_handler_unblock(obj, id)
    end


    obj
end


## textbox
function gtk_widget(widget::Textbox)
    obj = @GtkEntry
    setproperty!(obj, :text, string(widget.signal.value))

    ## widget -> signal
    id = signal_connect(obj, :key_release_event) do obj, e, args...
        txt = getproperty(obj, :text, AbstractString)
        push!(widget.signal, txt)
    end

    
    ## signal -> widget
    Reactive.foreach(widget.signal) do val
        signal_handler_block(obj, id)
        setproperty!(obj, :text, string(val))
        signal_handler_unblock(obj, id)
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
    id = signal_connect(obj, :changed) do obj, args...
        index = getproperty(obj, :active, Int) + 1
        push!(widget.signal, collect(values(widget.options))[index])
    end

    ## signal -> widget
    Reactive.foreach(widget.signal) do val
        signal_handler_block(obj, id)
        index = getproperty(obj, :active, Int) + 1
        val = findfirst(collect(values(widget.options)), val)
        if val != index
            setproperty!(obj, :active, val - 1)
        end
        signal_handler_unblock(obj, id)
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

    ## widget -> signal
    ids = Dict()
    for btn in btns
        ids[btn] = signal_connect(btn, :toggled) do obj, args...
            if getproperty(obj, :active, Bool)
                label = getproperty(obj, :label, AbstractString)
                push!(widget.signal, widget.options[label])
            end
        end
    end
    setproperty!(obj, :visible, true)
    showall(obj)

    ## signal -> widget
    Reactive.foreach(widget.signal) do val
        [signal_handler_block(btn, id) for (btn,id) in ids]
        selected = findfirst(collect(values(widget.options)), val)
        setproperty!(btns[selected], :active, true)
        [signal_handler_unblock(btn, id) for (btn,id) in ids]        
    end


    obj
    
end

## toggle buttons. Exclusive like a radio button
function gtk_widget(widget::Options{:ToggleButtons})
    labs = collect(keys(widget.options))
    vals = collect(values(widget.options))

    block = @GtkBox(false)
    function make_button(lab)
        btn =  Gtk.@GtkToggleButton(lab)
        setproperty!(btn, :active, lab == widget.value_label)
        push!(block, btn)
        btn
    end
    btns = map(make_button, labs)

    ## widget -> signal
    ids = Dict()
    for btn in btns
        ids[btn] = signal_connect(btn, :button_press_event) do _,__
            val =  getproperty(btn, :active, Bool)
            if !val
                ## set button state
                for b in btns
                    setproperty!(b, :active, b==btn)
                end
                ## set widget state
                push!(widget.signal, vals[findfirst(labs, getproperty(btn, :label, AbstractString))])
            end
            true                # impt: stop evennt propogation
        end
    end

    ## signal -> widget
    Reactive.foreach(widget.signal) do val
        ## get index from val
        index = findfirst(vals, val)
        lab = labs[index]
        for btn in btns
            signal_handler_block(btn, ids[btn])
            setproperty!(btn, :active, getproperty(btn, :label, AbstractString) == lab)
            signal_handler_unblock(btn, ids[btn])
        end
    end

    
    block
end


## buttongroup -- non exclusive
function gtk_widget(widget::VectorOptions{:ButtonGroup})
    labs = collect(keys(widget.options))
    vals = collect(values(widget.options))
    
    block = @GtkBox(false)
    
    btns = Gtk.GtkToggleButton[]
    for (lab, val) in zip(labs, vals)
        btn =  Gtk.@GtkToggleButton(lab)
        setproperty!(btn, :active, val in widget.values)
        push!(block, btn)
        push!(btns, btn)
    end

    ## widget -> signal
    ids = Dict()
    for btn in btns
        ids[btn] = signal_connect(btn, :toggled) do btn, xs...
            val =  getproperty(btn, :active, Bool)
            values = widget.signal.value
            lab = getproperty(btn, :label, AbstractString)
            i = findfirst(labs, lab)
            if val
                !(vals[i] in values) && push!(values, vals[i])
            else
                (vals[i] in values) && (values = filter(x -> vals[i] != x, values))
            end
            push!(widget.signal, values)
        end
    end

    ## signal -> widget
    Reactive.foreach(widget.signal) do values
        
        indices = [findfirst(vals, v) for v in values]
        selectedlabs = labs[indices]

        for btn in btns
            signal_handler_block(btn, ids[btn])
            setproperty!(btn, :active, getproperty(btn, :label, AbstractString) in selectedlabs)
            signal_handler_unblock(btn, ids[btn])
        end

    end


    

    block
end


## select -- a grid
function gtk_widget(widget::Options{:Select})
    error("Select is not supported, as there is pending pull request")

    
    labs = collect(keys(widget.options))
    vals = collect(values(widget.options))

    m = @GtkListStore(eltype(labs))
    block = @GtkScrolledWindow()
    obj = @GtkTreeView()
    [setproperty!(obj, x, true) for  x in [:hexpand, :vexpand]]
    push!(block, obj)

    Gtk.G_.model(obj, m)
    for lab in labs
        push!(m, (lab,))
    end

    cr = @GtkCellRendererText()
    col = @GtkTreeViewColumn(widget.label, cr, Dict([("text",0)]))
    push!(obj, col)

    ## initial choice
    index = findfirst(labs, widget.value_label)
    selection = Gtk.G_.selection(obj)
    store = getproperty(obj, :model, Gtk.GtkListStoreLeaf)
    iter = Gtk.iter_from_index(store, index)
    Gtk.select!(selection, iter)

    ## set up callback widget -> signal
    id = signal_connect(selection, :changed) do args...
        iter = selected(selection)
        i = Gtk.index_from_iter(store, iter)  ## XXX This needs a pull request to be accepted XXX
        push!(widget.signal, vals[i])
    end
    
    ## push! -> update UI
    Reactive.foreach(widget.signal) do val
        signal_handler_block(selection, id)
        index = findfirst(vals, val)
        iter = Gtk.iter_from_index(store, index)
        Gtk.select!(selection, iter)
        signal_handler_unblock(selection, id)
    end

    block

    
end



## Output widgets


## CairoGraphic
function gtk_widget(widget::CairoGraphic)
    if widget.obj != nothing
        return widget
    end

    obj = @GtkCanvas(widget.width, widget.height)
    ## how to make winston draw here? Here we store canvas in obj and override push!
    ## is there a more natural way??
    widget.obj = obj
    widget.signal = Signal(widget)
    widget
end



## Text area.
## unfortunately, setting the font doesn't seem to work.
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
    setproperty!(widget.buffer, :text, widget.value)

    widget.obj = block
    #    widget.signal = Input(widget)
    widget.signal = Signal(widget)
    widget
end

## change text in view
function Base.push!(obj::Textarea, value::AbstractString) 
    setproperty!(obj.buffer, :text, value)
    value
end



## Label
function gtk_widget(widget::Label) 
    obj = @GtkLabel(widget.value)
    setproperty!(obj, :selectable, true)
    setproperty!(obj, :use_markup, true)

    widget.obj = obj
    #    widget.signal = Input(widget)
    widget.signal = Signal(widget)
    widget
end

function Base.push!(obj::Label, value::AbstractString) 
    setproperty!(obj.obj, :label, value)
    setproperty!(obj.obj, :use_markup, true)
    obj.value = value
end

## shared or label, textarea
typealias TextOrLabel @compat Union{Textarea, Label}
Base.push!{T <: AbstractString}(obj::TextOrLabel, value::Vector{T}) = push!(obj, join(value, "\n"))

function Base.push!(obj::TextOrLabel, value)
    push!(obj, to_string(value))
end

## Progress bar
function gtk_widget(widget::Progress) 
    obj = @GtkProgressBar()

    
    widget.obj = obj
    push!(widget, widget.value)
    #    widget.signal = Input(widget)
    widget.signal = Signal(widget)
    widget
end

## push value in range of obj.range
function Base.push!(widget::Progress, value)
    frac = clamp((value - first(widget.range)) / (last(widget.range) - first(widget.range)), 0, 1)
    setproperty!(widget.obj, :fraction, frac)
end



## Main window
function init_window(widget::MainWindow)
    if widget.obj != nothing
        return widget
    end

    widget.window = @GtkWindow(title=widget.title)
    resize!(widget.window, widget.width, widget.height)

    box = @GtkBox(:v)
    push!(widget.window, box)

    al = @GtkAlignment(0.0, 0.0, 1.0, 1.0)
    for pad in [:right_padding, :top_padding, :left_padding, :bottom_padding]
        setproperty!(al, pad, 5)
    end

    
    widget.obj = @GtkGrid()
    setproperty!(widget.obj, :hexpand, true)
    setproperty!(widget.obj, :row_spacing, 5)
    setproperty!(widget.obj, :column_spacing, 5)

    push!(box, al)
    push!(al, widget.obj)

    widget                      # return widget here...
end
  
## add children
function Base.push!(parent::MainWindow, obj::InputWidget) 
    widget = gtk_widget(obj)
    lab = obj.label
    
    al = @GtkAlignment(1.0, 0.0, 0.0, 0.0)
    setproperty!(al, :right_padding, 5)
    setproperty!(al, :left_padding, 5)
    setproperty!(widget, :hexpand, true)

    push!(al, @GtkLabel(lab))
    parent.obj[1, parent.nrows] = al
    parent.obj[2, parent.nrows] = widget

    parent.nrows = parent.nrows + 1
    showall(parent.window)
end


function Base.push!(parent::MainWindow, obj::Widget) 
    widget = gtk_widget(obj)

    parent.obj[2, parent.nrows] = (:obj in fieldnames(obj)) ? obj.obj : widget
    parent.nrows = parent.nrows + 1
    showall(parent.window)
end

Base.append!(parent::MainWindow, items) = map(x -> push!(parent, x), items)


## for displaying an @manipulate object, we need this
Base.display(x::ManipulateWidget) = Reactive.foreach(a -> show_outwidget(x.w, a), x.a)

function show_outwidget(w, x)
            
    x == nothing && return()
    if w.label == nothing
        w.label = @GtkLabel("")
        setproperty!(w.label, :selectable, true)
        setproperty!(w.label, :use_markup, true)
        push!(w.window[1], w.label)
        showall(w.window)
    end
    setproperty!(w.label, :label, to_string(x))
end

## convert object to string for display through label
to_string(x::AbstractString) = x
to_string(x) = sprint(io -> writemime(io, "text/plain", x))
