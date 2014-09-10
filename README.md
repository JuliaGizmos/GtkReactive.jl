# GtkInteract

[![Build Status](https://travis-ci.org/jverzani/GtkInteract.jl.svg?branch=master)](https://travis-ci.org/jverzani/GtkInteract.jl)

The [`Interact`](https://github.com/JuliaLang/Interact.jl)  package brings interactive widgets to `IJulia`
notebooks. In particular, the `@manipulate` macro makes it trivial to
define simple interactive graphics.

This package provides a similar `@manipulate` macro using `Gtk` for
the widget toolkit, allowing similarly easy interactive graphics with
Winston. The basic syntax is *almost* the same:

```
using GtkInteract
using Winston
@manipulate for ϕ = 0:π/16:4π, f = [:sin=>sin, :cos=>cos], out=:plot
       p = plot(θ -> f(θ + ϕ), 0, 25)
       push!(out, p)
end
```

![Imgur](http://i.imgur.com/1MiynXf.png)


The differences from `Interact` are:

* the additional control `out=:plot` creates an output widget for the
* graphic to be displayed Displaying to the output widget is not
  implicit, rather one "pushes" (`push!(out, p)`) to is. In the above
  command, this call renders the `Winston` graphic.

For textual output, a similar `out=:text` can be used, as in:

```
using GtkInteract
using SymPy
x = Sym("x")
@manipulate for n=1:20, out=:text
   a = diff(sin(x^2), x, n)
   ## push!(out, a)		# looks bad
   push!(out, jprint(a))	# better
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

It requires [Gtk](https://github.com/JuliaLang/Gtk.jl). See that page for installation notes.
