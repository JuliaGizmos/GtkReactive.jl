## Make a simple enough GUI to plot variables in a data frame
using GtkReactive
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

## layout toolbar with space between the items.
tb = toolbar(do_titles, vskip(),  about |> tooltip("Simple GUI"))

w = window(title="simple GUI");
b = vbox(tb);
push!(w, b)
push!(b, hbox(vbox(halign(:start, GtkReactive.bold("Select variables: ")),
                 vb,
                 halign(:start, GtkReactive.bold("Filter by: ")),
                   fb),
              cg |> grow |> padding(5)
              ))

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

## actually show GUI
display(w)

## Hook up signals

f(args...) = info("A simple GUI") #messagebox("a simple GUI")
## ## XXX THIS IS FLAKY XXX 
map(f, about)


## make update happen when a widget is updated
map(vcat(do_titles, xvar, yvar, values(factors)...)...) do args...
    make_graphic()
end



