using GtkReactive, Gtk.ShortNames, IntervalSets
using Base.Test

try
    Reactive.stop()
catch
end

rr() = (Reactive.run_till_now(); yield())

counter = 0

@testset "Widgets" begin
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

    ## checkbox
    w = Window("Checkbox")
    check = checkbox(label="click me")
    push!(w, check)
    showall(w)
    @test value(signal(check)) == false
    @test Gtk.G_.active(check.widget) == false
    push!(signal(check), true)
    rr()
    @test value(signal(check))
    @test Gtk.G_.active(check.widget)
    destroy(w)

    ## togglebutton
    w = Window("Togglebutton")
    tgl = togglebutton(label="click me")
    push!(w, tgl)
    showall(w)
    @test value(signal(tgl)) == false
    @test Gtk.G_.active(tgl.widget) == false
    push!(signal(tgl), true)
    rr()
    @test value(signal(tgl))
    @test Gtk.G_.active(tgl.widget)
    destroy(w)

    ## textbox (aka Entry)
    txt = textbox("Type something")
    num = textbox(5, range=1:10)
    win = Window("Textboxes") |> (bx = Box(:h))
    push!(bx, txt)
    push!(bx, num)
    showall(win)
    @test getproperty(txt.widget, :text, String) == "Type something"
    push!(signal(txt), "ok")
    rr()
    @test getproperty(txt.widget, :text, String) == "ok"
    @test getproperty(num.widget, :text, String) == "5"
    push!(signal(num), 11, (sig, val, capex) -> throw(capex.ex))
    @test_throws ArgumentError rr()
    push!(signal(num), 8)
    rr()
    @test getproperty(num.widget, :text, String) == "8"
    destroy(win)

    ## textarea (aka TextView)
    v = textarea("Type something longer")
    win = Window(v.widget)
    showall(win)
    @test value(signal(v)) == "Type something longer"
    push!(signal(v), "ok")
    rr()
    @test getproperty(Gtk.G_.buffer(v.widget), :text, String) == "ok"
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

    ## dropdown
    dd = dropdown(("Strawberry", "Vanilla", "Chocolate"))
    @test value(dd) == "Strawberry"
    push!(signal(dd), "Chocolate")
    rr()
    @test getproperty(dd.widget, :active, Int) == 2
    destroy(dd.widget)

    r = Ref(0)
    dd = dropdown(["Five"=>x->x[]=5, "Seven"=>x->x[]=7])
    map(f->f(r), dd.mappedsignal)
    rr()
    @test value(dd) == "Five"
    @test r[] == 5
    push!(signal(dd), "Seven")
    rr()
    @test value(dd) == "Seven"
    @test r[] == 7
    push!(signal(dd), "Five")
    rr()
    @test r[] == 5
    destroy(dd.widget)
end

@testset "Compound widgets" begin
    ## player widget
    s = Signal(1)
    p = player(s, 1:8)
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
end

@testset "Canvas" begin
    c = canvas(208, 207)
    win = Window(c)
    showall(win)
    sleep(0.1)
    @test Graphics.width(c) == 208
    @test Graphics.height(c) == 207
    @test isa(c, GtkReactive.Canvas{DeviceUnit})
    destroy(win)
    c = canvas(UserUnit, 208, 207)
    win = Window(c)
    showall(win)
    sleep(0.1)
    @test isa(c, GtkReactive.Canvas{UserUnit})
    set_coords(c, BoundingBox(0, 1, 0, 1))
    corner_dev = (DeviceUnit(208), DeviceUnit(207))
    corner_usr = (UserUnit(1), UserUnit(1))
    @test GtkReactive.convertunits(UserUnit, c, corner_dev...) == corner_usr
    @test GtkReactive.convertunits(DeviceUnit, c, corner_dev...) == corner_dev
    @test GtkReactive.convertunits(UserUnit, c, corner_usr...) == corner_usr
    @test GtkReactive.convertunits(DeviceUnit, c, corner_usr...) == corner_dev
    destroy(win)
end

@testset "Zoom/pan" begin
    zr = GtkReactive.ZoomRegion((1:100, 1:80))
    zrz = GtkReactive.zoom(zr, 0.5)
    @test zrz.currentview.x == 26..75
    @test zrz.currentview.y == 21..60
    zrp = GtkReactive.pan_x(zrz, 0.2)
    @test zrp.currentview.x == 36..85
    @test zrp.currentview.y == 21..60
    zrp = GtkReactive.pan_x(zrz, -0.2)
    @test zrp.currentview.x == 16..65
    @test zrp.currentview.y == 21..60
    zrp = GtkReactive.pan_y(zrz, -0.2)
    @test zrp.currentview.x == 26..75
    @test zrp.currentview.y == 13..52
    zrp = GtkReactive.pan_y(zrz, 0.2)
    @test zrp.currentview.x == 26..75
    @test zrp.currentview.y == 29..68
    zrp = GtkReactive.pan_x(zrz, 1.0)
    @test zrp.currentview.x == 51..100
    @test zrp.currentview.y == 21..60
    zrp = GtkReactive.pan_y(zrz, -1.0)
    @test zrp.currentview.x == 26..75
    @test zrp.currentview.y == 1..40
    zrz2 = GtkReactive.zoom(zrz, 2.0001)
    @test zrz2 == zr
    zrz2 = GtkReactive.zoom(zrz, 3)
    @test zrz2 == zr
    zrz2 = GtkReactive.zoom(zrz, 1.9)
    @test zrz2.currentview.x == 4..97
    @test zrz2.currentview.y == 3..78
    zrz = GtkReactive.zoom(zr, 0.5, GtkReactive.MousePosition{DeviceUnit}(50.5, 40.5))
    @test zrz.currentview.x == 26..75
    @test zrz.currentview.y == 21..60
    zrz = GtkReactive.zoom(zr, 0.5, GtkReactive.MousePosition{DeviceUnit}(60.5, 30.5))
    @test zrz.currentview.x == 31..80
    @test zrz.currentview.y == 16..55
    zrr = GtkReactive.reset(zrz)
    @test zrr == zr
end

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
