# Zoom and pan

In addition to low-level canvas support, GtkReactive also provides
high-level functions to make it easier implement rubber-banding, pan,
and zoom functionality.

To illustrate these tools, let's first open a window with a drawing canvas:

```jldoctest demozoom
julia> using Gtk.ShortNames, GtkReactive, TestImages

julia> win = Window("Image");

julia> c = canvas(UserUnit);

julia> push!(win, c);
```

As explained in [A simple drawing program](@ref), the `UserUnit`
specifies that mouse pointer positions will be reported in the units
we specify, through a `set_coordinates` call below.

Now let's load an image to draw into the canvas:
```jldoctest demozoom
julia> image = testimage("lighthouse");
```

For what follows, it may be worth reminding readers that julia arrays
are indexed as `image[row, column]`, whereas for graphics we usually
think in terms of `(x, y)`. Since `x` corresponds to `column` and `y`
corresponds to `row`, some operations will require that we swap the
first and second indices.

Zoom and pan interactions all work through a [`ZoomRegion`](@ref) signal; let's
create one for this image:
```jldoctest demozoom
julia> zr = Signal(ZoomRegion(image))
1: "input" = GtkReactive.ZoomRegion{RoundingIntegers.RInt64}(XY(1..768, 1..512), XY(1..768, 1..512)) GtkReactive.ZoomRegion{RoundingIntegers.RInt64}
```

The key thing to note here is that it has been created for the
intervals `1..768` (corresponding to the width of the image) and
`1..512` (the height of the image). Let's now create a `view` of the image as a Signal:

```jldoctest demozoom
julia> imgsig = map(zr) do r
           cv = r.currentview   # extract the currently-selected region
           # Create a SubArray covering just the selected region (see `?view`)
           view(image, UnitRange{Int}(cv.y), UnitRange{Int}(cv.x))
       end;
```

`imgsig` is a Signal that holds a "sub-image," one that updates any
time `zr` is modified. We then define a `draw` method for the canvas
that paints this selection to the canvas:

```jldoctest demozoom
julia> redraw = draw(c, imgsig, zr) do cnvs, img, r
           # Copy the pixel data to the canvas. Because `img` is the value of `imgsig`,
           # this will only copy the region that was selected by the `view` call above.
           copy!(cnvs, img)

           # Here we set the coordinates of the canvas to correspond
           # to the selected region of the image. This ensures that
           # every point on the canvas has coordinates that correspond
           # to the same position in the image.
           set_coordinates(cnvs, r)
       end
Signal{Void}(nothing, nactions=0)
```

We won't need to do anything further with `redraw`, but as a reminder:
by assigning it to a variable we ensure it won't be garbage-collected
(if that happened, the canvas would stop updating when `imgsig` and/or
`zr` update).

Now, let's see our image:
```jldoctest demozoom
julia> showall(win);
```

![image1](assets/image1.png)

We could `push!` values to `zr` and see the image update:
```jldoctest demozoom
julia> push!(zr, (100:300, indices(image, 2)))
```

![image2](assets/image2.png)

More useful is to couple `zr` to mouse actions. Let's turn on both
zooming (with [`init_zoom_rubberband`](@ref)) and panning (with [`init_pan_drag`](@ref)):

```jldoctest demozoom
julia> rb = init_zoom_rubberband(c, zr)
Dict{String,Any} with 5 entries:
  "drag"    => Signal{Void}(nothing, nactions=0)
  "init"    => Signal{Void}(nothing, nactions=0)
  "active"  => Signal{Bool}(false, nactions=0)
  "finish"  => Signal{Void}(nothing, nactions=0)
  "enabled" => Signal{Bool}(true, nactions=0)

julia> pandrag = init_pan_drag(c, zr)
Dict{String,Any} with 5 entries:
  "drag"    => Signal{Void}(nothing, nactions=0)
  "init"    => Signal{Void}(nothing, nactions=0)
  "active"  => Signal{Bool}(false, nactions=0)
  "finish"  => Signal{Void}(nothing, nactions=0)
  "enabled" => Signal{Bool}(true, nactions=0)
```

Now hold down your `Ctrl` key on your keyboard, click on the image,
and drag to select a region of interest. You should see the image zoom
in on that region. Then try clicking your mouse (without holding
`Ctrl`) and drag; the image will move around, following your
mouse. Double-click on the image while holding down `Ctrl` to zoom out
to full view. The use of these modifier keys can be customized through
keyword arguments to `init_zoom_rubberband` and `init_pan_drag`.

The returned dictionaries have a number of signals necessary for
internal operations. Perhaps the only important user-level element is
`enabled`; if you `push!(rb["enabled"], false)` then you can
(temporarily) turn off rubber-band initiation.

If you have a wheel mouse, you can activate additional interactions
with [`init_zoom_scroll`](@ref) and [`init_pan_scroll`](@ref).
