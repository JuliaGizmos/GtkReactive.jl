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

immutable TimeWidget{T <: Dates.TimeType} <: InputWidget{T}
    signal::Signal{T}
    widget::GtkFrame
end

"""
    timewidget(time)

Return a time widget that includes the `Time` and a `GtkFrame` with the hour, minute, and
second widgets in it. You can specify the specific `GtkFrame` widget (useful when using the `Gtk.Builder` and `glade`). Time is guaranteed to be positive. 
"""
function timewidget(t1::Dates.Time; widget=nothing, signal=nothing)
    const zerotime = Dates.Time(0,0,0)
    b = Gtk.GtkBuilder(filename=joinpath(@__DIR__, "time.glade"))
    if signal == nothing
        signal = Signal(t1)
    end
    S = map(signal) do x
        (Dates.Second(x), x)
    end
    M = map(S) do x
        x = last(x)
        (Dates.Minute(x), x)
    end
    H = map(M) do x
        x = last(x)
        (Dates.Hour(x), x)
    end
    t2 = map(last, H)
    bind!(signal, t2)
    Sint = Signal(Dates.value(first(value(S))))
    Ssb = spinbutton(-1:60, widget=b["second"], signal=Sint)
    foreach(Sint) do x
        Δ = Dates.Second(x) - first(value(S))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Second(new_t)
        push!(S, (new_x, new_t))
    end
    Sint2 = map(src -> Dates.value(Dates.Second(src)), t2)
    Sint3 = droprepeats(Sint2)
    bind!(Sint, Sint3, false)
    Mint = Signal(Dates.value(first(value(M))))
    Msb = spinbutton(-1:60, widget=b["minute"], signal=Mint)
    foreach(Mint) do x
        Δ = Dates.Minute(x) - first(value(M))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Minute(new_t)
        push!(M, (new_x, new_t))
    end
    Mint2 = map(src -> Dates.value(Dates.Minute(src)), t2)
    Mint3 = droprepeats(Mint2)
    bind!(Mint, Mint3, false)
    Hint = Signal(Dates.value(first(value(H))))
    Hsb = spinbutton(0:23, widget=b["hour"], signal=Hint)
    foreach(Hint) do x
        Δ = Dates.Hour(x) - first(value(H))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Hour(new_t)
        push!(H, (new_x, new_t))
    end
    Hint2 = map(src -> Dates.value(Dates.Hour(src)), t2)
    Hint3 = droprepeats(Hint2)
    bind!(Hint, Hint3, false)

    if widget == nothing
        return TimeWidget(signal, b["frame"])
    else
        push!(widget, b["frame"])
        return TimeWidget(signal, widget)
    end
end

"""
    datetimewidget(datetime)

Return a datetime widget that includes the `DateTime` and a `GtkBox` with the
year, month, day, hour, minute, and second widgets in it. You can specify the
specific `SpinButton` widgets for the hour, minute, and second (useful when using
`Gtk.Builder` and `glade`). Date and time are guaranteed to be positive. 
"""
function datetimewidget(t1::DateTime; widget=nothing, signal=nothing)
    const zerotime = DateTime(0,1,1,0,0,0)
    b = Gtk.GtkBuilder(filename=joinpath(@__DIR__, "datetime.glade"))
    # t1 = eps(t0) < Dates.Second(1) ? round(t0, Dates.Second(1)) : t0
    if signal == nothing
        signal = Signal(t1)
    end
    S = map(signal) do x
        (Dates.Second(x), x)
    end
    M = map(S) do x
        x = last(x)
        (Dates.Minute(x), x)
    end
    H = map(M) do x
        x = last(x)
        (Dates.Hour(x), x)
    end
    d = map(H) do x
        x = last(x)
        (Dates.Day(x), x)
    end
    m = map(d) do x
        x = last(x)
        (Dates.Month(x), x)
    end
    y = map(m) do x
        x = last(x)
        (Dates.Year(x), x)
    end
    t2 = map(last, y)
    bind!(signal, t2)
    Sint = Signal(Dates.value(first(value(S))))
    Ssb = spinbutton(-1:60, widget=b["second"], signal=Sint)
    foreach(Sint) do x
        Δ = Dates.Second(x) - first(value(S))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Second(new_t)
        push!(S, (new_x, new_t))
    end
    Sint2 = map(src -> Dates.value(Dates.Second(src)), t2)
    Sint3 = droprepeats(Sint2)
    bind!(Sint, Sint3, false)
    Mint = Signal(Dates.value(first(value(M))))
    Msb = spinbutton(-1:60, widget=b["minute"], signal=Mint)
    foreach(Mint) do x
        Δ = Dates.Minute(x) - first(value(M))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Minute(new_t)
        push!(M, (new_x, new_t))
    end
    Mint2 = map(src -> Dates.value(Dates.Minute(src)), t2)
    Mint3 = droprepeats(Mint2)
    bind!(Mint, Mint3, false)
    Hint = Signal(Dates.value(first(value(H))))
    Hsb = spinbutton(-1:24, widget=b["hour"], signal=Hint)
    foreach(Hint) do x
        Δ = Dates.Hour(x) - first(value(H))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Hour(new_t)
        push!(H, (new_x, new_t))
    end
    Hint2 = map(src -> Dates.value(Dates.Hour(src)), t2)
    Hint3 = droprepeats(Hint2)
    bind!(Hint, Hint3, false)
    dint = Signal(Dates.value(first(value(d))))
    dsb = spinbutton(-1:32, widget=b["day"], signal=dint)
    foreach(dint) do x
        Δ = Dates.Day(x) - first(value(d))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Day(new_t)
        push!(d, (new_x, new_t))
    end
    dint2 = map(src -> Dates.value(Dates.Day(src)), t2)
    dint3 = droprepeats(dint2)
    bind!(dint, dint3, false)
    mint = Signal(Dates.value(first(value(m))))
    msb = spinbutton(-1:13, widget=b["month"], signal=mint)
    foreach(mint) do x
        Δ = Dates.Month(x) - first(value(m))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Month(new_t)
        push!(m, (new_x, new_t))
    end
    mint2 = map(src -> Dates.value(Dates.Month(src)), t2)
    mint3 = droprepeats(mint2)
    bind!(mint, mint3, false)
    yint = Signal(Dates.value(first(value(y))))
    ysb = spinbutton(-1:10000, widget=b["year"], signal=yint)
    foreach(yint) do x
        Δ = Dates.Year(x) - first(value(y))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Year(new_t)
        push!(y, (new_x, new_t))
    end
    yint2 = map(src -> Dates.value(Dates.Year(src)), t2)
    yint3 = droprepeats(yint2)
    bind!(yint, yint3, false)

    if widget == nothing
        return TimeWidget(signal, b["frame"])
    else
        push!(widget, b["frame"])
        return TimeWidget(signal, widget)
    end
end
