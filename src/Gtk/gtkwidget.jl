## Code that is Gtk specific

## Plotting code is package dependent
## Plots should dispatch to underlying code for Immerse, Winston or PyPlot


## Plots package

## Helper to add canvas to main window if none there
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

Requires.@require Plots begin
    ## In general use a canvas to display a plot in the main window
    show_outwidget(w::GtkInteract.MainWindow, x::Plots.Plot) = make_canvas(w, x)
    
    Base.push!(obj::CairoGraphic, p::Plots.Plot) = push!(obj.obj, p)
    Base.push!(c::GtkCanvas, p::Plots.Plot) = push!(c, p.o[2])

    ## show_outwidget makes a display widget for a plot

    ## ## For unicode plots we try a label, but doesn't work...
    ## function show_outwidget(w::GtkInteract.MainWindow, p::Plots.Plot{Plots.UnicodePlotsPackage})
    ##      if w.label == nothing
    ##         w.label = @GtkLabel("")
    ##         setproperty!(w.label, :selectable, true)
    ##         setproperty!(w.label, :use_markup, true)
    ##         push!(w.window[1], w.label)
    ##         showall(w.window)
    ## end
    
    ##     ## Fails!
    ##     Plots.rebuildUnicodePlot!(p)
    ##     out = sprint(io -> writemime(io, "text/plain", p.o))
    ##     setproperty!(w.label, :label, out)
    ## end
end

## Immerse
## XXX This has issues, as the canvas doen't get refreshed between draws
Requires.@require Immerse begin
    eval(Expr(:using, :Gadfly))
    eval(Expr(:using, :Compose))

    function gtk_widget(widget::ImmerseFigure)
        widget.obj != nothing && return(widget.obj)

        box, toolbar, cnv = Immerse.createPlotGuiComponents()
        Gtk.G_.size_request(box, 480, 400)
        widget.obj = box
        widget.toolbar = toolbar
        widget.cnv = cnv

        widget.signal = Signal(widget)

        ## Add figure, But should I close the next one??
        i = Immerse.nextfig(Immerse._display)
        f = Immerse.Figure(cnv)
        Immerse.initialize_toolbar_callbacks(f)        
        Immerse.addfig(Immerse._display, i, f)
        
        box
    end
        
    
    ## same as Plots.Plot, make canvas window
    function show_outwidget(w::GtkInteract.MainWindow, x::Gadfly.Plot)
        if w.cg == nothing
            widget = immersefigure()
            o = gtk_widget(widget)
            w.cg = widget.cnv
            box = w.window[1]
            push!(box, o)
            showall(w.window)
        end
        display(Immerse._display, x)
    end

    ## this is used by Plots+Immerse
    function Base.push!(c::GtkCanvas, p::Gadfly.Plot)
        display(c, Immerse.Figure(c, p))
    end

    
end



## Winston
## Winston is a problem if `ENV["WINSTON_OUTPUT"] = :gtk` is not set *beforehand*
Requires.@require Winston begin
    ENV["WINSTON_OUTPUT"] = :gtk    

    show_outwidget(w::GtkInteract.MainWindow, x::Winston.FramedPlot) = make_canvas(w, x)
    
    Base.push!(obj::CairoGraphic, pc::Winston.PlotContainer) = Winston.display(obj.obj, pc)    
    Base.push!(c::GtkCanvas, pc::Winston.PlotContainer) = Winston.display(c, pc)
end

## Gadfly 
Requires.@require Gadfly begin
    info("Gadfly support is through the Immerse package. Please install that.")

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
    function show_outwidget(w::GtkInteract.MainWindow, x::PyPlot.Figure) 
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

## link up widget and its gtk proxy

## button
##
## button("label") is constructor
##
function gtk_widget(widget::Button)
    obj = @GtkButton(widget.label)
#    widget.label = "" ## XXX why do I have this?

    ## widget -> signal
    id = signal_connect(obj, :clicked) do obj, args...
        push!(widget.signal,Reactive.value(Interact.signal(widget))) # call
    end

    obj
end

## checkbox
function checkbox_cb(cbptr::Ptr,  user_data)
    widget, obj = user_data
    val = getproperty(obj, :active, Bool)
    push!(widget.signal, getproperty(obj, :active, Bool))
    nothing
