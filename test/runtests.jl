using GtkReactive, Gtk.ShortNames, IntervalSets, Graphics, Colors,
      TestImages, FileIO, FixedPointNumbers, RoundingIntegers
using Base.Test

if !istaskdone(Reactive.runner_task)
    Reactive.stop()
    wait(Reactive.runner_task)
end

include("tools.jl")

@testset "Widgets" begin
    ## label
    l = label("Hello")
    @test signal(l) == l.signal
    @test signal(signal(l)) == l.signal
    @test getproperty(l, :label, String) == "Hello"
    push!(signal(l), "world")
    rr()
    @test getproperty(l, :label, String) == "world"
    @test string(l) == string("Gtk.GtkLabelLeaf with ", string(signal(l)))
    # map with keywords
    lsig0 = map(l) do lbl  # "regular" map runs the function
        lbl
    end
    rr()
    @test value(lsig0) == "world"
    lsig = map(l; init="foo") do lbl   # with "init", you avoid running
        lbl
    end
    rr()
    @test value(lsig) == "foo"
    push!(l, "bar")
    rr()
    @test value(lsig) == "bar"

    ## checkbox
    w = Window("Checkbox")
    check = checkbox(label="click me")
    push!(w, check)
    showall(w)
    @test value(check) == false
    @test Gtk.G_.active(check.widget) == false
    push!(check, true)
    rr()
    @test value(check)
    @test Gtk.G_.active(check.widget)
    destroy(w)

    ## togglebutton
    w = Window("Togglebutton")
    tgl = togglebutton(label="click me")
    push!(w, tgl)
    showall(w)
    @test value(tgl) == false
    @test Gtk.G_.active(tgl.widget) == false
    push!(tgl, true)
    rr()
    @test value(tgl)
    @test Gtk.G_.active(tgl.widget)
    destroy(w)

    ## textbox (aka Entry)
    txt = textbox("Type something")
    num = textbox(5, range=1:10)
    win = Window("Textboxes") |> (bx = Box(:h))
    push!(bx, txt)
    push!(bx, num)
    showall(win)
    @test getproperty(txt, :text, String) == "Type something"
    push!(txt, "ok")
    rr()
    @test getproperty(txt, :text, String) == "ok"
    setproperty!(txt, :text, "other direction")
    signal_emit(widget(txt), :activate, Void)
    rr()
    @test value(txt) == "other direction"
    @test getproperty(num, :text, String) == "5"
    push!(signal(num), 11, (sig, val, osig, capex) -> throw(capex.ex))
    @test_throws ArgumentError rr()
    push!(num, 8)
    rr()
    @test getproperty(num, :text, String) == "8"
    meld = map(txt, num) do t, n
        join((t, n), 'X')
    end
    rr()
    @test value(meld) == "other directionX8"
    push!(num, 4)
    rr()
    @test value(meld) == "other directionX4"
    push!(txt, "4")
    rr()
    @test value(meld) == "4X4"
    destroy(win)

    ## textarea (aka TextView)
    v = textarea("Type something longer")
    win = Window(v)
    showall(win)
    @test value(v) == "Type something longer"
    push!(v, "ok")
    rr()
    @test getproperty(Gtk.G_.buffer(v.widget), :text, String) == "ok"
    destroy(win)

    ## slider
    s = slider(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test value(s) == 8
    push!(s, 3)
    rr()
    @test value(s) == 3

    # Use a single signal for two widgets
    s2 = slider(1:15, signal=signal(s), orientation='v')
    @test value(s2) == 3
    push!(s2, 11)
    rr()
    @test value(s) == 11
    destroy(s2)
    destroy(s)

    # Updating the limits of the slider
    s = slider(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test value(s) == 8
    push!(s, 1:7, 5)
    sleep(0.01)
    rr()
    @test value(s) == 5

    ## dropdown
    dd = dropdown(("Strawberry", "Vanilla", "Chocolate"))
    @test value(dd) == "Strawberry"
    push!(dd, "Chocolate")
    rr()
    @test getproperty(dd, :active, Int) == 2
    destroy(dd.widget)

    r = Ref(0)
    dd = dropdown(["Five"=>x->x[]=5,
                   "Seven"=>x->x[]=7])
    ddsig = map(f->f(r), dd.mappedsignal)
    rr()
    @test value(dd) == "Five"
    @test r[] == 5
    push!(dd, "Seven")
    run_till_empty()
    @test value(dd) == "Seven"
    @test r[] == 7
    push!(dd, "Five")
    rr()
    @test r[] == 5
    destroy(dd.widget)

    ## spinbutton
    s = spinbutton(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test value(s) == 1
    push!(s, 3)
    rr()
    @test value(s) == 3
    destroy(s)

    s = spinbutton(0:59, orientation="vertical")
    @test G_.orientation(Orientable(widget(s))) == Gtk.GConstants.GtkOrientation.VERTICAL
    destroy(s)

    # Updating the limits of the spinbutton
    s = spinbutton(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test value(s) == 1
    push!(s, 1:7, 5)
    rr()
    @test value(s) == 5

end

## button
# For reasons I don't understand, this often fails if it's inside a @testset
counter = 0

w = Window("Widgets")
b = button("Click me")
push!(w, b)
action = map(b) do val
    global counter
    counter::Int += 1
end
showall(w)
rr()
cc = counter  # map seems to fire it once, so record the "new" initial value
click(b::GtkReactive.Button) = ccall((:gtk_button_clicked,Gtk.libgtk),Void,(Ptr{Gtk.GObject},),b.widget)
gc(true)
click(b)
rr()
@test counter == cc+1
destroy(w)

# Make sure we can also put a ToolButton in a Button
button(; widget=ToolButton("Save as..."))

if Gtk.libgtk_version >= v"3.10"
    # To support GtkBuilder, we need this as the minimum libgtk version
    @testset "Compound widgets" begin
        ## player widget
        s = Signal(1)
        p = player(s, 1:8)
        win = Window() |> (g = Grid())
        g[1,1] = p
        showall(win)
        rr()
        btn_fwd = p.widget.step_forward
        @test value(s) == 1
        push!(btn_fwd, nothing)
        run_till_empty()
        @test value(s) == 2
        push!(p.widget.play_forward, nothing)
        for i = 1:7
            run_till_empty()
            sleep(0.1)
        end
        @test value(s) == 8
        destroy(win)

        p = player(1:1000)
        win = Window(frame(p))
        showall(win)
        push!(widget(p).direction, 1)
        destroy(win)  # this should not generate a lot of output
    end
end

@testset "CairoUnits" begin
    x = UserUnit(0.2)
    @test x+x === UserUnit(0.2+0.2)
    @test x-x === UserUnit(0.0)
    y = UserUnit(-0.3)
    @test abs(x) === x
    @test abs(y) === UserUnit(0.3)
    @test min(x, y) === y
    @test max(x, y) === x
    z = DeviceUnit(2.0)
    @test_throws ErrorException x+z
end

@testset "Canvas" begin
    @test XY(5, 5) === XY{Int}(5, 5)
    @test XY(5, 5.0) === XY{Float64}(5.0, 5.0)
    @test XY{UserUnit}(5, 5.0) === XY{UserUnit}(5.0, 5.0) === XY{UserUnit}(UserUnit(5), UserUnit(5))

    @test isa(MouseButton{UserUnit}(), MouseButton{UserUnit})
    @test isa(MouseButton{DeviceUnit}(), MouseButton{DeviceUnit})
    @test isa(MouseScroll{UserUnit}(), MouseScroll{UserUnit})
    @test isa(MouseScroll{DeviceUnit}(), MouseScroll{DeviceUnit})

    @test BoundingBox(XY(2..4, -15..15)) === BoundingBox(2, 4, -15, 15)

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
    reveal(c, true)
    sleep(0.3)
    @test isa(c, GtkReactive.Canvas{UserUnit})
    corner_dev = (DeviceUnit(208), DeviceUnit(207))
    for (coords, corner_usr) in ((BoundingBox(0, 1, 0, 1), (UserUnit(1), UserUnit(1))),
                                 (ZoomRegion((5:10, 3:5)), (UserUnit(5), UserUnit(10))),
                                 ((-1:1, 101:110), (UserUnit(110), UserUnit(1))))
        set_coordinates(c, coords)
        @test GtkReactive.convertunits(UserUnit, c, corner_dev...) == corner_usr
        @test GtkReactive.convertunits(DeviceUnit, c, corner_dev...) == corner_dev
        @test GtkReactive.convertunits(UserUnit, c, corner_usr...) == corner_usr
        @test GtkReactive.convertunits(DeviceUnit, c, corner_usr...) == corner_dev
    end

    destroy(win)


    c = canvas()
    f = Frame(c)
    @test isa(f, Gtk.GtkFrameLeaf)
    destroy(f)
    c = canvas()
    f = AspectFrame(c, "Some title", 0.5, 0.5, 3.0)
    @test isa(f, Gtk.GtkAspectFrameLeaf)
    @test getproperty(f, :ratio, Float64) == 3.0
    destroy(f)
end

# @testset "Canvas events" begin
    win = Window() |> (c = canvas(UserUnit))
    showall(win)
    sleep(0.2)
    lastevent = Ref("nothing")
    press   = map(btn->lastevent[] = "press",   c.mouse.buttonpress)
    release = map(btn->lastevent[] = "release", c.mouse.buttonrelease)
    motion  = map(btn->lastevent[] = string("motion to ", btn.position.x, ", ", btn.position.y),
                  c.mouse.motion)
    scroll  = map(btn->lastevent[] = "scroll", c.mouse.scroll)
    rr()
    lastevent[] = "nothing"
    @test lastevent[] == "nothing"
    signal_emit(widget(c), "button-press-event", Bool, eventbutton(c, BUTTON_PRESS, 1))
    sleep(0.1)
    rr()
    @test lastevent[] == "press"
    signal_emit(widget(c), "button-release-event", Bool, eventbutton(c, GtkReactive.BUTTON_RELEASE, 1))
    sleep(0.1)
    rr()
    sleep(0.1)
    rr()
    @test lastevent[] == "release"
    signal_emit(widget(c), "scroll-event", Bool, eventscroll(c, UP))
    sleep(0.1)
    rr()
    sleep(0.1)
    rr()
    @test lastevent[] == "scroll"
    signal_emit(widget(c), "motion-notify-event", Bool, eventmotion(c, 0, UserUnit(20), UserUnit(15)))
    sleep(0.1)
    rr()
    sleep(0.1)
    rr()
    @test lastevent[] == "motion to UserUnit(20.0), UserUnit(15.0)"
    destroy(win)
# end

@testset "Popup" begin
    popupmenu = Menu()
    popupitem = MenuItem("Popup menu...")
    push!(popupmenu, popupitem)
    showall(popupmenu)
    win = Window() |> (c = canvas())
    popuptriggered = Ref(false)
    push!(c.preserved, map(c.mouse.buttonpress) do btn
        if btn.button == 3 && btn.clicktype == BUTTON_PRESS
            popup(popupmenu, btn.gtkevent)  # use the raw Gtk event
            popuptriggered[] = true
            nothing
        end
    end)
    yield()
    @test !popuptriggered[]
    evt = eventbutton(c, BUTTON_PRESS, 1)
    signal_emit(widget(c), "button-press-event", Bool, evt)
    yield()
    @test !popuptriggered[]
    evt = eventbutton(c, BUTTON_PRESS, 3)
    signal_emit(widget(c), "button-press-event", Bool, evt)
    run_till_empty()
    @test popuptriggered[]
    destroy(win)
    destroy(popupmenu)
end

@testset "Drawing" begin
    img = testimage("lighthouse")
    c = canvas(UserUnit, size(img, 2), size(img, 1))
    win = Window(c)
    xsig, ysig = Signal(20), Signal(20)
    draw(c, xsig, ysig) do cnvs, x, y
        copy!(c, img)
        ctx = getgc(cnvs)
        set_source(ctx, colorant"red")
        set_line_width(ctx, 2)
        circle(ctx, x, y, 5)
        stroke(ctx)
    end
    showall(win)
    rr()
    push!(xsig, 100)
    rr()
    sleep(1)
    # Check that we get the right answer
    fn = tempname()
    Cairo.write_to_png(getgc(c).surface, fn)
    imgout = load(fn)
    rm(fn)
    @test imgout[25,100] == imgout[16,100] == imgout[20,105] == colorant"red"
    @test imgout[20,100] == img[20,100]
    destroy(win)
end

# For testing ZoomRegion support for non-AbstractArray objects
immutable Foo end
Base.indices(::Foo) = (Base.OneTo(7), Base.OneTo(9))

@testset "Zoom/pan" begin
    @test string(UserUnit(3)) == "UserUnit(3.0)"
    @test string(DeviceUnit(3)) == "DeviceUnit(3.0)"

    xy = @inferred(XY(1, 3))
    @test isa(xy, XY{Int})
    @test xy.x == 1
    @test xy.y == 3
    @test string(xy) == "XY(1, 3)"
    xy = @inferred(XY{Float64}(1, 3))
    @test isa(xy, XY{Float64})
    @test xy.x == 1
    @test xy.y == 3
    @test string(xy) == "XY(1.0, 3.0)"
    @test isa(convert(XY{Int}, xy), XY{Int})
    xy = XY{Float64}(3.2, 4.8)
    xyr = convert(XY{RInt}, xy)
    @test isa(xyr, XY{RInt}) && xyr.x == 3 && xyr.y == 5
    xy = XY(UserUnit(3), UserUnit(5))
    @test string(xy) == "XY{UserUnit}(3.0, 5.0)"
    @test @inferred(XY{UserUnit}(3, 5)) == xy

    zr = ZoomRegion((1:80, 1:100))  # y, x order
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
    zrz = GtkReactive.zoom(zr, 0.5, GtkReactive.XY{DeviceUnit}(50.5, 40.5))
    @test zrz.currentview.x == 26..75
    @test zrz.currentview.y == 21..60
    zrz = GtkReactive.zoom(zr, 0.5, GtkReactive.XY{DeviceUnit}(60.5, 30.5))
    @test zrz.currentview.x == 31..80
    @test zrz.currentview.y == 16..55
    zrr = GtkReactive.reset(zrz)
    @test zrr == zr

    zrbb = ZoomRegion(zr.fullview, BoundingBox(5, 15, 35, 75))
    @test zrbb.fullview === zr.fullview
    @test zrbb.currentview.x == 5..15
    @test zrbb.currentview.y == 35..75
    @test typeof(zrbb.currentview) == typeof(zr.currentview)

    zrsig = Signal(zr)
    push!(zrsig, (3:5, 4:7))
    rr()
    zr = value(zrsig)
    @test zr.fullview.y == 1..80
    @test zr.fullview.x == 1..100
    @test zr.currentview.y == 3..5
    @test zr.currentview.x == 4..7
    push!(zrsig, XY(1..2, 3..4))
    rr()
    zr = value(zrsig)
    @test zr.fullview.y == 1..80
    @test zr.fullview.x == 1..100
    @test zr.currentview.y == 3..4
    @test zr.currentview.x == 1..2

    zr = ZoomRegion(Foo())
    @test zr.fullview.y == 1..7
    @test zr.fullview.x == 1..9

    zr = ZoomRegion((1:100, 1:80), (11:20, 8:12))
    @test zr.fullview.x == 1..80
    @test zr.fullview.y == 1..100
    @test zr.currentview.x == 8..12
    @test zr.currentview.y == 11..20
    @test indices(zr) == (11:20, 8:12)
end

### Simulate the mouse clicks, etc. to trigger zoom/pan
# Again, this doesn't seem to work inside a @testset
win = Window() |> (c = canvas(UserUnit))
zr = Signal(ZoomRegion((1:11, 1:20)))
zoomrb = init_zoom_rubberband(c, zr)
zooms = init_zoom_scroll(c, zr)
pans = init_pan_scroll(c, zr)
pand = init_pan_drag(c, zr)
draw(c) do cnvs
    set_coordinates(c, value(zr))
    fill!(c, colorant"blue")
end
showall(win)
sleep(0.1)

# Zoom by rubber band
signal_emit(widget(c), "button-press-event", Bool,
            eventbutton(c, BUTTON_PRESS, 1, UserUnit(5), UserUnit(3), CONTROL))
sleep(0.1)
rr()
signal_emit(widget(c), "motion-notify-event", Bool,
            eventmotion(c, mask(1), UserUnit(10), UserUnit(4)))
sleep(0.1)
rr()
signal_emit(widget(c), "button-release-event", Bool,
            eventbutton(c, GtkReactive.BUTTON_RELEASE, 1, UserUnit(10), UserUnit(4)))
sleep(0.1)
rr()
sleep(0.1)
rr()
@test value(zr).currentview.x == 5..10
@test value(zr).currentview.y == 3..4
# Ensure that the rubber band damage has been repaired
fn = tempname()
Cairo.write_to_png(getgc(c).surface, fn)
imgout = load(fn)
rm(fn)
@test all(x->x==colorant"blue", imgout)

# Pan-drag
signal_emit(widget(c), "button-press-event", Bool,
            eventbutton(c, BUTTON_PRESS, 1, UserUnit(6), UserUnit(3), 0))
sleep(0.1)
rr()
signal_emit(widget(c), "motion-notify-event", Bool,
            eventmotion(c, mask(1), UserUnit(7), UserUnit(2)))
sleep(0.1)
rr()
sleep(0.1)
rr()
@test value(zr).currentview.x == 4..9
@test value(zr).currentview.y == 4..5

# Reset
signal_emit(widget(c), "button-press-event", Bool,
            eventbutton(c, DOUBLE_BUTTON_PRESS, 1, UserUnit(5), UserUnit(4.5), CONTROL))
sleep(0.1)
rr()
sleep(0.1)
rr()
@test value(zr).currentview.x == 1..20
@test value(zr).currentview.y == 1..11

# Zoom-scroll
signal_emit(widget(c), "scroll-event", Bool,
            eventscroll(c, UP, UserUnit(8), UserUnit(4), CONTROL))
sleep(0.1)
rr()
sleep(0.1)
rr()
@test value(zr).currentview.x == 4..14
@test value(zr).currentview.y == 2..8

# Pan-scroll
signal_emit(widget(c), "scroll-event", Bool,
            eventscroll(c, RIGHT, UserUnit(8), UserUnit(4), 0))
sleep(0.1)
rr()
sleep(0.1)
rr()
@test value(zr).currentview.x == 5..15
@test value(zr).currentview.y == 2..8

signal_emit(widget(c), "scroll-event", Bool,
            eventscroll(c, DOWN, UserUnit(8), UserUnit(4), 0))
sleep(0.1)
rr()
sleep(0.1)
rr()
@test value(zr).currentview.x == 5..15
@test value(zr).currentview.y == 3..9

destroy(win)

@testset "Surfaces" begin
    for (val, cmp) in ((0.2, Gray24(0.2)),
                       (Gray(N0f8(0.5)), Gray24(0.5)),
                       (RGB(0, 1, 0), RGB24(0, 1, 0)),
                       (RGBA(1, 0, 0.5, 0.8), ARGB32(1, 0, 0.5, 0.8)))
        surf = GtkReactive.image_surface(fill(val, 3, 5))
        @test surf.height == 3 && surf.width == 5
        @test all(x->x == reinterpret(UInt32, cmp), surf.data)
        destroy(surf)
    end
end

@testset "Layout" begin
    g = Grid()
    g[1,1] = textbox("hello")
end

# Ensure that the examples run (but the Reactive queue is stopped, so
# they won't work unless one calls `@async Reactive.run()` manually)
examplepath = joinpath(dirname(dirname(@__FILE__)), "examples")
include(joinpath(examplepath, "imageviewer.jl"))
include(joinpath(examplepath, "widgets.jl"))
include(joinpath(examplepath, "drawing.jl"))
