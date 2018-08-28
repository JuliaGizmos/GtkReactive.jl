### Input widgets

"""
    init_wsigval([T], signal, value; default=nothing) -> signal, value

Return a suitable initial state for `signal` and `value` for a
widget. Any but one of these argument can be `nothing`. A new `signal`
will be created if the input `signal` is `nothing`. Passing in a
pre-existing `signal` will return the same signal, either setting the
signal to `value` (if specified as an input) or extracting and
returning its current value (if the `value` input is `nothing`).

Optionally specify the element type `T`; if `signal` is a
`Reactive.Signal`, then `T` must agree with `eltype(signal)`.
"""
init_wsigval(::Void, ::Void; default=nothing) = _init_wsigval(nothing, default)
init_wsigval(::Void, value; default=nothing) = _init_wsigval(typeof(value), nothing, value)
init_wsigval(signal, value; default=nothing) = _init_wsigval(eltype(signal), signal, value)
init_wsigval{T}(::Type{T}, ::Void, ::Void; default=nothing) =
    _init_wsigval(T, nothing, default)
init_wsigval{T}(::Type{T}, signal, value; default=nothing) =
    _init_wsigval(T, signal, value)

_init_wsigval(::Void, value) = _init_wsigval(typeof(value), nothing, value)
_init_wsigval{T}(::Type{T}, ::Void, ::Void) = error("must supply an initial value")
_init_wsigval{T}(::Type{T}, ::Void, value) = Signal(T, value), value
_init_wsigval{T}(::Type{T}, signal::Signal{T}, ::Void) =
    _init_wsigval(T, signal, value(signal))
function _init_wsigval{T}(::Type{T}, signal::Signal{T}, value)
    push!(signal, value)
    signal, value
end

"""
    init_signal2widget(widget::GtkWidget, id, signal) -> updatesignal
    init_signal2widget(getter, setter, widget::GtkWidget, id, signal) -> updatesignal

Update the "display" value of the Gtk widget `widget` whenever `signal`
changes. `id` is the signal handler id for updating `signal` from the
widget, and is required to prevent the widget from responding to the
update by firing `signal`.

If `updatesignal` is garbage-collected, the widget will no longer
update. Most likely you should either `preserve` or store
`updatesignal`.
"""
function init_signal2widget(getter::Function,
                            setter!::Function,
                            widget::GtkWidget,
                            id, signal)
    map(signal) do val
        signal_handler_block(widget, id)  # prevent "recursive firing" of the handler
        curval = getter(widget)
        curval != val && setter!(widget, val)
        signal_handler_unblock(widget, id)
        nothing
    end
end
init_signal2widget(widget::GtkWidget, id, signal) =
    init_signal2widget(defaultgetter, defaultsetter!, widget, id, signal)

defaultgetter(widget) = Gtk.G_.value(widget)
defaultsetter!(widget,val) = Gtk.G_.value(widget, val)

"""
    ondestroy(widget::GtkWidget, preserved)

Create a `destroy` callback for `widget` that terminates updating dependent signals.
"""
function ondestroy(widget::GtkWidget, preserved::AbstractVector)
    signal_connect(widget, :destroy) do widget
        map(close, preserved)
        empty!(preserved)
        # but it's too dangerous to close signal itself
    end
    nothing
end

########################## Slider ############################