end
function gtk_widget(widget::Checkbox)
    obj = @GtkCheckButton()
    setproperty!(obj, :active, Reactive.value(Interact.signal(widget)))

    ## widget -> signal
    id = signal_connect(checkbox_cb, obj, "toggled", Void, (),  false, (widget, obj))

   Reactive.foreach(widget.signal) do val
       signal_handler_block(obj, id)
       curval = getproperty(obj, :active, Bool)
       val != curval && setproperty!(obj, :active, val) 
       signal_handler_unblock(obj, id)
   end
        

    obj
end


## slider
## following
## https://github.com/timholy/GtkUtilities.jl/blob/b36edfca6b4f0c0b6351f1c1409e4e2d04ca4f8f/src/link.jl#L243-L253
## strangely, this can not be defined within gtk_widget...
function scale_cb(scaleptr::Ptr, user_data)
    obj, widget = user_data
    val = Gtk.G_.value(obj)
    push!(widget.signal, val)
    nothing
end

function gtk_widget(widget::Slider)
    obj = @GtkScale(false, first(widget.range), last(widget.range), step(widget.range))
    Gtk.G_.size_request(obj, 200, -1)
    Gtk.G_.value(obj, widget.value)

    ## widget -> signal
    ## https://github.com/JuliaLang/Gtk.jl/blob/master/doc/more_signals.md
    id = signal_connect(scale_cb, obj, "value-changed", Void, (), false, (obj, widget))

    ## ## this might be an issue with #161
    ## id = signal_connect(obj, :value_changed) do obj, args...
    ##     val = Gtk.G_.value(obj)
    ##     push!(widget.signal, val)
    ## end
    
    ## 
    Reactive.foreach(widget.signal) do val
        signal_handler_block(obj, id)
        curval = Gtk.G_.value(obj)
        curval != val && Gtk.G_.value(obj, val)
        signal_handler_unblock(obj, id)
    end
    
    obj
end

## togglebutton (single one. XXX is label on button or a label? XXX)
function togglebtn_cb(toggleptr::Ptr, user_data)
    widget, obj = user_data
    value = getproperty(obj, :active, Bool)
    push!(widget.signal, value)
    nothing
end

function gtk_widget(widget::ToggleButton)
    obj = @GtkToggleButton(string(widget.label))
    setproperty!(obj, :active, widget.value)

    ## widget -> signal
    id = signal_connect(togglebtn_cb, obj, "toggled", Void, (), false, (widget, obj))

    ## signal -> widget
    Reactive.foreach(widget.signal) do val
        signal_handler_block(obj, id)
        setproperty!(obj, :active, val)
        signal_handler_unblock(obj, id)
    end


    obj
end


## textbox
function textbox_cb(entryptr::Ptr, eventptr::Ptr, user_data)
    widget, obj = user_data
    txt = getproperty(obj, :text, AbstractString)
    push!(widget.signal, txt)
    false
end

function gtk_widget(widget::Textbox)
    obj = @GtkEntry
    setproperty!(obj, :text, string(widget.signal.value))

    ## widget -> signal
    id = signal_connect(textbox_cb, obj,
                                  "key-release-event", Bool, (Ptr{Gtk.GdkEventButton},), false,
                                  (widget, obj))

    ## id = signal_connect(obj, :key_release_event) do obj, e, args...
    ##     txt = getproperty(obj, :text, AbstractString)
    ##     push!(widget.signal, txt)
    ## end

    
    ## signal -> widget
    Reactive.foreach(widget.signal) do val
        signal_handler_block(obj, id)
        setproperty!(obj, :text, string(val))
        signal_handler_unblock(obj, id)
    end

    obj
end

## dropdown
function combobox_cb(o::Ptr, user_data)
    widget, obj = user_data
    index = getproperty(obj, :active, Int) + 1
    push!(widget.signal, collect(values(widget.options))[index])
    nothing
end

function gtk_widget(widget::Options{:Dropdown})
    obj = @GtkComboBoxText(false)
    for key in keys(widget.options)
        push!(obj, key)
    end
    index = findfirst(collect(keys(widget.options)), widget.value_label)
    setproperty!(obj, :active, index - 1)

    ## widget -> signal
    id = signal_connect(combobox_cb, obj, "changed", Void, (), false, (widget, obj))
