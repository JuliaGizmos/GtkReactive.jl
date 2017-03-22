# Introduction

## Scope of this package

GtkReactive is a package building on the functionality of
[Gtk.jl](https://github.com/JuliaGraphics/Gtk.jl) and
[Reactive.jl](https://github.com/JuliaGizmos/Reactive.jl). Its main
purpose is to simplify the handling of interactions among components
of a graphical user interface (GUI).

Creating a GUI generally involves some or all of the following:

1. creating the controls
2. arranging the controls (layout) in one or more windows
3. specifying the interactions among components of the GUI
4. (for graphical applications) canvas drawing
5. (for graphical applications) canvas interaction (mouse clicks, drags, etc.)

GtkReactive is targeted primarily at items 1, 3, and 5. Layout is
handled by Gtk.jl, and drawing (with a couple of exceptions) is
handled by plotting packages or at a lower level by
[Cairo](https://github.com/JuliaGraphics/Cairo.jl).

GtkReactive is suitable for:

- "quick and dirty" applications which you might create from the command line
- more sophisticated GUIs where layout is specified using tools like [Glade](https://glade.gnome.org/)

For usage with Glade, the [Input widgets](@ref) and
[Output widgets](@ref) defined by this package allow you to supply a
preexisting `widget` (which you might load with GtkBuilder) rather
than creating one from scratch. Users interested in using GtkReactive
with Glade are encouraged to see how the [`player`](@ref) widget is
constructed (see `src/extrawidgets.jl`).

At present, GtkReactive supports only a small subset of the
[widgets provided by Gtk](https://developer.gnome.org/gtk3/stable/ch03.html). It
is fairly straightforward to add new ones, and pull requests would be
welcome.

## Concepts

The central concept of Reactive.jl is the `Signal`, a type that allows
updating with new values that then triggers actions that may update
other `Signal`s or execute functions. Your GUI ends up being
represented as a "graph" of Signals that collectively propagate the
state of your GUI. GtkReactive couples `Signal`s to Gtk.jl's
widgets. In essence, Reactive.jl allows ordinary Julia objects to
become the triggers for callback actions; the primary advantage of
using Julia objects, rather than Gtk widgets, as the "application
logic" triggers is that it simplifies reasoning about the GUI and
seems to reduce the number of times ones needs to consult the
[Gtk documentation](https://developer.gnome.org/gtk3/stable/gtkobjects.html).

Because these can sometimes be a source of bugs, it's worth
emphasizing two crucial features of Reactive.jl Signals:

- updates to `Signal`s are asynchronous, so values will not propagate
  until the next time the Reactive message-handler runs

- derived signals are subject to garbage-collection; you should either
  hold a reference to or `preserve` any derived signals (for any
  signals that are associated with updating an on-screen widget, see
  also [`GtkReactive.gc_preserve`](@ref)).

Please see the [Reactive.jl documentation](http://juliagizmos.github.io/Reactive.jl/) for more information.
