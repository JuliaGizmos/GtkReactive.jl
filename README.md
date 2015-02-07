# GtkInteract

[![Build Status](https://travis-ci.org/jverzani/GtkInteract.jl.svg?branch=master)](https://travis-ci.org/jverzani/GtkInteract.jl)

The [`Interact`](https://github.com/JuliaLang/Interact.jl) package
brings interactive widgets to `IJulia` notebooks. In particular, the
`@manipulate` macro makes it trivial to define simple interactive
graphics. Though `Interact` can animate graphics using `Gadfly`,
`PyPlot`, or `Winstont`, the new
[`Patchwork`](https://github.com/shashi/Patchwork.jl) package can be
used to efficiently manipulate SVG graphics, including those created
through `Gadfly`, for more fluid graphical animations.

The `GtkInteract` package modifies `Interact`'s `@manipulate` macro to
allow interactive widgets from the command-line REPL using the `Gtk`
package for the widget toolkit. The allows for similarly easy
interactive graphics with `Winston`. The basic syntax is the same:

```
using GtkInteract, Winston
@manipulate for ϕ = 0:π/16:4π, f = [:sin=>sin, :cos=>cos]
    plot(θ -> f(θ + ϕ), 0, 25)
end
```

![Imgur](http://i.imgur.com/1MiynXf.png)

Text output can also be displayed (though not as nicely as in `IJulia` due to HTML and LaTeX support):

```
using GtkInteract, SymPy
x = Sym("x")
@manipulate for n=1:5
   a = diff(sin(x^2), x, n)
   jprint(a)
end
```

The basic widgets can also be used by hand to create simple GUIs:

```
using Reactive
w = mainwindow(title="Simple test")
n = slider(1:10, label="n")
m = slider(11:20, label="m")
cg = cairographic()

append!(w, [n, m, cg])		# layout widgets

@lift push!(cg, plot(sin, n*pi, m*pi))
```


## Installation

Until this package lands in `Julia`'s METADATA it should be installed via "cloning":

```
Pkg.clone("https://github.com/jverzani/GtkInteract.jl")
```

This package requires [Gtk](https://github.com/JuliaLang/Gtk.jl) (for
GTK+ 3, not GTK+ 2). See that page for installation notes.

## Using with PyPlot

There is experimental support for plotting with PyPlot. Rather than have a `withfig(f)` call, as with `IJulia`, we have a call to `gcf()` as the final command:

```
using PyPlot
pygui(false) ## necessary

using GtkInteract
@manipulate for n in 1:10, m in 1:10
    ts = linspace(0, 2*n*m*pi, 2500)
    xs = [sin(m*t) for t in ts]
    ys = [cos(n*t) for t in ts]
    PyPlot.plot(xs, ys)
    gcf()
end
```

The `pygui(false)` seems necessary to prevent a crash. There may be a *much* nicer way of doing this -- if you know how, please share.
