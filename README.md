# GtkInteract

[![Build Status](https://travis-ci.org/jverzani/GtkInteract.jl.svg?branch=master)](https://travis-ci.org/jverzani/GtkInteract.jl)

The `Interact` package brings interactive widgets to `IJulia`
notebooks. In particular, the `@manipulate` macro makes it trivial to
define simple interactive graphics.

This package provides a similar `@manipulate` macro using `Gtk` for
the widget toolkit, allowing similarly easy interactive graphics with
Winston. The basic syntax is *almost* the same:

```
using GtkInteract
using Winston
@manipulate for ϕ = 0:π/16:4π, f = [:sin => sin, :cos => cos], out=:plot
	    p = plot(x -> f(x + ϕ), 0, 2pi)
	    push!(out, p)
end
```

The differences from `Interact` are:

* the additional control `out=:plot` creates a place for the graphic to be displayed 
* the `push!(out, p)` causes the `Winston` graphic to be displayed.

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
n = slider(1:10, label="n"); push!(w, n)
m = slider(11:20, label="m"); push!(w, m)
cg = cairographic(); push!(w, cg)

@lift push!(cg, plot(sin, n*pi, m*pi))
```
