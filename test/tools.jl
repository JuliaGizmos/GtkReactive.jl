rr() = (Reactive.run_till_now(); yield())
function run_till_empty()
    while !isempty(Reactive._messages.data)
        rr()
    end
end

# Simulate user inputs
function eventbutton(c, event_type, btn, x=DeviceUnit(0), y=DeviceUnit(0), state=0)
    xd, yd = GtkReactive.convertunits(DeviceUnit, c, x, y)
    Gtk.GdkEventButton(event_type,
                       Gtk.gdk_window(widget(c)),
                       Int8(0),
                       UInt32(0),
                       Float64(xd), Float64(yd),
                       convert(Ptr{Float64},C_NULL),
                       UInt32(state),
                       UInt32(btn),
                       C_NULL,
                       0.0, 0.0)
end
function eventscroll(c, direction, x=DeviceUnit(0), y=DeviceUnit(0), state=0)
    xd, yd = GtkReactive.convertunits(DeviceUnit, c, x, y)
    Gtk.GdkEventScroll(Gtk.GdkEventType.SCROLL,
                       Gtk.gdk_window(widget(c)),
                       Int8(0),
                       UInt32(0),
                       Float64(xd), Float64(yd),
                       UInt32(state),
                       direction,
                       convert(Ptr{Float64},C_NULL),
                       0.0, 0.0,
                       0.0, 0.0)
end
function eventmotion(c, btn, x, y)
    xd, yd = GtkReactive.convertunits(DeviceUnit, c, x, y)
    Gtk.GdkEventMotion(Gtk.GdkEventType.MOTION_NOTIFY,
                       Gtk.gdk_window(widget(c)),
                       Int8(0),
                       UInt32(0),
                       Float64(xd), Float64(yd),
                       convert(Ptr{Float64},C_NULL),
                       UInt32(btn),
                       Int16(0),
                       C_NULL,
                       0.0, 0.0)
end

const ModType = Gtk.GConstants.GdkModifierType
mask(btn) =
    btn == 1 ? ModType.GDK_BUTTON1_MASK :
    btn == 2 ? ModType.GDK_BUTTON2_MASK :
    btn == 3 ? ModType.GDK_BUTTON3_MASK :
    error(btn, " not recognized")