immutable Slider{T<:Number} <: InputWidget{T}
    signal::Signal{T}
    widget::GtkScaleLeaf
    id::Culong
    preserved::Vector

    function (::Type{Slider{T}}){T}(signal::Signal{T}, widget, id, preserved)
        obj = new{T}(signal, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end
Slider{T}(signal::Signal{T}, widget::GtkScaleLeaf, id, preserved) =
    Slider{T}(signal, widget, id, preserved)

# differs from median(r) in that it always returns an element of the range
medianidx(r) = (1+length(r))>>1
medianelement(r::Range) = r[medianidx(r)]

slider(signal::Signal, widget::GtkScaleLeaf, id, preserved = []) =
    Slider(signal, widget, id, preserved)

"""
    slider(range; widget=nothing, value=nothing, signal=nothing, orientation="horizontal")

Create a slider widget with the specified `range`. Optionally provide:
  - the GtkScale `widget` (by default, creates a new one)
  - the starting `value` (defaults to the median of `range`)
  - the (Reactive.jl) `signal` coupled to this slider (by default, creates a new signal)
  - the `orientation` of the slider.
"""
function slider{T}(range::Range{T};
                   widget=nothing,
                   value=nothing,
                   signal=nothing,
                   orientation="horizontal",
                   syncsig=true,
                   own=nothing)
    signalin = signal
    signal, value = init_wsigval(T, signal, value; default=medianelement(range))
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkScale(lowercase(first(orientation)) == 'v',
                          first(range), last(range), step(range))
        Gtk.G_.size_request(widget, 200, -1)
    else
        adj = Gtk.Adjustment(widget)
        Gtk.G_.lower(adj, first(range))
        Gtk.G_.upper(adj, last(range))
        Gtk.G_.step_increment(adj, step(range))
    end
    Gtk.G_.value(widget, value)

    ## widget -> signal
    id = signal_connect(widget, :value_changed) do w
        push!(signal, defaultgetter(w))
    end

    ## signal -> widget
    preserved = []
    if syncsig
        push!(preserved, init_signal2widget(widget, id, signal))
    end
    if own
        ondestroy(widget, preserved)
    end

    Slider(signal, widget, id, preserved)
end

# Adjust the range on a slider
# Is calling this `push!` too much of a pun?
function Base.push!(s::Slider, range::Range, value=value(s))
    first(range) <= value <= last(range) || error("$value is not within the span of $range")
    adj = Gtk.Adjustment(widget(s))
    Gtk.G_.lower(adj, first(range))
    Gtk.G_.upper(adj, last(range))
    Gtk.G_.step_increment(adj, step(range))
    Gtk.G_.value(widget(s), value)
end

######################### Checkbox ###########################

immutable Checkbox <: InputWidget{Bool}
    signal::Signal{Bool}
    widget::GtkCheckButtonLeaf
    id::Culong
    preserved::Vector

    function (::Type{Checkbox})(signal::Signal{Bool}, widget, id, preserved)
        obj = new(signal, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

checkbox(signal::Signal, widget::GtkCheckButtonLeaf, id, preserved=[]) =
    Checkbox(signal, widget, id, preserved)

"""
    checkbox(value=false; widget=nothing, signal=nothing, label="")

Provide a checkbox with the specified starting (boolean)
`value`. Optionally provide:
  - a GtkCheckButton `widget` (by default, creates a new one)
  - the (Reactive.jl) `signal` coupled to this checkbox (by default, creates a new signal)
  - a display `label` for this widget
"""
function checkbox(value::Bool; widget=nothing, signal=nothing, label="", own=nothing)
    signalin = signal
    signal, value = init_wsigval(signal, value)
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkCheckButton(label)
    end
    Gtk.G_.active(widget, value)

    id = signal_connect(widget, :clicked) do w
        push!(signal, Gtk.G_.active(w))
    end
    preserved = []
    push!(preserved, init_signal2widget(w->Gtk.G_.active(w),
                                        (w,val)->Gtk.G_.active(w, val),
                                        widget, id, signal))
    if own
        ondestroy(widget, preserved)
    end

    Checkbox(signal, widget, id, preserved)
end
checkbox(; value=false, widget=nothing, signal=nothing, label="", own=nothing) =
    checkbox(value; widget=widget, signal=signal, label=label, own=own)

###################### ToggleButton ########################

immutable ToggleButton <: InputWidget{Bool}
    signal::Signal{Bool}
    widget::GtkToggleButtonLeaf
    id::Culong
    preserved::Vector

    function (::Type{ToggleButton})(signal::Signal{Bool}, widget, id, preserved)
        obj = new(signal, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

togglebutton(signal::Signal, widget::GtkToggleButtonLeaf, id, preserved=[]) =
    ToggleButton(signal, widget, id, preserved)

"""
    togglebutton(value=false; widget=nothing, signal=nothing, label="")

Provide a togglebutton with the specified starting (boolean)
`value`. Optionally provide:
  - a GtkCheckButton `widget` (by default, creates a new one)
  - the (Reactive.jl) `signal` coupled to this button (by default, creates a new signal)
  - a display `label` for this widget
"""
function togglebutton(value::Bool; widget=nothing, signal=nothing, label="", own=nothing)
    signalin = signal
    signal, value = init_wsigval(signal, value)
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkToggleButton(label)
    end
    Gtk.G_.active(widget, value)

    id = signal_connect(widget, :clicked) do w
        push!(signal, Gtk.G_.active(w))
    end
    preserved = []
    push!(preserved, init_signal2widget(w->Gtk.G_.active(w),
                                        (w,val)->Gtk.G_.active(w, val),
                                        widget, id, signal))
    if own
        ondestroy(widget, preserved)
    end

    ToggleButton(signal, widget, id, preserved)
end
togglebutton(; value=false, widget=nothing, signal=nothing, label="", own=nothing) =
    togglebutton(value; widget=widget, signal=signal, label=label, own=own)

######################### Button ###########################

immutable Button <: InputWidget{Void}
    signal::Signal{Void}
    widget::Union{GtkButtonLeaf,GtkToolButtonLeaf}
    id::Culong

    function (::Type{Button})(signal::Signal{Void}, widget, id)
        obj = new(signal, widget, id)
        gc_preserve(widget, obj)
        obj
    end
end

button(signal::Signal, widget::Union{GtkButtonLeaf,GtkToolButtonLeaf}, id) =
    Button(signal, widget, id)

"""
    button(label; widget=nothing, signal=nothing)
    button(; label=nothing, widget=nothing, signal=nothing)

Create a push button with text-label `label`. Optionally provide:
  - a GtkButton `widget` (by default, creates a new one)
  - the (Reactive.jl) `signal` coupled to this button (by default, creates a new signal)
"""
function button(;
                label::Union{Void,String,Symbol}=nothing,
                widget=nothing,
                signal=nothing,
                own=nothing)
    signalin = signal
    if signal == nothing
        signal = Signal(nothing)
    end
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkButton(label)
    end

    id = signal_connect(widget, :clicked) do w
        push!(signal, nothing)
    end

    Button(signal, widget, id)
end
button(label::Union{String,Symbol}; widget=nothing, signal=nothing, own=nothing) =
    button(; label=label, widget=widget, signal=signal, own=own)

######################## Textbox ###########################

immutable Textbox{T} <: InputWidget{T}
    signal::Signal{T}
    widget::GtkEntryLeaf
    id::Culong
    preserved::Vector{Any}
    range

    function (::Type{Textbox{T}}){T}(signal::Signal{T}, widget, id, preserved, range)
        obj = new{T}(signal, widget, id, preserved, range)
        gc_preserve(widget, obj)
        obj
    end
end
Textbox{T}(signal::Signal{T}, widget::GtkEntryLeaf, id, preserved, range) =
    Textbox{T}(signal, widget, id, preserved, range)

textbox(signal::Signal, widget::GtkButtonLeaf, id, preserved = []) =
    Textbox(signal, widget, id, preserved)

"""
    textbox(value=""; widget=nothing, signal=nothing, range=nothing, gtksignal=:activate)
    textbox(T::Type; widget=nothing, signal=nothing, range=nothing, gtksignal=:activate)

Create a box for entering text. `value` is the starting value; if you
don't want to provide an initial value, you can constrain the type
with `T`. Optionally specify the allowed range (e.g., `-10:10`)
for numeric entries, and/or provide the (Reactive.jl) `signal` coupled
to this text box. Finally, you can specify which Gtk signal (e.g.
`activate`, `changed`) you'd like the widget to update with.
"""
function textbox{T}(::Type{T};
                    widget=nothing,
                    value=nothing,
                    range=nothing,
                    signal=nothing,
                    syncsig=true,
                    own=nothing,
                    gtksignal=:activate)
    if T <: AbstractString && range != nothing
        throw(ArgumentError("You cannot set a range on a string textbox"))
    end
    signalin = signal
    signal, value = init_wsigval(T, signal, value; default="")
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkEntry()
    end
    setproperty!(widget, :text, value)

    id = signal_connect(widget, gtksignal) do w
        push!(signal, entrygetter(w, signal, range))
    end

    preserved = []
    function checked_entrysetter!(w, val)
        val ∈ range || throw(ArgumentError("$val is not within $range"))
        entrysetter!(w, val)
    end
    if syncsig
        push!(preserved, init_signal2widget(w->entrygetter(w, signal, range),
                                            range == nothing ? entrysetter! : checked_entrysetter!,
                                            widget, id, signal))
    end
    own && ondestroy(widget, preserved)

    Textbox(signal, widget, id, preserved, range)
end
function textbox{T}(value::T;
                    widget=nothing,
                    range=nothing,
                    signal=nothing,
                    syncsig=true,
                    own=nothing,
                    gtksignal=:activate)
    textbox(T; widget=widget, value=value, range=range, signal=signal, syncsig=syncsig, own=own, gtksignal=gtksignal)
end

entrygetter{T<:AbstractString}(w, signal::Signal{T}, ::Void) =
    getproperty(w, :text, String)
function entrygetter{T}(w, signal::Signal{T}, range)
    val = tryparse(T, getproperty(w, :text, String))
    if isnull(val)
        nval = value(signal)
        # Invalid entry, restore the old value
        entrysetter!(w, nval)
    else
        nv = get(val)
        nval = nearest(nv, range)
        if nv != nval
            entrysetter!(w, nval)
        end
    end
    nval
end
nearest(val, ::Void) = val
function nearest(val, r::Range)
    i = round(Int, (val - first(r))/step(r)) + 1
    r[clamp(i, 1, length(r))]
end

entrysetter!(w, val) = setproperty!(w, :text, string(val))


######################### Textarea ###########################

immutable Textarea <: InputWidget{String}
    signal::Signal{String}
    widget::GtkTextView
    id::Culong
    preserved::Vector

    function (::Type{Textarea})(signal::Signal{String}, widget, id, preserved)
        obj = new(signal, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

"""
    textarea(value=""; widget=nothing, signal=nothing)

Creates an extended text-entry area. Optionally provide a GtkTextView `widget`
and/or the (Reactive.jl) `signal` associated with this widget. The
`signal` updates when you type.
"""
function textarea(value::String="";
                  widget=nothing,
                  signal=nothing,
                  syncsig=true,
                  own=nothing)
    signalin = signal
    signal, value = init_wsigval(signal, value)
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkTextView()
    end
    buf = Gtk.G_.buffer(widget)
    setproperty!(buf, :text, value)

    id = signal_connect(buf, :changed) do w
        push!(signal, getproperty(w, :text, String))
    end

    preserved = []
    if syncsig
        # GtkTextBuffer is not a GtkWdiget, so we have to do this manually
        push!(preserved, map(signal) do val
                  signal_handler_block(buf, id)
                  curval = getproperty(buf, :text, String)
                  curval != val && setproperty!(buf, :text, val)
                  signal_handler_unblock(buf, id)
                  nothing
              end)
    end
    own && ondestroy(widget, preserved)

    Textarea(signal, widget, id, preserved)
end

##################### SelectionWidgets ######################

immutable Dropdown <: InputWidget{String}
    signal::Signal{String}
    mappedsignal::Signal
    widget::GtkComboBoxTextLeaf
    id::Culong
    preserved::Vector

    function (::Type{Dropdown})(signal::Signal{String}, mappedsignal::Signal, widget, id, preserved)
        obj = new(signal, mappedsignal, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

"""
    dropdown(choices; widget=nothing, value=first(choices), signal=nothing, label="", with_entry=true, icons, tooltips)

Create a "dropdown" widget. `choices` can be a vector (or other iterable) of
options. Optionally specify
  - the GtkComboBoxText `widget` (by default, creates a new one)
  - the starting `value`
  - the (Reactive.jl) `signal` coupled to this slider (by default, creates a new signal)
  - whether the widget should allow text entry

# Examples

    a = dropdown(["one", "two", "three"])

To link a callback to the dropdown, use

    f = dropdown(("turn red"=>colorize_red, "turn green"=>colorize_green))
    map(g->g(image), f.mappedsignal)
"""
function dropdown(; choices=nothing,
                  widget=nothing,
                  value=juststring(first(choices)),
                  signal=nothing,
                  label="",
                  with_entry=true,
                  icons=nothing,
                  tooltips=nothing,
                  own=nothing)
    signalin = signal
    signal, value = init_wsigval(String, signal, value)
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkComboBoxText()
    end
    if choices != nothing
        empty!(widget)
    else
        error("Pre-loading the widget is not yet supported")
    end
    allstrings = all(x->isa(x, AbstractString), choices)
    allstrings || all(x->isa(x, Pair), choices) || throw(ArgumentError("all elements must either be strings or pairs, got $choices"))
    str2int = Dict{String,Int}()
    int2str = Dict{Int,String}()
    getactive(w) = int2str[getproperty(w, :active, Int)]
    setactive!(w, val) = setproperty!(widget, :active, str2int[val])
    k = -1
    for c in choices
        str = juststring(c)
        push!(widget, str)
        str2int[str] = (k+=1)
        int2str[k] = str
    end
    if value == nothing
        value = juststring(first(choices))
    end
    setactive!(widget, value)

    id = signal_connect(widget, :changed) do w
        push!(signal, getactive(w))
    end

    preserved = []
    push!(preserved, init_signal2widget(getactive, setactive!, widget, id, signal))
    if !allstrings
        choicedict = Dict(choices...)
        mappedsignal = map(val->choicedict[val], signal; typ=Any)
    else
        mappedsignal = Signal(nothing)
    end
    if own
        ondestroy(widget, preserved)
    end

    Dropdown(signal, mappedsignal, widget, id, preserved)
end

function dropdown(choices; kwargs...)
    dropdown(; choices=choices, kwargs...)
end

juststring(str::AbstractString) = String(str)
juststring(p::Pair{String}) = p.first
pairaction(str::AbstractString) = x->nothing
pairaction{F<:Function}(p::Pair{String,F}) = p.second


# """
# radiobuttons: see the help for `dropdown`
# """
# radiobuttons(opts; kwargs...) =
#     Options(:RadioButtons, opts; kwargs...)

# """
# selection: see the help for `dropdown`
# """
# function selection(opts; multi=false, kwargs...)
#     if multi
#         options = getoptions(opts)
#         #signal needs to be of an array of values, not just a single value
#         signal = Signal(collect(values(options))[1:1])
#         Options(:SelectMultiple, options; signal=signal, kwargs...)
#     else
#         Options(:Select, opts; kwargs...)
#     end
# end

# Base.@deprecate select(opts; kwargs...) selection(opts, kwargs...)

# """
# togglebuttons: see the help for `dropdown`
# """
# togglebuttons(opts; kwargs...) =
#     Options(:ToggleButtons, opts; kwargs...)

# """
# selection_slider: see the help for `dropdown`
# If the slider has numeric (<:Real) values, and its signal is updated, it will
# update to the nearest value from the range/choices provided. To disable this
# behaviour, so that the widget state will only update if an exact match for
# signal value is found in the range/choice, use `syncnearest=false`.
# """
# selection_slider(opts; kwargs...) = begin
#     if !haskey(Dict(kwargs), :value_label)
#         #default to middle of slider
#         mid_idx = medianidx(opts)
#         push!(kwargs, (:sel_mid_idx, mid_idx))
#     end
#     Options(:SelectionSlider, opts; kwargs...)
# end

# """
# `vselection_slider(args...; kwargs...)`

# Shorthand for `selection_slider(args...; orientation="vertical", kwargs...)`
# """
# vselection_slider(args...; kwargs...) = selection_slider(args...; orientation="vertical", kwargs...)

# function nearest_val(x, val)
#     local valbest
#     local dxbest = typemax(Float64)
#     for v in x
#         dx = abs(v-val)
#         if dx < dxbest
#             dxbest = dx
#             valbest = v
#         end
#     end
#     valbest
# end


### Output Widgets

######################## Label #############################

immutable Label <: Widget
    signal::Signal{String}
    widget::GtkLabel
    preserved::Vector{Any}

    function (::Type{Label})(signal::Signal{String}, widget, preserved)
        obj = new(signal, widget, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

"""
    label(value; widget=nothing, signal=nothing)

Create a text label displaying `value` as a string; new values may
displayed by pushing to the widget. Optionally specify
  - the GtkLabel `widget` (by default, creates a new one)
  - the (Reactive.jl) `signal` coupled to this label (by default, creates a new signal)
"""
function label(value;
               widget=nothing,
               signal=nothing,
               syncsig=true,
               own=nothing)
    signalin = signal
    signal, value = init_wsigval(String, signal, value)
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkLabel(value)
    else
        setproperty!(widget, :label, value)
    end
    preserved = []
    if syncsig
        push!(preserved, map(signal) do val
            setproperty!(widget, :label, val)
        end)
    end
    if own
        ondestroy(widget, preserved)
    end
    Label(signal, widget, preserved)
end

# export Latex, Progress

# Base.@deprecate html(value; label="")  HTML(value)

# type Latex <: Widget
#     label::AbstractString
#     value::AbstractString
# end
# latex(label, value::AbstractString) = Latex(label, value)
# latex(value::AbstractString; label="") = Latex(label, value)
# latex(value; label="") = Latex(label, mimewritable("application/x-latex", value) ? stringmime("application/x-latex", value) : stringmime("text/latex", value))

# ## # assume we already have Latex
# ## writemime(io::IO, m::MIME{symbol("application/x-latex")}, l::Latex) =
# ##     write(io, l.value)

# type Progress <: Widget
#     label::AbstractString
#     value::Int
#     range::Range
#     orientation::String
#     readout::Bool
#     readout_format::String
#     continuous_update::Bool
# end

# progress(args...) = Progress(args...)
# progress(;label="", value=0, range=0:100, orientation="horizontal",
#             readout=true, readout_format="d", continuous_update=true) =
#     Progress(label, value, range, orientation, readout, readout_format, continuous_update)

# # Make a widget out of a domain
# widget(x::Signal, label="") = x
# widget(x::Widget, label="") = x
# widget(x::Range, label="") = selection_slider(x, label=label)
# widget(x::AbstractVector, label="") = togglebuttons(x, label=label)
# widget(x::Associative, label="") = togglebuttons(x, label=label)
# widget(x::Bool, label="") = checkbox(x, label=label)
# widget(x::AbstractString, label="") = textbox(x, label=label, typ=AbstractString)
# widget{T <: Number}(x::T, label="") = textbox(typ=T, value=x, label=label)

# ### Set!

# """
# `set!(w::Widget, fld::Symbol, val)`

# Set the value of a widget property and update all displayed instances of the
# widget. If `val` is a `Signal`, then updates to that signal will be reflected in
# widget instances/views.

# If `fld` is `:value`, `val` is also `push!`ed to `signal(w)`
# """
# function set!(w::Widget, fld::Symbol, val)
#     fld == :value && val != signal(w).value && push!(signal(w), val)
#     setfield!(w, fld, val)
#     update_view(w)
#     w
# end

# set!(w::Widget, fld::Symbol, valsig::Signal) = begin
#     map(val -> set!(w, fld, val), valsig) |> preserve
# end

# set!{T<:Options}(w::T, fld::Symbol, val::Union{Signal,Any}) = begin
#     fld == :options && (val = getoptions(val))
#     invoke(set!, (Widget, Symbol, typeof(val)), w, fld, val)
# end

########################## SpinButton ########################

immutable SpinButton{T<:Number} <: InputWidget{T}
    signal::Signal{T}
    widget::GtkSpinButtonLeaf
    id::Culong
    preserved::Vector

    function (::Type{SpinButton{T}}){T}(signal::Signal{T}, widget, id, preserved)
        obj = new{T}(signal, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end
SpinButton{T}(signal::Signal{T}, widget::GtkSpinButtonLeaf, id, preserved) =
    SpinButton{T}(signal, widget, id, preserved)

spinbutton(signal::Signal, widget::GtkSpinButtonLeaf, id, preserved = []) =
    SpinButton(signal, widget, id, preserved)

"""
    spinbutton(range; widget=nothing, value=nothing, signal=nothing, orientation="horizontal")

Create a spinbutton widget with the specified `range`. Optionally provide:
  - the GtkSpinButton `widget` (by default, creates a new one)
  - the starting `value` (defaults to the start of `range`)
  - the (Reactive.jl) `signal` coupled to this spinbutton (by default, creates a new signal)
  - the `orientation` of the spinbutton.
"""
function spinbutton{T}(range::Range{T};
                       widget=nothing,
                       value=nothing,
                       signal=nothing,
                       orientation="horizontal",
                       syncsig=true,
                       own=nothing)
    signalin = signal
    signal, value = init_wsigval(T, signal, value; default=range.start)
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkSpinButton(
                          first(range), last(range), step(range))
        Gtk.G_.size_request(widget, 200, -1)
    else
        adj = Gtk.Adjustment(widget)
        Gtk.G_.lower(adj, first(range))
        Gtk.G_.upper(adj, last(range))
        Gtk.G_.step_increment(adj, step(range))
    end
    if lowercase(first(orientation)) == 'v'
        Gtk.G_.orientation(Gtk.GtkOrientable(widget),
                           Gtk.GConstants.GtkOrientation.VERTICAL)
    end
    Gtk.G_.value(widget, value)

    ## widget -> signal
    id = signal_connect(widget, :value_changed) do w
        push!(signal, defaultgetter(w))
    end

    ## signal -> widget
    preserved = []
    if syncsig
        push!(preserved, init_signal2widget(widget, id, signal))
    end
    if own
        ondestroy(widget, preserved)
    end

    SpinButton(signal, widget, id, preserved)
end

# Adjust the range on a spinbutton
# Is calling this `push!` too much of a pun?
function Base.push!(s::SpinButton, range::Range, value=value(s))
    first(range) <= value <= last(range) || error("$value is not within the span of $range")
    adj = Gtk.Adjustment(widget(s))
    Gtk.G_.lower(adj, first(range))
    Gtk.G_.upper(adj, last(range))
    Gtk.G_.step_increment(adj, step(range))
    Gtk.G_.value(widget(s), value)
end

########################## CyclicSpinButton ########################

immutable CyclicSpinButton{T<:Number} <: InputWidget{T}
    signal::Signal{T}
    widget::GtkSpinButtonLeaf
    id::Culong
    preserved::Vector

    function (::Type{CyclicSpinButton{T}}){T}(signal::Signal{T}, widget, id, preserved)
        obj = new{T}(signal, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end
CyclicSpinButton{T}(signal::Signal{T}, widget::GtkSpinButtonLeaf, id, preserved) =
    CyclicSpinButton{T}(signal, widget, id, preserved)

cyclicspinbutton(signal::Signal, widget::GtkSpinButtonLeaf, id, preserved = []) =
    CyclicSpinButton(signal, widget, id, preserved)

"""
    cyclicspinbutton(range, carry_up; widget=nothing, value=nothing, signal=nothing, orientation="horizontal")

Create a cyclicspinbutton widget with the specified `range` that updates a `carry_up::Signal{Bool}`
only when a value outside the `range` of the cyclicspinbutton is pushed. `carry_up`
is updated with `true` when the cyclicspinbutton is updated with a value that is
higher than the maximum of the range. When cyclicspinbutton is updated with a value that is smaller
than the minimum of the range `carry_up` is updated with `false`. Optional arguments are:
  - the GtkSpinButton `widget` (by default, creates a new one)
  - the starting `value` (defaults to the start of `range`)
  - the (Reactive.jl) `signal` coupled to this cyclicspinbutton (by default, creates a new signal)
  - the `orientation` of the cyclicspinbutton.
"""
function cyclicspinbutton{T}(range::Range{T}, carry_up::Signal{Bool};
                       widget=nothing,
                       value=nothing,
                       signal=nothing,
                       orientation="horizontal",
                       syncsig=true,
                       own=nothing)
    signalin = signal
    signal, value = init_wsigval(T, signal, value; default=range.start)
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkSpinButton(first(range) - step(range), last(range) + step(range), step(range))
        Gtk.G_.size_request(widget, 200, -1)
    else
        adj = Gtk.Adjustment(widget)
        Gtk.G_.lower(adj, first(range) - step(range))
        Gtk.G_.upper(adj, last(range) + step(range))
        Gtk.G_.step_increment(adj, step(range))
    end
    if lowercase(first(orientation)) == 'v'
        Gtk.G_.orientation(Gtk.GtkOrientable(widget),
                           Gtk.GConstants.GtkOrientation.VERTICAL)
    end
    Gtk.G_.value(widget, value)

    ## widget -> signal
    id = signal_connect(widget, :value_changed) do w
        push!(signal, defaultgetter(w))
    end

    ## signal -> widget
    preserved = []
    if syncsig
        push!(preserved, init_signal2widget(widget, id, signal))
    end
    if own
        ondestroy(widget, preserved)
    end

    up = filter(x -> x > last(range), value, signal)
    foreach(up; init=nothing) do _
        push!(signal, first(range))
        push!(carry_up, true)
    end
    down = filter(x -> x < first(range), value, signal)
    foreach(down; init=nothing) do _
        push!(signal, last(range))
        push!(carry_up, false)
    end
    push!(signal, value)

    CyclicSpinButton(signal, widget, id, preserved)
end

######################## ProgressBar #########################

immutable ProgressBar{T <: Number} <: Widget
    signal::Signal{T}
    widget::GtkProgressBarLeaf
    preserved::Vector{Any}

    function (::Type{ProgressBar{T}}){T}(signal::Signal{T}, widget, preserved)
        obj = new{T}(signal, widget, preserved)
        gc_preserve(widget, obj)
        obj
    end
end
ProgressBar{T}(signal::Signal{T}, widget::GtkProgressBarLeaf, preserved) =
    ProgressBar{T}(signal, widget, preserved)

# convert a member of the interval into a decimal
interval2fraction(x::AbstractInterval, i) = (i - minimum(x))/IntervalSets.width(x)

"""
    progressbar(interval::AbstractInterval; widget=nothing, signal=nothing)

Create a progressbar displaying the current state in the given interval; new iterations may be
displayed by pushing to the widget. Optionally specify
  - the GtkProgressBar `widget` (by default, creates a new one)
  - the (Reactive.jl) `signal` coupled to this progressbar (by default, creates a new signal)

# Examples

```julia-repl
julia> using GtkReactive

julia> using IntervalSets

julia> n = 10

julia> pb = progressbar(1..n)
Gtk.GtkProgressBarLeaf with 1: "input" = 1 Int64

julia> for i = 1:n
           # do something
           push!(pb, i)
       end

```
"""
function progressbar(interval::AbstractInterval{T};
               widget=nothing,
               signal=nothing,
               syncsig=true,
               own=nothing) where T<:Number
    value = minimum(interval)
    signalin = signal
    signal, value = init_wsigval(T, signal, value)
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = GtkProgressBar()
    else
        setproperty!(widget, :fraction, interval2fraction(interval, value))
    end
    preserved = []
    if syncsig
        push!(preserved, map(signal) do val
            setproperty!(widget, :fraction, interval2fraction(interval, val))
        end)
    end
    if own
        ondestroy(widget, preserved)
    end
    ProgressBar(signal, widget, preserved)
end

progressbar(range::Range; args...) = progressbar(ClosedInterval(range), args...)
