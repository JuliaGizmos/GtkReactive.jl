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
end

"""
    timewidget(time)

Return a time widget that includes the `Time` and a `GtkBox` with the hour, minute, and second widgets in it.
You can specify the specific `SpinButton` widgets for the hour, minute, and second (useful when using the 
`Gtk.Builder` and `glade`).
"""
function timewidget(t0::Dates.Time; hour_widget=nothing, minute_widget=nothing, second_widget=nothing)
    t = Signal(t0)
    # values
    h = map(x -> Dates.value(Dates.Hour(x)), t)
    m = map(x -> Dates.value(Dates.Minute(x)), t)
    s = map(x -> Dates.value(Dates.Second(x)), t)
    # widgets
    hour = spinbutton(0:23, widget=hour_widget, signal=h)
    increase_hour = Signal(false)
    minute = cyclicspinbutton(0:59, increase_hour, widget=minute_widget, signal=m)
    increase_minute = Signal(false)
    second = cyclicspinbutton(0:59, increase_minute, widget=second_widget, signal=s)
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

