## The creation of *simple* GUIs usually involves 3 steps:
##
## * create the controls
## * layout the controls
## * propagate changes in a control to some output

## With `GtkInteract`, the first two are covered by using patterns from
## `Interact` and `Escher`; the latter by patterns from `Reactive.


using GtkInteract, Reactive, Plots
backend(:immerse)


## To create controls is done by calling the constructor. The
## constructors are fairly primitive and have little customization.
## The available controls
## basically map some data into a GUI element:

n = slider(1:10, label="n")
rb = radiobutton(["one", "two", "three"], label="radio")
cb = checkbox(true, label="checkbox")

## the `Interact.widget` function will try to read your mind:

Interact.widget(1:4) # a slider
Interact.widget(true) # a check box
Interact.widget(["one", "two", "three"]) # togglebuttons


## To layout the controls we first make a parent window, and then add
## widgets to that.  We have two types of parent windows `mainwindow`
## and `window`. The `mainwindow` container uses a fixed "form" layout
## for simplicity. One simply appends the controls to the
## mainwindow. The `label` property of the widget, is used to label
## the control.

w = mainwindow(title="Simple test")
n = slider(1:10, label="n") 
m = slider(11:20, label="m")
cg = cairographic()
append!(w, [n,m,cg])


## Other layouts are available. The style is borrowed from Escher,
## though not all the functionality from Escher is implemented. For
## this use, instead of `mainwindow`, a `window` object is used.
## For example, we have:

n = slider(1:10, label="n:")
m = slider(11:20, label="m:")
cg = cairographic()
w = window(hbox(vbox(hbox(label(n.label), n),
                     hbox(label(m.label), m)
                    ),
               padding(5, grow(cg))); title = "Simple test")


## This uses boxes (`hbox` and `vbox`) to orangize child widgets. The
## structure above is that a `hbox` is used to hold a box that has the
## two slider controls and the graphic window. A vertical box is used
## to layout the slider controls. Unlike the layout with `mainwindow`,
## the labels must be managed by the programmer. Hence the construct
## `hbox(label(n.label), n)`. This pattern packs a label next to the
## control.  To adjust layouts, there are a few
## attributes. Illustrated above is `padding`, which adds 5 pixels of
## "padding" around the widget used to display the graphic; and `grow`
## which instructs the child to grow to fill any allocated space.

## However the layout is done, once the widgets are made and layed
## out, they can be connected using Reactive signals:

map(n, m) do n,m
    push!(cg, plot(sin, n*pi, m*pi))
end

## the map function propagates changes to the underlying widgets to
## the function call.
##
## The `map` functon (`map(fn, widgets...)`) takes
## the widgets and allows them to be referenced by their values. That
## is, the use of `n` and `m` within the `plot` command uses the
## values in the controls `n` and `m`.
##
## With `GtkInteract`, there are
## two basic types of widgets: input widgets and output widgets. The
## graphics device is an output widget. For these, values are
## `push!`ed onto them. So the call `push!(cg, ...)` should update the
## graphic using the generated plot. Other output widgets include
## `immersefigure`, and `textarea`.


## A pattern where the update only is related to a button push, and
## not each control is desired if the update is expensive to compute
## (With sliders it may be computed up to 4 times during the move).

w = mainwindow(title="Simple test")
n = slider(1:10, label="n")
m = slider(1:10, label="m")
btn = button("update")
append!(w, [n, m, btn])

## We can connect to the button to pass along the values of the other widget:
map(btn) do _
    println(Reactive.value(n.signal) * Reactive.value(m.signal))
end


## The above is cumbersome, as to extract a value from a widget
## requires grabbing the value from its
## signal property. This package provides an shorthant: `value(n)`.
##
## For a more elegant solution, we can leverage this pattern from
## Shasi. It is modifed from
## https://groups.google.com/forum/?fromgroups#!topic/julia-users/Ur5b2_dsJyA
## as there are changes needed for the newer Reactive.jl.
##