#    id = signal_connect(obj, :changed) do obj, args...
#        index = getproperty(obj, :active, Int) + 1
#        push!(widget.signal, collect(values(widget.options))[index])
#    end

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
function radiobtn_cb(r::Ptr, user_data)
    widget, obj = user_data
    if getproperty(obj, :active, Bool)
        label = getproperty(obj, :label, AbstractString)
        push!(widget.signal, widget.options[label])
    end
end
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
        ids[btn] = signal_connect(radiobtn_cb, btn, "toggled", Void, (), false, (widget, btn))
        ## ids[btn] = signal_connect(btn, :toggled) do obj, args...
        ##     if getproperty(obj, :active, Bool)
        ##         label = getproperty(obj, :label, AbstractString)
        ##         push!(widget.signal, widget.options[label])
        ##     end
        ## end
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
## was seeing crashing, so try this.
function togglebtn_press_event_cb(btnptr::Ptr, evt::Ptr, user_data)
    btn, btns, w, vals, labs = user_data
    val =  getproperty(btn, :active, Bool)
    if !val
        ## set button state
        for b in btns
            setproperty!(b, :active, b==btn)
        end
        ## set widget state
        push!(w.signal, vals[findfirst(labs, getproperty(btn, :label, AbstractString))])
    end
    true
end

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
        ids[btn] = signal_connect(togglebtn_press_event_cb, btn,
                                  "button-press-event", Bool, (Ptr{Gtk.GdkEventButton},), false,
                                  (btn, btns, widget, vals, labs))
        ## ids[btn] = signal_connect(btn, :button_press_event) do _,__
        ##     val =  getproperty(btn, :active, Bool)
        ##     if !val
        ##         ## set button state
        ##         for b in btns
        ##             setproperty!(b, :active, b==btn)
        ##         end
        ##         ## set widget state
        ##         push!(widget.signal, vals[findfirst(labs, getproperty(btn, :label, AbstractString))])
        ##     end
        ##     true                # impt: stop evennt propogation
        ## end
    end

    ## ## signal -> widget
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

function buttongroup_cb(o::Ptr, user_data)
    widget, btn, labs, vals = user_data
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
    nothing
end
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
        ids[btn] = signal_connect(buttongroup_cb, btn, "toggled", Void, (), false, (widget, btn, labs, vals))
        ## ids[btn] = signal_connect(btn, :toggled) do btn, xs...
        ##     val =  getproperty(btn, :active, Bool)
        ##     values = widget.signal.value
        ##     lab = getproperty(btn, :label, AbstractString)
        ##     i = findfirst(labs, lab)
        ##     if val
        ##         !(vals[i] in values) && push!(values, vals[i])
        ##     else
        ##         (vals[i] in values) && (values = filter(x -> vals[i] != x, values))
        ##     end
        ##     push!(widget.signal, values)
        ## end
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
    
    labs = collect(map(AbstractString,keys(widget.options)))
    vals = collect(map(AbstractString,values(widget.options)))

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
        j = Gtk.get_string_from_iter(Gtk.GtkTreeModel(store), iter)
        i = parse(Int, j) + 1
        #map(int, split(get_string_from_iter(treeModel, iter), ":")) + 1
#        i = Gtk.index_from_iter(store, iter)  
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
        return widget.obj
    end

    obj = @GtkCanvas(widget.width, widget.height)
    ## how to make winston draw here? Here we store canvas in obj and override push!
    ## is there a more natural way??
    widget.obj = obj
    widget.signal = Signal(widget)
    obj
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
    block
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
    widget.signal = Signal(widget)


    obj
end

function Base.push!(obj::Label, value::AbstractString) 
    setproperty!(obj.obj, :label, value)
    setproperty!(obj.obj, :use_markup, true)
    obj.value = value
end


## shared or label, textarea
typealias TextOrLabel Union{Textarea, Label}
Base.push!(obj::TextOrLabel, value::Reactive.Node) = push!(obj, Reactive.value(value))
Base.push!{T <: AbstractString}(obj::TextOrLabel, value::Vector{T}) = push!(obj, join(value, "\n"))

function Base.push!(obj::TextOrLabel, value)
    push!(obj, to_string(value))
end

## icon
function gtk_widget(widget::Icon)
    obj = @GtkImage()
    setproperty!(obj, :icon_name, widget.stock_id)

    if widget.tile != nothing
        child = gtk_widget(widget.tile)
        setproperty!(child, :always_show_image, true)
        Gtk.G_.image(child, obj)
        obj = child
    end

    obj
