using GtkReactive, Gtk.ShortNames, Colors

# Create some controls
n = slider(1:10)
dd = dropdown(["one"=>()->println("you picked \"one\""),
               "two"=>()->println("two for tea"),
               "three"=>()->println("three is a magic number")],
              label="dropdown")
cb = checkbox(true, label="make window visible")

# To illustrate some of Reactive's propagation, we create a textbox
# that shares the signal with the slider. You could alternatively
# `bind` the two signals together.
tb = textbox(Int; signal=n.signal)

# Set up the mapping for the dropdown callbacks
cbsig = map(g->g(), dd.mappedsignal)  # assign to variable to prevent garbage collection

# Lay out the GUI. You can alternatively use `glade` and pass the
# widgets to the constructors above (see the implementation of
# `player` in `extrawidgets.jl` for an example).
mainwin = Window("GtkReactive")
vbox = Box(:v)
hbox = Box(:h)
push!(vbox, hbox)
push!(hbox, n)
push!(hbox, tb)
push!(vbox, dd)
push!(vbox, cb)
push!(mainwin, vbox)

# Create the auxillary window and link its visibility to the checkbox
cnvs = canvas()
auxwin = Window(cnvs)
map(cb) do val
    setproperty!(auxwin, :visible, val)
end
# Also make sure it gets destroyed when we destroy the main window
signal_connect(mainwin, :destroy) do w
    destroy(auxwin)
end
# Draw something in the auxillary window
draw(cnvs) do c
    fill!(c, colorant"orange")
end
showall(auxwin)

showall(mainwin)