w = mainwindow(title="Simple test")
n = slider(1:10, label="n")
m = slider(1:10, label="m")
btn = button("update")
append!(w, [n, m, btn])

vals = map(tuple, n, m)  # not just (n,m), as map "lifts" values.

map(vals->println(join(vals, ", ")), Reactive.sampleon(btn.signal, vals))

## The `vals` is not just `(n,m)`, but instead `map` lifts the signals
## from the widgets `n` and `m` and passes their values on to a tuple
## whenever the signals changes. So `vals` reflects the current state
## of the two widgets.
##
## The `sampleon` function samples the value of `vals` when the
## button's signal is emitted, which happens when the button is
## clicked. So `Reactive.sampleon(btn.signal, vals)` makes a new
## signal which is emitted when the button is clicked and passes on a
## tuple of values reflecting the state of the widgets `m` and `n`.
##
## In this example, the values are just printed. In the next example a
## graph is drawn.

using Reactive, GtkInteract, Plots
backend(:immerse)

α = slider(1:10, label="α")
β = slider(1:10, label="β")
replot = button("replot")
cg = cairographic()

## display
hbox(vbox(hbox(label(α.label),α),
          hbox(label(β.label), β),
          replot),
     padding(5, cg)) |> window(title="layout")

## Our action:
function draw_plot(α, β)
    push!(cg, plot(x -> α + sin(x + β), 0, 2pi))
end

## We can then connect the button as follows:
coeffs = Reactive.sampleon(replot.signal, map(tuple, α, β))
map(vals -> drow_plot(vals...), coeffs)


## Here, unlike with `@manipulate`, the graphic is only updated when
## the `replot` button is pressed. Changing the sliders only updates
## the `coeffs` values, which is propogated when the button is
## pressed.


## For this specific pattern with a button, `GtkInteract` extends Reactive's `sampleon` function, so that
## the first line can be just:
coeffs = sampleon(replot, α, β)





## kitchen sink of control widgets
##
using DataStructures
a = OrderedDict{Symbol, Int}()
a[:one]=1; a[:two] = 2; a[:three] = 3

l = Dict()
l[:slider]        = slider(1:10, label="slider")
l[:button]        = button("button label")
l[:checkbox]      = checkbox(true, label="checkbox")
l[:togglebutton]  = togglebutton(true, label="togglebutton")
l[:dropdown]      = dropdown(a, label="dropdown")
l[:radiobuttons]  = radiobuttons(a, label="radiobuttons")
l[:select]        = selectlist(a, label="select")  # aka Interact.select
l[:togglebuttons] = togglebuttons(a, label="togglebuttons")
l[:buttongroup]   = buttongroup(a, label="buttongroup") # non exclusive
l[:textbox]       = textbox("text goes here", label="textbox")

w = mainwindow()
append!(w, values(l))


## ANother out put widget
## progress bar
##
using GtkInteract
w = mainwindow()
b = button("press")
pb = progress()

append!(w, [pb, b])

# connect button press to update
map(b) do _
    push!(pb, floor(Integer, 100*rand()))
end


## There is some some support for toolbars and menubars. This silly example 
## demonstrates the basic usage

btn = button("button")
btn1 = button("one")
btn2 = button("two")
tog = togglebutton(value=true, label="button")

mb = menu(menu(btn1, separator(),
               menu(btn1, btn2, label="submenu"), # submenus need `label=` argument
               btn2, label="one"),
          menu(btn1, btn2, btn, label="two"))

map(_ -> println("ouch"), btn1)         # some actin
map(_ -> println("kjapow"), btn2)

tb = toolbar(icon("window-close", btn), # add icon...
             separator(),
             (tog |> icon("window-open"))
             )

l = button("one") 

window(mb, tb, grow(icon("window-close", l)))


## We see that a toolbar just takes child widgets as its
## arguments. The pattern `icon(icon_name, tile)` adds a tile to the
## toolbar item.

## The menu bar is similar, though we add submenus using `menu`
## again. These submenus must have a `label` value specified through a
## keyword argument.