end


## Progress bar
function gtk_widget(widget::Progress) 
    obj = @GtkProgressBar()
    widget.obj = obj
    
    push!(widget, widget.value)
    widget.signal = Signal(widget)
    obj
end

## push value in range of obj.range
Base.push!(obj::Progress, value::Reactive.Node) = push!(obj, Reactive.value(value))
function Base.push!(widget::Progress, value)
    frac = clamp((value - first(widget.range)) / (last(widget.range) - first(widget.range)), 0, 1)
    setproperty!(widget.obj, :fraction, frac)
end


## Layouts

## Attributes
function gtk_widget(widget::Size)
    # set size of tile
    obj = gtk_widget(widget.tile)

    Gtk.G_.size_request(obj, widget.w_px.value, widget.h_px.value)
    
    obj
end

function gtk_widget(widget::Grow)
    obj = gtk_widget(widget.tile)
    ## how to use factor? It is in [0,1]?
    widget.factor > 0 && :horizontal in widget.direction && Gtk.G_.hexpand(obj, true)
    widget.factor > 0 && :vertical in widget.direction && Gtk.G_.vexpand(obj, true)

    obj
end


function gtk_widget(widget::Shrink)
    obj = gtk_widget(widget.tile)
    ## how to use factor?
    if widget.factor > 0
        Gtk.G_.hexpand(obj, false)
        Gtk.G_.vexpand(obj, false)
    end

    obj
end

function gtk_widget(widget::Pad)
    # set size of tile
    obj = gtk_widget(widget.tile)

    ## group on keywaor...
    :left in widget.sides   && Gtk.G_.margin_left(obj, widget.len.value)
    :right in widget.sides && Gtk.G_.margin_right(obj, widget.len.value)
    :top in widget.sides    && Gtk.G_.margin_top(obj, widget.len.value)
    :bottom in widget.sides && Gtk.G_.margin_bottom(obj, widget.len.value)
    
    obj
end


function gtk_widget(widget::Align)
    # set alignment
    obj = gtk_widget(widget.tile)

    Gtk.G_.halign(obj, widget.halign)
    Gtk.G_.valign(obj, widget.valign)
    
    obj
end

## containers
function gtk_widget(widget::FlowContainer)
    obj = widget.obj =  @GtkBox(widget.direction == "vertical") # GtkFlowBox...
    for child in widget.children
        push!(obj, gtk_widget(child))
    end
    obj
end


function gtk_widget(widget::Separator)
    obj = @GtkLabel("* * * * *")        # poor man's separator...
    Gtk.G_.margin_top(obj, 5)
    Gtk.G_.margin_bottom(obj, 5)
    obj
end

function gtk_widget(widget::Tabs)
    obj = @GtkNotebook()
    for (label, child) in zip(widget.labels, widget.children)
        gchild = gtk_widget(child)
        push!(obj, gchild, label)
        show(gchild)
    end
    Gtk.G_.current_page(obj, widget.initial-1)
    obj
end

## Toolbar
function gtk_widget(widget::Toolbar)
    obj = @GtkToolbar()
    Gtk.G_.style(obj, Gtk.GConstants.GtkToolbarStyle.GTK_TOOLBAR_BOTH)
    
    for child in widget.children
        tbchild = gtk_toolbar_widget(child)
        push!(obj, tbchild)
    end

    obj
end

function gtk_toolbar_widget(widget::Button)
    obj = @GtkToolButton(widget.label)
    Gtk.G_.label(obj, widget.label)

    ## widget -> signal
    id = signal_connect(obj, :clicked) do obj, args...
        push!(widget.signal, Reactive.value(Interact.signal(widget))) # call
    end
    
    obj
end
function gtk_toolbar_widget(widget::ToggleButton)
    obj = @GtkToggleToolButton(widget.label)
    Gtk.G_.label(obj, widget.label)
    
    ## widget -> signal
    id = signal_connect(obj, :toggled) do obj, args...
        val = getproperty(obj, :active, Bool)
        push!(widget.signal, val) # call
    end
    
    obj
end
#function gtk_toolbar_widget(child::Interact.Dropdown)
#end

function gtk_toolbar_widget(child::Separator)
    obj = @GtkSeparatorToolItem()
    obj
