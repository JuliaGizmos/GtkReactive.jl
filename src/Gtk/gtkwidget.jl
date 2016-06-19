## Code that is Gtk specific

## Plotting code is package dependent
## Plots should dispatch to underlying code for Immerse, Winston or PyPlot


## Plots package

## Helper to add canvas to main window if none there
function make_canvas(w::MainWindow, x)
    if w.out == nothing
        w.out = cairographic()
        push!(w, grow(w.out))
        display(w)
    end
    push!(w.out, x)
end


Requires.@require Plots begin
    ## In general use a canvas to display a plot in the main window
    show_outwidget(w::GtkInteract.MainWindow, x::Plots.Plot) = make_canvas(w, x)

    function Base.push!(obj::CairoGraphic, p::Plots.Plot)
        if obj.obj != nothing
            push!(obj.obj, p)
        end
    end
    Base.push!(c::GtkCanvas, p::Plots.Plot) = push!(c, p.o[2])

    ## show_outwidget makes a display widget for a plot

    ## ## For unicode plots we try a label, but doesn't work...
    ## function show_outwidget(w::GtkInteract.MainWindow, p::Plots.Plot{Plots.UnicodePlotsPackage})
    ##      .....
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

        ## Add figure, But should I close the next one??
        i = Immerse.nextfig(Immerse._display)
        f = Immerse.Figure(cnv)
        Immerse.initialize_toolbar_callbacks(f)
        Immerse.addfig(Immerse._display, i, f)

        box
    end


    ## same as Plots.Plot, make canvas window
    function show_outwidget(w::GtkInteract.MainWindow, x::Gadfly.Plot)
        if w.out == nothing
            w.out = immersefigure()
            push!(w, grow(w.out))
            display(w)
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

    show_outwidget(w::GtkInteract.MainWindow, x::Winston.PlotContainer) = make_canvas(w, x)

    function Base.push!(obj::CairoGraphic, pc::Winston.PlotContainer)
        if obj.obj != nothing
            Winston.display(obj.obj, pc)
        end
    end
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
        error("XXX This is broken XXX")
        if w.out == nothing
            w.out = image()
            push(w, grow(w.out))
            display(w)
        end

        f = tempname() * ".png"
        io = open(f, "w")
        writemime(io, "image/png", x)
        close(io)
        push!(w.out, f)
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

function button_cb(btnptr::Ptr, user_data)
    w, o = user_data
#    println(typeof(o))
    println("Push value to object of type $(typeof(w))")
    #    push!(w.signal, Reactive.value(Interact.signal(w)))
    #    push!(w, value(w))
    push!(w, nothing)

end
function gtk_widget(widget::Button)
    obj = @GtkButton(widget.label)

    ## widget -> signal
    id = signal_connect(button_cb, obj, "clicked", Void, (),  false, (widget, obj))
#    id = signal_connect(obj, :clicked) do obj, args...
#        push!(widget.signal,Reactive.value(Interact.signal(widget))) # call
#    end
    signal_connect(obj, :destroy) do args...
        signal_handler_block(obj, id)
    end

    obj
end

## checkbox
function checkbox_cb(cbptr::Ptr,  user_data)
    w, o = user_data
    val = getproperty(o, :active, Bool)
    push!(w.signal, getproperty(o, :active, Bool))
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
    w, o = user_data
    val = Gtk.G_.value(o)
    push!(w.signal, val)
    nothing
end

