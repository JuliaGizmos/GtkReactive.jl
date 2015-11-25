# GtkInteract

[![Build Status](https://travis-ci.org/jverzani/GtkInteract.jl.svg?branch=master)](https://travis-ci.org/jverzani/GtkInteract.jl)

The [`Interact`](https://github.com/JuliaLang/Interact.jl) package
brings interactive widgets to `IJulia` notebooks. In particular, the
`@manipulate` macro makes it trivial to define simple interactive
graphics.  `Interact` can animate graphics using `Gadfly`, `PyPlot`,
or `Winston`. For more fluid graphical animations, the 
[`Patchwork`](https://github.com/shashi/Patchwork.jl) package can be
used to efficiently manipulate SVG graphics, including those created
through `Gadfly`,

The `GtkInteract` package modifies `Interact`'s `@manipulate` macro to
allow interactive widgets from the command-line REPL using the `Gtk`
package for the widget toolkit. This package then allows for similarly
easy interactive graphics from the command line. It works with the
following packages: `Immerse`, or `Plots` with the `:immerse` backend.
There is some experimental, though buggy, support for using `PyPlot`
graphics. `Winston` graphics should also work.

The basic syntax is the same as for `Interact`. For example, 

```
using GtkInteract, Plots
backend(:immerse)
@manipulate for ϕ = 0:π/16:4π, f = Dict(:sin=>sin, :cos=>cos)
    plot(θ -> f(θ + ϕ), 0, 25)
end
```

This produces a layout along the lines of:

![Imgur](http://i.imgur.com/1MiynXf.png)

Using `Immerse` directly is also possible:

```
using GtkInteract, Immerse
@manipulate for ϕ = 0:π/16:4π, f = Dict(:sin=>sin, :cos=>cos)
    xs = linspace(0, 25)
    ys = map(θ -> f(θ + ϕ), xs)
    Immerse.plot(x=xs, y=ys)
end
```

When used directly, the figure includes the toolbar features provided by `Immerse`.

## Text output

Text output can also be displayed (though not as nicely as in `IJulia` due to a lack of HTML support):

```
using GtkInteract, SymPy
x = symbols("x")
@manipulate for n=1:5
   a = diff(sin(x^2), x, n)
   SymPy.jprint(a)
end
```

The basic idea is that an output widget is chosen based on the return
value of the evaluation of the block within the `@manipulate`
macro. Returning a value of `nothing` will suppress any output widget
being chosen. In this case, the body should have side effects, such as
explicitly creating a graph. Some of the provided `examples`
illustrate why this might be of interest.

## basic widgets

The basic widgets can also be used by hand to create simple GUIs:

```
using GtkInteract

w = mainwindow(title="Simple test")
n = slider(1:10, label="n")
m = slider(11:20, label="m")
cg = cairographic()

append!(w, [n, m, cg])		# layout widgets
```


More complicated layouts are possible using a few layouts similar to those in the `Escher` package:

```
window(vbox(hbox(n, m),
                     grow(cg)),
              title="Some title")
```

We can use `Reactive.map`to propagate changes in the controls to update the graphic window:

```
map(n,m) do n,m
  push!(cg, plot(sin, n*pi, m*pi))
end
```

This basic usage follows this pattern: we map over the input widgets
and within the function passed to map (through the `do` notation
above), we `push!` some combination of the values onto one or more
output widgets, such as `cg` above. The `@manipulate` macro basically
figure out an output widget from the last value found in the code
block and pushes that value onto the output widget.

## Installation

Until this package lands in `Julia`'s METADATA it should be installed via "cloning":

```
Pkg.clone("https://github.com/jverzani/GtkInteract.jl")
```

This package requires [Gtk](https://github.com/JuliaLang/Gtk.jl) (for
GTK+ 3, not GTK+ 2). See that page for installation notes.

## Using with PyPlot

[This is currently broken on a mac, segfaulting with the interactivity!]

There is experimental support for plotting with PyPlot. Using `PyPlot`
requires an extra wrapper function, called `GtkInteract.withfig`. (The `withfig`
function is defined in  `PyPlot` and modified here, hence the module qualification.)

```
using GtkInteract, PyPlot

f = figure()
@manipulate for n in 1:10, m in 1:10
    GtkInteract.withfig(f) do
      ts = linspace(0, 2*n*m*pi, 2500)
      xs = [sin(m*t) for t in ts]
      ys = [cos(n*t) for t in ts]
      PyPlot.plot(xs, ys)
    end
end
```

It can be a bit slower, as this does not draw onto a canvas, but
rather creates an image file and displays that on each update.  In the
background `pygui(false)` is called. Not doing so leads to a crash on
some machines.

(To copy-and-paste code that works with `Interact` simply requires some local definition such as `withfig=GtkInteract.withfig`.)

## Widget summary

In addition to the widgets in `Interact`, the following new widgets are provided:

* `buttongroup`, `selectlist` (just a renamed `Interact.select`)
* `cairographic`, `immersefigure`, `textarea`, `label`, `progress`
* `icon`, `separator`, `tooltip`
* `size`, `width`, `height`, `vskip`, `hskip`
* `grow`, `shrink`, `flex`
* `align`, `halign`, `valign`
* `padding`
* `vbox`, `hbox`, `tabs`, `formlayout`
* `toolbar`, `menu`
* `window`, `mainwindow`
* `messagebox`, `confirmbox`, `inputbox`, `openfile`, `savefile`, `selectdir`


