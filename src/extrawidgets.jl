# Widgets built on top of more basic widgets

"""
    frame(w) -> f

Return the GtkFrame `f` associated with widget `w`.
"""
frame(f::GtkFrame) = f

################# A movie-player widget ##################

immutable Player{P} <: Widget
    signal::Signal{Int}
    widget::P
    preserved::Vector

    function (::Type{Player{P}}){P}(signal::Signal{Int}, widget, preserved)
        obj = new{P}(signal, widget, preserved)
        gc_preserve(frame(widget), obj)
        obj
    end
end
Player{P}(signal::Signal{Int}, widget::P, preserved) =
    Player{P}(signal, widget, preserved)

frame(p::Player) = frame(p.widget)

immutable PlayerWithTextbox
    range::UnitRange{Int}     # valid values for index
    direction::Signal{Int8}   # +1 = forward, -1 = backward, 0 = not playing
    # GUI elements
    frame::GtkFrame
    scale::Slider{Int}
    entry::Textbox
    play_back::Button
    step_back::Button
    stop::Button
    step_forward::Button
    play_forward::Button
end

frame(p::PlayerWithTextbox) = p.frame

function PlayerWithTextbox(builder, index::Signal, range::AbstractUnitRange, id::Integer=1)
    1 <= id <= 2 || error("only 2 player widgets are defined in player.glade")
    direction = Signal(Int8(0))
    frame = Gtk.G_.object(builder,"player_frame$id")
    scale = slider(range; widget=Gtk.G_.object(builder,"index_scale$id"), signal=index)
    entry = textbox(first(range); widget=Gtk.G_.object(builder,"index_entry$id"), signal=index, range=range)
    play_back = button(; widget=Gtk.G_.object(builder,"play_back$id"))
    step_back = button(; widget=Gtk.G_.object(builder,"step_back$id"))
    stop = button(; widget=Gtk.G_.object(builder,"stop$id"))
    step_forward = button(; widget=Gtk.G_.object(builder,"step_forward$id"))
    play_forward = button(; widget=Gtk.G_.object(builder,"play_forward$id"))

    # Fix up widget properties
    setproperty!(scale.widget, "round-digits", 0)  # glade/gtkbuilder bug that I have to set this here?

    # Link the buttons
    clampindex(i) = clamp(i, minimum(range), maximum(range))
    preserved = [map(x->push!(direction, -1), signal(play_back); init=nothing),
                 map(x->(push!(direction, 0); push!(index, clampindex(value(index)-1))),
                     signal(step_back); init=nothing),
                 map(x->push!(direction, 0), signal(stop); init=nothing),
                 map(x->(push!(direction, 0); push!(index, clampindex(value(index)+1))),
                     signal(step_forward); init=nothing),
                 map(x->push!(direction, +1), signal(play_forward); init=nothing)]
    function advance(widget)
        i = value(index) + value(direction)
        if !(i ∈ range)
            push!(direction, 0)
            i = clampindex(i)
        end
        push!(index, i)
        nothing
    end
    # Stop playing if the widget is destroyed
    signal_connect(frame, :destroy) do widget
        push!(direction, 0)
    end
    # Start the timer
    push!(preserved, map(advance, fpswhen(map(x->x!=0, direction), 30)))
    # Create the player object
    PlayerWithTextbox(range, direction, frame, scale, entry, play_back, step_back, stop, step_forward, play_forward), preserved
end
function PlayerWithTextbox(index::Signal, range::AbstractUnitRange, id::Integer=1)
    builder = GtkBuilder(filename=joinpath(splitdir(@__FILE__)[1], "player.glade"))
    PlayerWithTextbox(builder, index, range, id)
end

player(range::Range{Int}; style="with-textbox", id::Int=1) =
    player(Signal(first(range)), range; style=style, id=id)

"""
    player(range; style="with-textbox", id=1)
    player(slice::Signal{Int}, range; style="with-textbox", id=1)

Create a movie-player widget. This includes the standard play and stop
buttons and a slider; style "with-textbox" also includes play
backwards, step forward/backward, and a textbox for entering a
slice by keyboard.

You can create up to two player widgets for the same GUI, as long as
you pass `id=1` and `id=2`, respectively.
"""
function player(cs::Signal, range::AbstractUnitRange; style="with-textbox", id::Int=1)
    if style == "with-textbox"
        widget, preserved = PlayerWithTextbox(cs, range, id)
        return Player(cs, widget, preserved)
    end
    error("style $style not recognized")
end

