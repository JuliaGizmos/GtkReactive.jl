using GtkReactive, Gtk.ShortNames
using Base.Test

try
    Reactive.stop()
catch
end

rr() = (Reactive.run_till_now(); yield())

## label
l = label("Hello")
@test getproperty(l.widget, :label, String) == "Hello"
push!(signal(l), "world")
rr()
@test getproperty(l.widget, :label, String) == "world"

## button
w = Window("Widgets")
b = button("Click me")
push!(w, b)
counter = 0
action = map(b) do val
    global counter
    counter::Int += 1
end
rr()
cc = counter  # map seems to fire it once, so record the "new" initial value
click(b::GtkReactive.Button) = ccall((:gtk_button_clicked,Gtk.libgtk),Void,(Ptr{Gtk.GObject},),b.widget)
click(b)
rr()
@test counter == cc+1
destroy(w)

## textbox (aka Entry)
txt = textbox("Type something")
num = textbox(5, range=1:10)
win = Window("Textboxes") |> (bx = Box(:h))
push!(bx, txt)
push!(bx, num)
showall(win)
destroy(win)

## slider
s = slider(1:15)
sleep(0.01)    # For the Gtk eventloop
@test value(s) == 8
push!(signal(s), 3)
rr()
@test value(s) == 3

# Use a single signal for two widgets
s2 = slider(1:15, signal=signal(s), orientation='v')
@test value(s2) == 3
push!(signal(s2), 11)
rr()
@test value(s) == 11
destroy(s2)
destroy(s)

# player widget
s = CheckedSignal(1, 1:8)
p = player(s)
win = Window(frame(p))
showall(win)
rr()
btn_fwd = p.widget.step_forward
@test value(s) == 1
push!(signal(btn_fwd), nothing)
sleep(0.01)
rr()
sleep(0.01)
@test value(s) == 2
destroy(win)

nothing

# ## test manipulate
# @manipulate for n=1:10
#     n
# end



# ## tests widgets
# opts = ["one", "two", "three"]
# # write your own tests here
# sl = slider(1:10)         # one from range
# cb = checkbox(true, label="check")      # bool
# tb = togglebutton(true, label="toggle") # bool
# dd = dropdown(opts)       # 1 of n
# rbs = radiobuttons(opts)  # 1 of n
# sel = selectlist(opts, label="select")        # 1 of n
# tbs = togglebuttons(opts) # 1 of n
# bg = buttongroup(opts)    # 0,1,...,n of n
# txtb = textbox("text goes here", label="textbox")

# btn = button("button")
# out = label()

# controls = [sl, cb, tb, dd, rbs,  tbs, bg, sel, txtb]

# w = window(vbox(controls...),
#            hbox(halign(:end,padding(10, btn))),
#            out)


# ## using Reactive
# Reactive.foreach([x.signal for x in controls]...) do sl, cb, tb, dd, rbs, tbs, bg, sel, txtb
#     push!(out, """
#           $(string(sl))
#           $(string(cb))
#           $(string(tb))
#           $(string(dd))
#           $(string(rbs))
#           $(string(tbs))
#           $(string(bg))
#           $(string(sel))
#           $(string(txtb))

#           """)
# end

# # test numeric-valued textboxes
# using Gtk, Interact
# w = mainwindow()
# b = textbox(1)
# push!(w, b)
# display(w)
# g = first(w.window)
# widget = first(g)
# setproperty!(widget, :text, "2")
# @test value(signal(b)) == 1
# signal_emit(widget, :activate, Void)
# sleep(0.1)
# @test value(signal(b)) == 2

# # Images
# using TestImages, Colors
# w = mainwindow()
# img = testimage("mandrill")
# renderbuffer = convert(Matrix{RGB24}, img.data)
# surf = cairoimagesurface(renderbuffer)
# # Gtk.present(w.window)
# push!(w, grow(surf))
# display(w)
# img = testimage("cameraman")
# sleep(1)
# push!(surf, img)

# # Cleanup of signals (especially ones that run constantly!)
# using Reactive
# frametimer = fps(10)
# w = mainwindow()
# push!(w.refs, frametimer)
# display(w)
# @test frametimer.alive == true
# destroy(w)
# yield()
# @test frametimer.alive == false
