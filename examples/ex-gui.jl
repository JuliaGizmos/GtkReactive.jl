## Make a simple enough GUI to plot variables in a data frame
using GtkInteract
using RDatasets, DataFrames
using Plots
backend(:immerse)

cars = dataset("MASS", "Cars93")
nms = names(cars)

## vartypes
nums = filter(nm -> eltype(cars[nm]) <: Number, nms) 
bools = filter(nm -> eltype(cars[nm]) <: Bool, nms)
facs = filter(nm -> isa(cars[nm], PooledDataArray), nms)
facs = setdiff(facs, [:Manufacturer])
others = setdiff(nms, vcat(nums, bools, facs))




nums = map(string, nums)
xvar = dropdown(nums, label="X variable", value_label=nums[1])
yvar = dropdown(nums, label="Y variable", value_label=nums[2])
vb = formlayout()
append!(vb, [xvar, yvar])

fb = formlayout()
factors = Dict()
for fac in facs
    levs = levels(cars[fac])
    widget = buttongroup(levs, label=string(fac), value=levs)
    factors[fac] = widget
    push!(fb, widget)
end

## A graphics device
cg = cairographic()

## show toolbar
## * a togglebutton to hold state on whether titles should be displayed
## * a button to display an "about" message
do_titles = togglebutton(value=true, label="titles?")
about = button("about")
## what to do when a button is pressed (THIS IS FLAKY!!)
map(about) do 
    messagebox("A simple GUI to explore a data set")
end
## layout toolbar with space between the items.
tb = toolbar(do_titles, vskip(),  about)

## layout main GUI
b = vbox(tb);
w = window(b, title="simple GUI");
push!(b, hbox(vbox(halign(:start, GtkInteract.bold("Select variables: ")),
                 vb,
                 halign(:start, GtkInteract.bold("Filter by: ")),
                 fb), grow(cg)))

## How to generate the graphic: first subset data, then plot
function make_graphic(args...)
    df = copy(cars)
    for fac in facs
        df = df[ Bool[val in value(factors[fac]) for val in df[fac]], :]
    end

    if size(df)[1] > 0
        xs = df[symbol(value(xvar))]
        ys = df[symbol(value(yvar))]
        p = scatter(xs, ys)
        if value(do_titles)
            plot!(p, title="Cars93", xlabel = value(xvar), ylabel=value(yvar))
        end
        push!(cg, p)
    else
        info("No cases left after selection")
    end
end

## make update happen when a widget is updated
map(vcat(xvar, yvar, values(factors)...)...) do args...
    make_graphic()
end

## show w and its children
display(w)
make_graphic()                          # initial graphic