Base.unsafe_convert(::Type{Ptr{Gtk.GLib.GObject}}, p::PlayerWithTextbox) =
    Base.unsafe_convert(Ptr{Gtk.GLib.GObject}, frame(p))



################# A time widget ##########################

immutable TimeWidget <: InputWidget{Dates.Time}
    signal::Signal{Dates.Time}
    widget::GtkBox
    id::Culong
    preserved::Vector

    function (::Type{TimeWidget})(signal::Signal{Dates.Time}, widget, id, preserved)
        obj = new(signal, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end
TimeWidget(signal::Signal{Dates.Time}, widget::GtkBox, id, preserved) =
    TimeWidget(signal, widget, id, preserved)

timewidget(signal::Signal, widget::GtkBox, id, preserved = []) =
    TimeWidget(signal, widget, id, preserved)

"""
    timewidget(time; widget=nothing, value=nothing, signal=nothing, orientation="vertical")

Create a timewidget widget with the specified `time`. Optionally provide:
  - the GtkBox `widget` (by default, creates a new one)
  - the starting `value` (defaults to `Time(0,0,0)`)
  - the (Reactive.jl) `signal` coupled to this timewidget (by default, creates a new signal)
  - the `orientation` of the timewidget.
"""
function timewidget(time::Dates.Time;
                   widget=nothing,
                   value=nothing,
                   signal=nothing,
                   orientation="vertical",
                   syncsig=true,
                   own=nothing)



    signalin = signal
    signal, value = init_wsigval(Dates.Time, signal, value; default=Dates.Time(0,0,0))
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

    TimeWidget(signal, widget, id, preserved)
end












immutable TimeWidget
    signal::Signal{Dates.Time}
    widget::GtkBox
end

"""
    timewidget(time)

Return a time widget that includes the `Time` and a `GtkBox` with the hour, minute, and second widgets in it.
"""
function timewidget(t0::Dates.Time)
    t = Signal(t0)
    # values
    h = map(x -> Dates.value(Dates.Hour(x)), t)
    m = map(x -> Dates.value(Dates.Minute(x)), t)
    s = map(x -> Dates.value(Dates.Second(x)), t)
    # widgets
    hour = spinbutton(0:23, signal=h, orientation="v")
    increase_hour = Signal(false)
    minute = cyclicspinbutton(0:59, increase_hour, signal=m, orientation="v") 
    increase_minute = Signal(false)
    second = cyclicspinbutton(0:59, increase_minute, signal=s, orientation="v") 
    # maps and filters
    hourleft = map(increase_hour, hour) do i, h
        i ? h < 23 : h > 0
    end
    increase_hourᵗ = filterwhen(hourleft, value(increase_hour), increase_hour)
    foreach(increase_hourᵗ; init=nothing) do i
        push!(hour, value(hour) - (-1)^i)
    end
    timeleft = map(increase_minute, hour, minute) do i, h, m
        i ? m < 59 || h < 23 : m > 0 || h > 0
    end
    increase_minuteᵗ = filterwhen(timeleft, value(increase_minute), increase_minute)
    foreach(increase_minuteᵗ; init=nothing) do i
        push!(minute, value(minute) - (-1)^i)
    end
    tupled_time = map(tuple, hour, minute, second)
    good_time = map(tupled_time) do x
        isnull(Dates.validargs(Dates.Time, x..., 0, 0, 0))
    end
    x2 = filterwhen(good_time, value(tupled_time), tupled_time)
    t2 = map(x -> Dates.Time(x...), x2)
    bind!(t, t2, true, initial=false)
    # make everything as small as possible
    setproperty!(widget(hour), :width_request, 1)
    setproperty!(widget(minute), :width_request, 1)
    setproperty!(widget(second), :width_request, 1)
    setproperty!(widget(hour), :height_request, 1)
    setproperty!(widget(minute), :height_request, 1)
    setproperty!(widget(second), :height_request, 1)
    b = Gtk.Box(:h)
    push!(b, hour, minute, second)
    # done
    return TimeWidget(t, b)
end

# These would be cool to use, but I'm not sure if you want me to import all of these from Reactive, or if I should some how make TimeWidget a subtype of InputWidget. All my attempts to do either failed...
# signal(w::TimeWidget) = w.signal
# value(w::TimeWidget) = value(signal(w))
# Dates.Time(w::TimeWidget) = value(w)
# widget(w::TimeWidget) = w.widget
# Reactive.push!(w::TimeWidget, t::Dates.Time) = push!(signal(w), t)
# Reactive.map(f::Function, w::TimeWidget) = map(f, signal(w))

