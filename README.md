# GtkInteract

[![Build Status](https://travis-ci.org/jverzani/GtkInteract.jl.svg?branch=master)](https://travis-ci.org/jverzani/GtkInteract.jl)

The [`Interact`](https://github.com/JuliaLang/Interact.jl)  package brings interactive widgets to `IJulia`
notebooks. In particular, the `@manipulate` macro makes it trivial to
define simple interactive graphics.

This package provides a similar `@manipulate` macro using `Gtk` for
the widget toolkit, allowing similarly easy interactive graphics with
Winston. The basic syntax is the same:

```
using GtkInteract
using Winston
@manipulate for ϕ = 0:π/16:4π, f = [:sin=>sin, :cos=>cos]
    plot(θ -> f(θ + ϕ), 0, 25)
end
```

![Imgur](http://i.imgur.com/1MiynXf.png)

Text output can also be displayed:

```
using GtkInteract
using SymPy
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
