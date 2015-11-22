
## We follow Escher layout here
immutable Length{unit}
    value::Float64
end



abstract Layout
abstract LayoutAttribute <: Layout

immutable Size <: LayoutAttribute
    tile
    w_prefix
    h_prefix
    w_px::Length
    h_px::Length
end

Base.size(w::Int, h::Int, lyt::Layout) = Size(lyt, "", "", Length{:px}(w), Length{:px}(h))
Base.size(w::Int, h::Int) = lyt -> size(w, h, lyt)

"Width of widget"
function width(prefix::AbstractString, px::Int, lyt::Layout)
    Size(lyt, prefix, "", Length{:px}(px), Length{:px}(-1))
end
width(prefix::AbstractString, px::Int) = lyt -> width(prefix, px, lyt)
width(px::Int, w) = width("", px, w)
width(px::Int) = w -> width(px, w)
#minwidth(w, x...) = width("min", w, x...)
#maxwidth(w, x...) = width("max", w, x...)

"Height of widget"
function height(prefix::AbstractString, px::Int, lyt::Layout)
    Size(lyt, "", prefix, Length{:px}(-1), Length{:px}(px))
end
height(prefix::AbstractString, px::Int) = lyt -> height(prefix, px, lyt)
height(px::Int, w) = height("", px, w)
height(px::Int) = w -> height(px, w)
#minheight(w, x...) = height("min", w, x...)
#maxheight(w, x...) = height("max", w, x...)


vksip(y, lyt::Layout) = size(0, y, lyt)
vskip(y) = lyt -> vskip(y, lyt)
hskip(y, lyt::Layout) = size(y, 0, lyt)
hskip(y) = lyt -> hskip(y, lyt)

## flex
immutable Grow <: LayoutAttribute
    tile
    factor
end
## factor in [0,1]
grow(factor::Real, tile) = Grow(tile, factor)
grow(factor::Real) = tile -> grow(factor, tile)
grow(tile) = grow(1.0, tile)

immutable Shrink <: LayoutAttribute
    tile
    factor
end
## factor in [0,1]
shrink(factor::Real, tile) = Shrink(tile, factor)
shrink(factor::Real) = tile -> shrink(factor, tile)
shrink(tile) = shrink(1.0, tile)

immutable Flex <: LayoutAttribute
    tile
    factor
end
## factor in [0,1]
flex(factor::Real, tile) = Flex(tile, factor)
flex(factor::Real) = tile -> flex(factor, tile)
flex(tile) = flex(1.0, tile)


## alignment
Alignments =Dict(:fill      => Gtk.GConstants.GtkAlign.FILL,
                 :axisstart => Gtk.GConstants.GtkAlign.START,
                 :start     => Gtk.GConstants.GtkAlign.START,
                 :axisend   => Gtk.GConstants.GtkAlign.END,
                 :end       => Gtk.GConstants.GtkAlign.END,
                 :center    => Gtk.GConstants.GtkAlign.CENTER,
                 :baseline  => Gtk.GConstants.GtkAlign.BASELINE)

immutable Align <: LayoutAttribute
    tile
    halign
    valign
end

align(h::Symbol, v::Symbol, lyt) = Align(lyt, Alignments[h], Alignments[v])
align(h::Symbol, v::Symbol) = lyt -> align(h, v, lyt)
halign(a::Symbol, lyt) = align(a, :fill, lyt)
halign(a::Symbol) = lyt -> halign(a, lyt)
valign(a::Symbol, lyt) = align(:fill, a, lyt)
valign(a::Symbol) = lyt -> valign(a, lyt)


## padding
immutable Pad <: LayoutAttribute
    tile
    sides
    len::Length
end
## what to put for sides?
padcontent(len, tile, sides=[:left, :right, :top, :bottom]) = Pad(tile, sides, Length{:px}(len))

paad(len::Int, widget) = padcontent(len, widget)
paad(len::Int) = widget -> pad(len, widget)
paad(sides::AbstractVector, len, tile) =
    padcontent(sides, len, Container(tile))

## Boxes
type FlowContainer <: Layout
    obj
    direction
    children
end

" vertical box"
vbox(children...) = FlowContainer(nothing, "vertical", [children...])
hbox(children...) = FlowContainer(nothing, "horizontal", [children...])


## Separator
immutable Separator <: Layout
    orient
end
separator(orient::Symbol=:horizontal) = Separator(orient)

## Tabs...
immutable Tabs <: Layout
    children
    labels
    initial::Int
end

## Tabs are a bit different than Escher
## We use pairs to label children
##
## tabs("label"=>tile, "label1"=>tile, ...; selected=1)
##
function tabs(tiles...; selected::Int=1)
    labels = [label for (label, child) in tiles]
    children = [child for (label, child) in tiles]
    Tabs(children, labels, selected)
end


type Window <: Layout
    title
    children
end

## """
## A parentless container, like MainWindow, but less fuss.
##
## Children are packed into a `vbox`.
##
## """
window(children...; title::AbstractString="") = Window(title, [children...])
window(;kwargs...) = tile -> window(tile; kwargs...)

