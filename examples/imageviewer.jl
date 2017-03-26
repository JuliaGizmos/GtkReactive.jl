using TestImages, GtkReactive, Gtk.ShortNames

img = testimage("lighthouse")

## Build the GUI (just a Window with a Canvas in it)
# UserUnit: we'll use the indices of the image as canvas coordinates
# This makes it easy to relate the position of mouse-clicks to the image
c = canvas(UserUnit)
win = Window(c)

## Region-of-interest selection
zr = Signal(ZoomRegion(img))
# Interactivity: hold down Ctrl and then click-drag to select a
# region via rubberband. It updates `zr`.
zoomsigs = init_zoom_rubberband(c, zr)
# Create a Signal containing a `view` of the image over the
# region of interest. This view will update anytime `zr` updates.
imgsig = map(zr) do r
    cv = r.currentview
    view(img, UnitRange{Int}(cv.y), UnitRange{Int}(cv.x))
end

## Turn on drawing for the canvas
# `draw`, when passed Signal(s), will cause the canvas to be updated
# whenever any of the input Signals updates. It will also redraw
# whenever the Canvas is resized.
redraw = draw(c, imgsig) do cnvs, image
    copy!(cnvs, image)
    # canvas adopts the indices of the zoom region. That way if we
    # zoom in further, we select the correct region.
    set_coordinates(cnvs, value(zr))
end

## Don't forget this!
showall(win)
