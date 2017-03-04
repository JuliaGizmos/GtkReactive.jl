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
    _init_wsigval(T, signal, signal.value)
function _init_wsigval{T}(::Type{T}, signal::Signal{T}, value)
    push!(signal, value)
    signal, value
end

"""
    init_signal2widget(obj::GtkWidget, id, signal) -> updatesignal
    init_signal2widget(getter, setter, obj::GtkWidget, id, signal) -> updatesignal

Update the "display" value of the Gtk widget `obj` whenever `signal`
changes. `id` is the signal handler id for updating `signal` from the
widget, and is required to prevent the widget from responding to the
update by firing `signal`.

If `updatesignal` is garbage-collected, the widget will no longer
update. Most likely you should either `preserve` or store
`updatesignal`.
"""
function init_signal2widget(getter::Function,
                            setter!::Function,
                            obj::GtkWidget,
                            id, signal)
    map(signal) do val
        signal_handler_block(obj, id)  # prevent "recursive firing" of the handler
        curval = getter(obj)
        curval != val && setter!(obj, val)
        signal_handler_unblock(obj, id)
        nothing
    end
end
init_signal2widget(obj::GtkWidget, id, signal) =
    init_signal2widget(defaultgetter, defaultsetter!, obj, id, signal)

defaultgetter(obj) = Gtk.G_.value(obj)
defaultsetter!(obj,val) = Gtk.G_.value(obj, val)

"""
    ondestroy(obj::GtkWidget, preserved)

Create a `destroy` callback for `obj` that terminates updating dependent signals.
"""
function ondestroy(obj::GtkWidget, preserved::AbstractVector)
    signal_connect(obj, :destroy) do widget
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
    preserved::Vector{Any}
end

# differs from median(r) in that it always returns an element of the range
medianidx(r) = (1+length(r))>>1
medianelement(r::Range) = r[medianidx(r)]

slider(signal::Signal, widget::GtkScaleLeaf, id, preserved = []) =
    Slider(signal, widget, id, preserved)