function gtk_widget(widget::Slider)
    obj = @GtkScale(false, first(widget.range), last(widget.range), step(widget.range))
    Gtk.G_.size_request(obj, 200, -1)
    Gtk.G_.value(obj, widget.value)

    ## widget -> signal
    ## https://github.com/JuliaLang/Gtk.jl/blob/master/doc/more_signals.md
    id = signal_connect(scale_cb, obj, "value-changed", Void, (), false, (widget, obj))

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
    w, o = user_data
    value = getproperty(o, :active, Bool)
    push!(w.signal, value)
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
function gtk_widget(widget::Textbox)
    obj = @GtkEntry
    setproperty!(obj, :text, string(widget.signal.value))

    id = signal_connect(obj, :activate) do o
        try
            val = Interact.parse_msg(widget, getproperty(o, :text, AbstractString))
            push!(widget.signal, val)
        catch
            str = getproperty(o, :text, AbstractString)
            messagebox("\"$str\" cannot be parsed as a $(eltype(signal(widget)))", :error)
        end
        false
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
function combobox_cb(o::Ptr, user_data)
    w, o = user_data
    index = getproperty(o, :active, Int) + 1
    push!(w.signal, collect(values(w.options))[index])
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
    w, o = user_data
    if getproperty(o, :active, Bool)
        label = getproperty(o, :label, AbstractString)
        push!(w.signal, w.options[label])
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

    btns = Dict()
    for (lab, val) in zip(labs, vals)
        btn =  Gtk.@GtkToggleButton(lab)
        btns[lab] = btn
        push!(block, btn)
    end

    ## widget -> signal
    ids = Dict()
    for (lab, btn) in btns
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

        for (lab, btn) in btns
            signal_handler_block(btn, ids[btn])
            setproperty!(btn, :active, getproperty(btn, :label, AbstractString) in selectedlabs)
            signal_handler_unblock(btn, ids[btn])
        end

    end

    ## set initial *after* foreach call
    for (lab, val) in zip(labs, vals)
        btn =  btns[lab]
        setproperty!(btn, :active, val in widget.values)
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


##################################################
## Output widgets


## CairoGraphic
function gtk_widget(widget::CairoGraphic)
    if widget.obj == nothing

        obj = @GtkCanvas(widget.width, widget.height)
        ## how to make winston draw here? Here we store canvas in obj and override push!
        ## is there a more natural way??
        widget.obj = obj
    end

    widget.obj
end

## CairoImageSurface
function gtk_widget(widget::CairoImageSurface)
    if widget.obj == nothing
        obj = @GtkCanvas(widget.width, widget.height)
        widget.obj = obj
        Gtk.draw(obj) do canvas
            ctx = Cairo.getgc(canvas)
            Cairo.save(ctx)
            Cairo.reset_transform(ctx)
            Cairo.image(ctx, widget.surf, 0, 0, Cairo.width(ctx), Cairo.height(ctx))
        end
    end

    widget.obj
end


## Text area.
## unfortunately, setting the font doesn't seem to work.
function gtk_widget(widget::Textarea)
    if widget.obj == nothing
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
    end
    widget.obj
end

## change text in view
function Base.push!(obj::Textarea, value::AbstractString)
    if obj.buffer != nothing
        setproperty!(obj.buffer, :text, value)
        obj.value = value
    end
    value
end



## Label
function gtk_widget(widget::Label)
    if widget.obj == nothing
        obj = @GtkLabel(widget.value)
        setproperty!(obj, :selectable, true)
        setproperty!(obj, :use_markup, true)

        widget.obj = obj
    end

    widget.obj
end

function Base.push!(widget::Label, value::AbstractString)
    if widget.obj != nothing
        setproperty!(widget.obj, :label, value)
        setproperty!(widget.obj, :use_markup, true)
        widget.value = value
    end
    value
end


## Catch all `push!` for non AbstractString for label or textarea
typealias TextOrLabel Union{Textarea, Label}
Base.push!{T <: AbstractString}(obj::TextOrLabel, value::Vector{T}) = push!(obj, join(value, "\n"))
Base.push!(obj::TextOrLabel, value::Reactive.Signal) = push!(obj, Reactive.value(value))
Base.push!(obj::TextOrLabel, value) = push!(obj, to_string(value))

