# Widgets built on top of more basic widgets

frame(f::GtkFrame) = f

################# A movie-player widget ##################

immutable Player{P,R<:Range} <: Widget
    signal::CheckedSignal{Int,R}
    widget::P
    preserved::Vector
end

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

function PlayerWithTextbox(builder, index::CheckedSignal, id::Integer=1)
    1 <= id <= 2 || error("only 2 player widgets are defined in player.glade")
    range = index.bounds
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
    preserved = [map(x->push!(direction, -1), signal(play_back)),
                 map(x->(push!(direction, 0); push!(index, clampindex(value(index)-1))),
                     signal(step_back)),
                 map(x->push!(direction, 0), signal(stop)),
                 map(x->(push!(direction, 0); push!(index, clampindex(value(index)+1))),
                     signal(step_forward)),
                 map(x->push!(direction, +1), signal(play_forward))]
    function advance(widget)
        i = value(index) + value(direction)
        if !(i ∈ range)
            push!(direction, 0)
            i = clampindex(i)
        end
        push!(index, i)
        nothing
    end
    # Some of the previous code seems to trigger signals, so let's stop it
    push!(direction, 0)
    # Start the timer
    push!(preserved, map(advance, fpswhen(map(x->x!=0, direction), 30)))
    # Create the player object
    PlayerWithTextbox(range, direction, frame, scale, entry, play_back, step_back, stop, step_forward, play_forward), preserved
end
function PlayerWithTextbox(index::CheckedSignal, id::Integer=1)
    builder = GtkBuilder(filename=joinpath(splitdir(@__FILE__)[1], "player.glade"))
    PlayerWithTextbox(builder, index, id)
end

player(range::Range{Int}; style="with-textbox", id::Int=1) =
    player(CheckedSignal(first(range), range); style=style)

function player(cs::CheckedSignal; style="with-textbox", id::Int=1)
    if style == "with-textbox"
        widget, preserved = PlayerWithTextbox(cs, id)
        return Player(cs, widget, preserved)
    end
    error("style $style not recognized")
end