"""
    slider(range; value=nothing, signal=nothing, orientation="horizontal")

Create a slider widget with the specified `range`. Optionally specify
the starting `value` (defaults to the median of `range`), provide the
(Reactive.jl) `signal` coupled to this slider, and/or specify the
orientation of the slider.
"""
function slider{T}(range::Range{T};
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
    obj = GtkScale(lowercase(first(orientation)) == 'v',
                   first(range), last(range), step(range))
    Gtk.G_.size_request(obj, 200, -1)
    Gtk.G_.value(obj, value)

    ## widget -> signal
    id = signal_connect(obj, :value_changed) do w
        push!(signal, defaultgetter(w))
    end

    ## signal -> widget
    preserved = []
    if syncsig
        push!(preserved, init_signal2widget(obj, id, signal))
    end
    if own
        ondestroy(obj, preserved)
    end

    Slider(signal, obj, id, preserved)
end

# ######################### Checkbox ###########################

# type Checkbox <: InputWidget{Bool}
#     signal::Signal{Bool}
#     label::AbstractString
#     value::Bool
# end

# checkbox(args...) = Checkbox(args...)

# """
#     checkbox(value=false; label="", signal)

# Provide a checkbox with the specified starting (boolean)
# `value`. Optional provide a `label` for this widget and/or the
# (Reactive.jl) `signal` coupled to this widget.
# """
# checkbox(value::Bool; signal=nothing, label="") = begin
#     signal, value = init_wsigval(signal, value)
#     Checkbox(signal, label, value)
# end
# checkbox(; label="", value=nothing, signal=nothing) = begin
#     signal, value = init_wsigval(signal, value; default=false)
#     Checkbox(signal, label, value)
# end
# ###################### ToggleButton ########################

# type ToggleButton <: InputWidget{Bool}
#     signal::Signal{Bool}
#     label::AbstractString
#     value::Bool
# end

# togglebutton(args...) = ToggleButton(args...)

# togglebutton(; label="", value=nothing, signal=nothing) = begin
#     signal, value = init_wsigval(signal, value; default=false)
#     ToggleButton(signal, label, value)
# end

# """
#     togglebutton(label=""; value=false, signal)

# Create a toggle button. Optionally specify the `label`, the initial
# state (`value=false` is off, `value=true` is on), and/or provide the
# (Reactive.jl) `signal` coupled to this button.
# """
# togglebutton(label; kwargs...) =
#     togglebutton(label=label; kwargs...)

######################### Button ###########################

type Button{T} <: InputWidget{T}
    signal::Signal{T}
    widget::GtkButtonLeaf
    id::Culong
end

button(signal::Signal, widget::GtkButtonLeaf, id) =
    Button(signal, widget, id)

"""
    button(label; signal=nothing)

Create a push button with text-label `label`. Optionally specify the
(Reactive.jl) `signal` coupled to this button.
"""
function button(label::Union{String,Symbol};
                signal=nothing,
                own=nothing)
    signalin = signal
    if signal == nothing
        signal = Signal(nothing)
    end
    if own == nothing
        own = signal != signalin
    end
    obj = GtkButton(label)

    id = signal_connect(obj, :clicked) do w
        push!(signal, nothing)
    end

    Button(signal, obj, id)
end

# ######################## Textbox ###########################

type Textbox{T} <: InputWidget{T}
    signal::Signal{T}
    widget::GtkEntryLeaf
    id::Culong
    preserved::Vector{Any}
    range
end

textbox(signal::Signal, widget::GtkButtonLeaf, id, preserved = []) =
    Textbox(signal, widget, id, preserved)

"""
    textbox(value=""; range=nothing, signal=nothing)
    textbox(T::Type; range=nothing, signal=nothing)

Create a box for entering text. `value` is the starting value; if you
don't want to provide an initial value, you can constrain the type
with `T`. Optionally specify the allowed range (e.g., `-10:10`)
for numeric entries, and/or provide the (Reactive.jl) `signal` coupled
to this text box.
"""
function textbox{T}(::Type{T};
                    value=nothing,
                    range=nothing,
                    signal=nothing,
                    syncsig=true,
                    own=nothing)
    if T <: AbstractString && range != nothing
        throw(ArgumentError("You cannot set a range on a string textbox"))
    end
    signalin = signal
    signal, value = init_wsigval(T, signal, value; default="")
    if own == nothing
        own = signal != signalin
    end
    obj = GtkEntry()
    setproperty!(obj, :text, value)

    id = signal_connect(obj, :activate) do w
        push!(signal, entrygetter(w, signal, range))
    end

    preserved = []
    if syncsig
        push!(preserved, init_signal2widget(w->entrygetter(w, signal, range),
                                            entrysetter!,
                                            obj, id, signal))
    end
    own && ondestroy(obj, preserved)

    Textbox(signal, obj, id, preserved, range)
end
function textbox{T}(value::T;
                    range=nothing,
                    signal=nothing,
                    syncsig=true,
                    own=nothing)
    textbox(T; value=value, range=range, signal=signal, syncsig=syncsig, own=own)
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

# textbox(;kwargs...) = Textbox(;kwargs...)

# textbox(val; kwargs...) =
#     Textbox(value=val; kwargs...)
# textbox(val::String; kwargs...) =
#     Textbox(value=val; kwargs...)

# parse_msg{T<:Number}(w::Textbox{T}, val::AbstractString) = parse_msg(w, parse(T, val))
# function parse_msg{T<:Number}(w::Textbox{T}, val::Number)
#     v = convert(T, val)
#     if isa(w.range, Range)
#         # force value to stay in range
#         v = max(first(w.range),
#                 min(last(w.range), v))
#     end
#     v
# end

# ######################### Textarea ###########################

# type Textarea{AbstractString} <: InputWidget{AbstractString}
#     signal::Signal{AbstractString}
#     label::AbstractString
#     value::AbstractString
# end

# textarea(args...) = Textarea(args...)

# textarea(; label="",
#          value=nothing,
#          signal=nothing) = begin
#     signal, value = init_wsigval(signal, value; default="")
#     Textarea(signal, label, value)
# end

# """
#     textarea(value=""; label="", signal)

# Creates an extended text-entry area. Optionally provide a `label`
# and/or the (Reactive.jl) `signal` associated with this widget. The
# `signal` updates when you type.
# """
# textarea(val; kwargs...) =
#     textarea(value=val; kwargs...)

# ##################### SelectionWidgets ######################

# immutable OptionDict
#     dict::OrderedDict
#     invdict::Dict
# end
# OptionDict(d::OrderedDict) = begin
#     T1 = eltype([keys(d)...])
#     T2 = eltype([values(d)...])
#     OptionDict(OrderedDict{T1,T2}(d), Dict{T2,T1}(zip(values(d), keys(d))))
# end

# Base.getindex(x::OptionDict, y) = getindex(x.dict, y)
# Base.haskey(x::OptionDict, y) = haskey(x.dict, y)
# Base.keys(x::OptionDict) = keys(x.dict)
# Base.values(x::OptionDict) = values(x.dict)
# Base.length(x::OptionDict) = length(keys(x))

# type Options{view, T} <: InputWidget{T}
#     signal::Signal
#     label::AbstractString
#     value::T
#     value_label::AbstractString
#     options::OptionDict
#     icons::AbstractArray
#     tooltips::AbstractArray
#     readout::Bool
#     orientation::AbstractString
# end

# Options(view::Symbol, options::OptionDict;
#         label = "",
#         value_label=first(keys(options)),
#         value=nothing,
#         icons=[],
#         tooltips=[],
#         typ=valtype(options.dict),
#         signal=nothing,
#         readout=true,
#         orientation="horizontal",
#         syncsig=true,
#         syncnearest=true,
#         sel_mid_idx=0) = begin
#     #sel_mid_idx set in selection_slider(...) so default value_label is middle of range
#     sel_mid_idx != 0 && (value_label = collect(keys(options.dict))[sel_mid_idx])
#     signal, value = init_wsigval(signal, value; typ=typ, default=options[value_label])
#     typ = eltype(signal)
#     ow = Options{view, typ}(signal, label, value, value_label,
#                     options, icons, tooltips, readout, orientation)
#     if syncsig
#         syncselnearest = view == :SelectionSlider && typ <: Real && syncnearest
#         if view != :SelectMultiple
#             #set up map that keeps the value_label in sync with the value
#             #TODO handle SelectMultiple. Need something similar to handle_msg,
#             #note also ow.value_label is an AbstractString whereas for SelectMultiple
#             #it should be a Vector{AbstractString} so would want to have Tvalue and
#             #Tlabel type parameters. Also would need to set w.value_label in handle_msg
#             #to avoid multiple updating
#             keep_label_updated(val) = begin
#                 if syncselnearest
#                     val = nearest_val(keys(ow.options.invdict), val)
#                 end
#                 if haskey(ow.options.invdict, val) &&
#                   ow.value_label != ow.options.invdict[val]
#                     ow.value_label = ow.options.invdict[val]
#                     update_view(ow)
#                 end
#                 nothing
#             end
#             preserve(map(keep_label_updated, signal; typ=Void))
#         end
#         push!(signal, value)
#     end
#     ow
# end

# function Options(view::Symbol,
#                     options::Union{Associative, AbstractArray};
#                     kwargs...)
#     Options(view, getoptions(options); kwargs...)
# end

# function getoptions(options)
#     opts = OrderedDict()
#     for el in options
#         addoption!(opts, el)
#     end
#     optdict = OptionDict(opts)
# end

# addoption!(opts, v::Union{Pair, NTuple{2}}) = opts[string(v[1])] = v[2]
# addoption!(opts, v) = opts[string(v)] = v

# """
#     dropdown(choices; label="", value, typ, icons, tooltips, signal)

# Create a "dropdown" widget. `choices` can be a vector of
# options. Optionally specify the starting `value` (defaults to the
# first choice), the `typ` of elements in `choices`, supply custom
# `icons`, provide `tooltips`, and/or specify the (Reactive.jl) `signal`
# coupled to this widget.

# # Examples

#     a = dropdown(["one", "two", "three"])

# To link a callback to the dropdown, use

#     f = dropdown(["turn red"=>colorize_red, "turn green"=>colorize_green])
#     map(g->g(image), signal(f))
# """
# dropdown(opts; kwargs...) =
#     Options(:Dropdown, opts; kwargs...)

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

# ### Output Widgets

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