## Image
function gtk_widget(widget::Image)
    if widget.obj == nothing
        obj = @GtkImage()
        widget.obj = obj
    end
    if widget.value != nothing
        Gtk.G_.file(obj, widget.value)
    end
    widget.obj
end
function Base.push!(widget::Image, val::AbstractString)
    if widget.obj != nothing
        widget.value = val
        Gtk.G_.file(widget.obj, val)
    end
end
##################################################
## Decorative
## icon (no obj property) as we don't push onto these
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

function gtk_widget(widget::Tooltip)
    obj = gtk_widget(widget.tile)
    setproperty!(obj, :tooltip_text, widget.text)
    obj
end

## Progress bar
function gtk_widget(widget::Progress)
    obj = @GtkProgressBar()
    widget.obj = obj

    push!(widget, widget.value)
    obj
end

## push value in range of obj.range
Base.push!(obj::Progress, value::Reactive.Signal) = push!(obj, Reactive.value(value))
function Base.push!(widget::Progress, value)
    if widget.obj != nothing
        frac = clamp((value - first(widget.range)) / (last(widget.range) - first(widget.range)), 0, 1)
        setproperty!(widget.obj, :fraction, frac)
    end
end

##################################################
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

formlabel(widget::Widget) = :label in fieldnames(widget) ? widget.label : ""
formlabel(widget::Button) = ""
formlabel(widget) = ""

function gtk_widget(widget::FormLayout)
    obj = @GtkGrid()
    setproperty!(obj, :hexpand, true)
    setproperty!(obj, :row_spacing, 5)
    setproperty!(obj, :column_spacing, 5)

    for (row, child) in enumerate(widget.children)
        al = @GtkAlignment(1.0, 0.0, 0.0, 0.0)
        setproperty!(al, :right_padding, 5)
        setproperty!(al, :left_padding, 5)

        child_widget = gtk_widget(child)
        setproperty!(child_widget, :hexpand, true)

        push!(al, @GtkLabel(formlabel(child)))

        obj[1, row] = al
        obj[2, row] = child_widget
    end

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
    obj = @GtkToolButton("")
    Gtk.G_.label(obj, widget.label)

    ## widget -> signal
    id = signal_connect(button_cb, obj, "clicked", Void, (),  false, (widget, obj))
#    id = signal_connect(obj, :clicked) do obj, args...
#        push!(widget.signal, value(widget)) # call
#    end

    obj
end
function gtk_toolbar_widget(widget::ToggleButton)
    obj = @GtkToggleToolButton(widget.label)
    Gtk.G_.label(obj, widget.label)
    setproperty!(obj, :active, widget.value)

    ## widget -> signal
    id = signal_connect(obj, :toggled) do obj, args...
        val = getproperty(obj, :active, Bool)
        push!(widget.signal, val) # call
    end

    obj
end

## XXX This isn't working XXX
function gtk_toolbar_widget(widget::MenuButton)
    obj = @GtkMenuToolButton(widget.label)
    Gtk.G_.label(obj, widget.label)

    m = @GtkMenu()
    Gtk.G_.menu(obj, m)
    push!(m , gtk_menu_widget(menu(widget.children...)))
    showall(obj)
    obj
end

function gtk_toolbar_widget(child::Separator)
    obj = @GtkSeparatorToolItem()
    obj
end

function gtk_toolbar_widget(widget::Icon)
    img = @GtkImage()
    setproperty!(img, :icon_name, widget.stock_id)

    obj = gtk_toolbar_widget(widget.tile) # must be non-empty or an error
    Gtk.G_.icon_widget(obj, img)

    obj
end

function gtk_toolbar_widget(widget::Tooltip)
    obj = gtk_toolbar_widget(widget.tile)
    setproperty!(obj, :tooltip_text, widget.text)
    obj
end

