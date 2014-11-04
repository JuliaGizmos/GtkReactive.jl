## Code that is Gtk specific

## Controls


## button
##
## button("label") is constructor
##
function gtk_widget(widget::Button)
    ## construct widget
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

    function handler(val)
        signal_handler_block(obj, id)
        setproperty!(obj, :active, val)
        signal_handler_unblock(obj, id)
    end
    lift(handler, widget.signal)

    obj
end


## slider
function gtk_widget(widget::Slider)
    obj = @GtkScale(false, first(widget.range), last(widget.range), step(widget.range))
    Gtk.G_.size_request(obj, 200, -1)
    Gtk.G_.value(obj, widget.value)

    ## widget -> signal
    id = signal_connect(obj, :value_changed) do obj, args...
        val = Gtk.G_.value(obj)
        push!(widget.signal, val)
    end
    
    ## 
    function handler(val)
        signal_handler_block(obj, id)
        Gtk.G_.value(obj, val)
        signal_handler_unblock(obj, id)
    end
    lift(handler, widget.signal)

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
    function handler(val)
        signal_handler_block(obj, id)
        setproperty!(obj, :active, val)
        signal_handler_unblock(obj, id)
    end
    lift(handler, widget.signal)


    obj
end


## textbox
function gtk_widget(widget::Textbox)
    obj = @GtkEntry
    setproperty!(obj, :text, string(widget.signal.value))

    ## widget -> signal
    id = signal_connect(obj, :key_release_event) do obj, e, args...
        txt = getproperty(obj, :text, String)
        push!(widget.signal, txt)
    end

    
    ## signal -> widget
    function handler(val)
        signal_handler_block(obj, id)
        setproperty!(obj, :text, string(val))
        signal_handler_unblock(obj, id)
    end
    lift(handler, widget.signal)


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
    function handler(val)
        signal_handler_block(obj, id)
        index = getproperty(obj, :active, Int) + 1
        val = findfirst(collect(values(widget.options)), val)
        if val != index
            setproperty!(obj, :active, val - 1)
        end
        signal_handler_unblock(obj, id)
    end
    lift(handler, widget.signal)


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
                label = getproperty(obj, :label, String)
                push!(widget.signal, widget.options[label])
            end
        end
    end
    setproperty!(obj, :visible, true)
    showall(obj)

    ## signal -> widget
    function handler(val)
        [signal_handler_block(btn, id) for (btn,id) in ids]
        selected = findfirst(collect(values(widget.options)), val)
        setproperty!(btns[selected], :active, true)
        [signal_handler_unblock(btn, id) for (btn,id) in ids]        
    end
    lift(handler, widget.signal)


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
                push!(widget.signal, vals[findfirst(labs, getproperty(btn, :label, String))])
            end
            true                # impt: stop evennt propogation
        end
    end

    ## signal -> widget
    function handler(val)
        ## get index from val
        index = findfirst(vals, val)
        lab = labs[index]
        for btn in btns
            signal_handler_block(btn, ids[btn])
            setproperty!(btn, :active, getproperty(btn, :label, String) == lab)
            signal_handler_unblock(btn, ids[btn])
        end
    end
    lift(handler, widget.signal)


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
            lab = getproperty(btn, :label, String)
            i = findfirst(labs, lab)
            if val
                !(vals[i] in values) && push!(values, vals[i])
            else
                (vals[i] in values) && (values = setdiff(values, vals[i]))
            end
            push!(widget.signal, values)
        end
    end

    ## signal -> widget
    function handler(values)
        
        indices = [findfirst(vals, v) for v in values]
        selectedlabs = labs[indices]

        for btn in btns
            signal_handler_block(btn, ids[btn])
            setproperty!(btn, :active, getproperty(btn, :label, String) in selectedlabs)
            signal_handler_unblock(btn, ids[btn])
        end

    end
    lift(handler, widget.signal)

    

    block
end


## select -- a grid
function gtk_widget(widget::Options{:Select})
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
    col = @GtkTreeViewColumn(widget.label, cr, {"text" => 0})
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
        i = Gtk.index_from_iter(store, iter)  ## XX This needs a pull request to be accepted
        push!(widget.signal, vals[i])
    end
    
    ## push! -> update UI
    function handler(val)
        signal_handler_block(selection, id)
        index = findfirst(vals, val)
        iter = Gtk.iter_from_index(store, index)
        Gtk.select!(selection, iter)
        signal_handler_unblock(selection, id)
    end
    lift(handler, widget.signal)

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
    widget.signal = Input(widget)
    widget
end


## Methods to push! a graphic onto canvas
## Would be nice to load these *only* when Winston or Gadfly is loaded
Base.push!(obj::CairoGraphic, pc::Winston.PlotContainer) = Winston.display(obj.obj, pc)

## This is for Gadfly, Compose, GtkInteract -- super slow!!!
if :Gadfly in names(Main)


end
if :Compose in names(Main)
    using Compose, Cairo
    function Base.push!(obj::CairoGraphic, co::Compose.Context)
        ## XXX Must clear old before drawing new XXX
        c = obj.obj
        Gtk.draw(c -> Compose.draw(CAIROSURFACE(c.back),co), c)
    end
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
    widget.signal = Input(widget)
    widget
end

## change text in view
function Base.push!(obj::Textarea, value::String) 
    setproperty!(obj.buffer, :text, value)
    value
end



## Label
function gtk_widget(widget::Label) 
    obj = @GtkLabel(widget.value)
    setproperty!(obj, :selectable, true)
    setproperty!(obj, :use_markup, true)

    widget.obj = obj
    widget.signal = Input(widget)
    widget
end

function Base.push!(obj::Label, value::String) 
    setproperty!(obj.obj, :label, value)
    setproperty!(obj.obj, :use_markup, true)
    obj.value = value
end

## shared or label, textarea
Base.push!{T <: String}(obj::Union(Textarea, Label), value::Vector{T}) = push!(obj, join(value, "\n"))

function Base.push!(obj::Union(Textarea, Label), value)
    push!(obj, sprint(io->writemime(io, "text/plain", value)))
end



## Main window
function init_window(widget::MainWindow)
    if widget.obj != nothing
        return widget
    end

    widget.window = @GtkWindow()
    setproperty!(widget.window, :title, widget.title)
    Gtk.G_.default_size(widget.window, widget.width, widget.height)

    al = @GtkAlignment(0.0, 0.0, 1.0, 1.0)
    for pad in [:right_padding, :top_padding, :left_padding, :bottom_padding]
        setproperty!(al, pad, 5)
    end
    widget.obj = @GtkGrid()
    push!(widget.window, al)

    setproperty!(widget.obj, :row_spacing, 5)
    setproperty!(widget.obj, :column_spacing, 5)
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

Base.append!(parent::MainWindow, items) = map(x -> push!(parent, x), items)
