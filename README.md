# GtkReactive

[![Build Status](https://travis-ci.org/JuliaGizmos/GtkReactive.jl.svg?branch=master)](https://travis-ci.org/JuliaGizmos/GtkReactive.jl)

This is WIP a fork of [GtkInteract](https://github.com/jverzani/GtkInteract.jl), but aims to be different in the following ways:
- Rather than use Interact.jl (which is oriented towards Jupyter), this re-implements similar features natively
- It will not implement `@manipulate` or any plotting; it is merely designed to be a "simplified interact to Gtk widgets"

Some of the following has been retained from GtkInteract, but may or may not (yet) be relevant.

## Resource management: Signal protection and cleanup

A `MainWindow` has a field, `refs`, to which you can `push!` any
Reactive signals that you want to preserve for the lifetime of the
window. Upon destroying the window, these signals are `close`d.
Timers like `fps` are particularly important to "register" with
`refs`: otherwise, you may keep using CPU resources even after you
close the window, until the next garbage-collection event.

Example:

```jl
using GtkReactive, Reactive
frametimer = fps(10)
w = mainwindow()
push!(w.refs, frametimer)
```

Now if you `display` `w`, and then close the window, `frametimer` will
no longer be active.

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
