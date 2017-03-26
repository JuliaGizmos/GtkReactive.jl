# Deprecations of Graphics.set_coords that handle GtkReactive types
export set_coords
Graphics.set_coords(c::Union{GtkCanvas,Canvas}, device::BoundingBox, user::BoundingBox) =
    set_coords(getgc(c), device, user)
Graphics.set_coords(c::Union{GtkCanvas,Canvas}, user::BoundingBox) =
    set_coords(c, BoundingBox(0, Graphics.width(c), 0, Graphics.height(c)), user)
function Graphics.set_coords(c::Union{GraphicsContext,Canvas,GtkCanvas}, zr::ZoomRegion)
    xy = zr.currentview
    bb = BoundingBox(xy)
    set_coords(c, bb)
end
function Graphics.set_coords(c::Union{Canvas,GtkCanvas}, inds::Tuple{AbstractUnitRange,AbstractUnitRange})
    y, x = inds
    bb = BoundingBox(first(x), last(x), first(y), last(y))
    set_coords(c, bb)
end
