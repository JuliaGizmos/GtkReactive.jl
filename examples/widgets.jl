## one can use the widgets directly
## (there is no real choice for layout beyond push!)




using GtkInteract, Reactive, Winston




## This is basically what @manipulate does
w = mainwindow(title="Simple test")
n = slider(1:10, label="n"); push!(w, n)
m = slider(11:20, label="m"); push!(w, m)
cg = cairographic(); push!(w, cg)

@lift push!(cg, plot(sin, n*pi, m*pi))




## A pattern where the update only is related to a button push, and not each control
## is desired if the update is expensive to compute (With sliders it may be computed up to 4 times during the move).
w = mainwindow(title="Simple test")
n = slider(1:10, label="n"); push!(w, n)
m = slider(1:10, label="m"); push!(w, m)
btn = button("update"); push!(w, btn)

## this is really ugly... but click on the button to print the product..
lift(_ -> println(signal(n).value * signal(m).value), btn)

## This pattern -- from Shasi
## https://groups.google.com/forum/?fromgroups#!topic/julia-users/Ur5b2_dsJyA
## -- is a much nicer way to react to a button, but not other controls:

using Reactive, GtkInteract, Winston

α = slider(1:10, label="α")
β = slider(1:10, label="β")
replot = button("replot")
cg = cairographic()

## display
w = mainwindow()
append!(w, [α, β, replot, cg])

## connect 
coeffs = sampleon(replot, lift(tuple, α, β))

function draw_plot(α, β)
    push!(cg, plot(x -> α + sin(x + β), 0, 2pi))
end

@lift apply(draw_plot, coeffs)





## kitchen sink of control widgets
using DataStructures
a = OrderedDict(Symbol, Int)
a[:one]=1; a[:two] = 2; a[:three] = 3

l = Dict()
l[:slider] = slider(1:10, label="slider")
l[:button] = button("button label")
l[:checkbox] = checkbox(true, label="checkbox")
l[:togglebutton] = togglebutton(true, label="togglebutton")
l[:dropdown] = dropdown(a, label="dropdown")
l[:radiobuttons] = radiobuttons(a, label="radiobuttons")
l[:select] = Interact.select(a, label="select")
l[:togglebuttons] = togglebuttons(a, label="togglebuttons")
l[:buttongroup] = buttongroup(a, label="buttongroup") # non exclusive
l[:textbox] = textbox("text goes here", label="textbox")

w = mainwindow()
for (k,v) in l
    push!(w, v)
end

## progress bar
using GtkInteract, Reactive
w = mainwindow()
b = button("press")
pb = progress()

append!(w, [pb, b])

## need @async here to update within a call
lift(b) do _
    @async push!(pb, ifloor(100*rand()))
end