## How to put in a spacer in a toolbar?
## We use vskip() to place a spring in a toolbar
function gtk_toolbar_widget(widget::Size)
    obj = @GtkSeparatorToolItem()
    Gtk.G_.draw(obj, false)
    Gtk.G_.expand(obj, true)
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

    id = signal_connect(button_cb, obj, "activate", Void, (),  false, (widget, obj))
    ## widget -> signal
#    id = signal_connect(obj, :activate) do obj, args...
#        push!(widget.signal, Reactive.value(Interact.signal(widget))) # call
#    end

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

## XXX This isn't working XXX
function gtk_widget(widget::MenuButton)
    error("GtkMenuButton is not (yet) in Gtk.jl")
    #obj = @GtkMenuButton()              # error, not (yet) part of Gtk.jl
    for child in widget.chldren
        push!(obj, gtk_menu_widget(child))
    end
    obj
end


##
function gtk_widget(widget::Window)
    obj = @GtkWindow(title=widget.title)
    widget.obj = obj
    widget.width > 0 && widget.height > 0 && resize!(obj, widget.width, widget.height)

    ## interior packing box...
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
function gtk_widget(widget::MainWindow)
    obj =  @GtkWindow(title=widget.title)
    resize!(obj, widget.width, widget.height)
    widget.window = obj
    signal_connect(obj, :destroy) do win
        closerefs!(widget.refs)
    end

    push!(obj, gtk_widget(formlayout(widget.children...)))

    obj
end


## for displaying an @manipulate object, we need this
function Base.display(x::ManipulateWidget)
    Reactive.foreach(a -> show_outwidget(x.w, a), x.a)
    ## hack to get output widgets passed in
    tmp = filter(u->!isa(u, GtkInteract.OutputWidget), x.w.children)[1]
    push!(tmp, value(tmp))
    nothing
end

## Catch all for showing outwidget
function show_outwidget(w::GtkInteract.MainWindow, x)

    if w.out == nothing
        w.out = label("")
        push!(w, grow(w.out))
        display(w)
    end
    x != nothing &&  push!(w.out, to_string(x))
end


## convert object to string for display through label
to_string(x::AbstractString) = x
to_string(x) = sprint(io -> writemime(io, "text/plain", x))

## Dialogs
function gtk_widget(widget::MessageBox)
    if widget.style == :warnt
        fn = Gtk.warn_dialog
    elseif widget.style == :error
        fn = Gtk.error_dialog
    else
        fn = Gtk.info_dialog
    end

    fn(widget.msg)

end

function gtk_widget(widget::ConfirmBox)
    Gtk.ask_dialog(widget.msg)
end

function gtk_widget(widget::InputBox)
    ret, val = Gtk.input_dialog(widget.msg, widget.default)
    if ret == 0
        val = utf8("")
    end
    val
end

function gtk_widget(widget::OpenFile)
    open_dialog(widget.title)
end

function gtk_widget(widget::SaveFile)
    save_dialog(widget.title)
end

function gtk_widget(widget::SelectDir)
    dlg = @GtkFileChooserDialog(widget.title, Gtk.GtkNullContainer(),
                                Gtk.GConstants.GtkFileChooserAction.SELECT_FOLDER,
                                (("_Cancel", Gtk.GConstants.GtkResponseType.CANCEL),
                                 ("_Save",   Gtk.GConstants.GtkResponseType.ACCEPT))
                                )
    dlgp = GtkFileChooser(dlg)
    response = run(dlg)
    if response == Gtk.GConstants.GtkResponseType.ACCEPT
        selection = bytestring(GAccessor.filename(dlgp))
    else
        selection = utf8("")
    end
    destroy(dlg)
    selection
end



## Typeography
gtk_widget(obj::Bold) = gtk_widget(label("<b>$(obj.label)</b>"))
gtk_widget(obj::Emph) = gtk_widget(label("<i>$(obj.label)</i>"))
gtk_widget(obj::Code) = gtk_widget(label("<tt>$(obj.label)</tt>"))