end

function gtk_toolbar_widget(widget::Icon)
    img = @GtkImage()
    setproperty!(img, :icon_name, widget.stock_id)

    obj = gtk_toolbar_widget(widget.tile)
    Gtk.G_.icon_widget(obj, img)

    obj
end

## menu
function gtk_widget(widget::Menu)
    obj = Gtk.@GtkMenuBar()
    Gtk.G_.hexpand(obj, true)
    for child in widget.children
        push!(obj, gtk_menu_widget(child))
    end

    obj
end

function gtk_menu_widget(widget::Button)
    obj = @GtkMenuItem(widget.label)

    ## widget -> signal
    id = signal_connect(obj, :activate) do obj, args...
        push!(widget.signal, Reactive.value(Interact.signal(widget))) # call
    end
    
    obj

end

function gtk_menu_widget(widget::ToggleButton)
    error("This menu item is not implemented")
    ## Hack to work around no GtkCheckMenuItem
    ## XXX Doesn't work
    ## obj = @GtkMenuItem()
    ## ## remove
    ## child = Gtk.G_.child(obj)
    ## ccall((:gtk_container_remove, Gtk.libgtk), Void, (Ptr{Gtk.GObject}, Ptr{Gtk.GObject}), obj, child)

    ## ## add back
    ## child = @GtkToggleToolButton(widget.label)
    ## Gtk.G_.label(child, widget.label)
    ## push!(obj, child)
    
    ## show(child)
    
    ## ## widget -> signal
    ## id = signal_connect(child, :toggled) do obj, args...
    ##     val = getproperty(child, :active, Bool)
    ##     push!(widget.signal, val) # call
    ## end
    
    ## obj
end

function gtk_menu_widget(widget::Separator)
    obj = @GtkSeparatorMenuItem()
    obj
end

function gtk_menu_widget(widget::Icon)
    ## images don't work?
    obj = gtk_menu_widget(widget.tile)  # will haver error if no tile

    img = @GtkImage()
    setproperty!(img, :icon_name, widget.stock_id)

    Gtk.G_.icon_widget(obj, img)
end

function gtk_menu_widget(widget::Menu)
    obj = @GtkMenuItem(widget.label)
    submenu = @GtkMenu(obj)
    for child in widget.children
         push!(submenu, gtk_menu_widget(child))
    end
    
    obj
end


##
function gtk_widget(widget::Window)
    obj = @GtkWindow(title=widget.title)
    ## interiro packing box...
    box = @GtkBox(true)
    Gtk.G_.hexpand(box, true)
    Gtk.G_.vexpand(box, true)
    push!(obj, box)
    
    for child in widget.children
        push!(box, gtk_widget(child))
    end
    showall(obj)
    obj
end
Base.display(widget::Window) = showall(gtk_widget(widget))


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


function Base.push!(parent::MainWindow, obj::Layout) 
    widget = gtk_widget(obj)

    parent.obj[2, parent.nrows] = (:obj in fieldnames(obj)) ? obj.obj : widget
    parent.nrows = parent.nrows + 1
    showall(parent.window)
end
Base.append!(parent::MainWindow, items) = map(x -> push!(parent, x), items)


## for displaying an @manipulate object, we need this
Base.display(x::ManipulateWidget) = Reactive.foreach(a -> show_outwidget(x.w, a), x.a)

## Catch all for showing outwidget
function show_outwidget(w::GtkInteract.MainWindow, x)
    x == nothing && return()
    if w.label == nothing
        w.label = @GtkLabel("")
        setproperty!(w.label, :selectable, true)
        setproperty!(w.label, :use_markup, true)
        push!(w.window[1], w.label)
        showall(w.window)
    end
    push!(w.label, x)
end

## add text to a label
function Base.push!(l::Gtk.GtkLabel, x)
    setproperty!(l, :label, to_string(x))
end

## convert object to string for display through label
to_string(x::AbstractString) = x
to_string(x) = sprint(io -> writemime(io, "text/plain", x))





## Typeography
gtk_widget(obj::Bold) = gtk_widget(label("<b>$(obj.label)</b>"))
gtk_widget(obj::Emph) = gtk_widget(label("<i>$(obj.label)</i>"))
gtk_widget(obj::Code) = gtk_widget(label("<tt>$(obj.label)</tt>"))

