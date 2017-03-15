using TestImages, GtkReactive, Gtk.ShortNames, IdentityRanges

img = testimage("lighthouse")
zr = Signal(ZoomRegion(img))
imgsig = map(zr) do r
    cv = r.currentview
    view(img, IdentityRange(cv.y), IdentityRange(cv.x))
end
c = canvas(UserUnit)
win = Window(c)
redraw = draw(c, imgsig) do cnvs, image
    copy!(cnvs, image)
    set_coords(cnvs, indices(image))
end

showall(win)

zoomsigs = init_zoom_rubberband(c, zr)
