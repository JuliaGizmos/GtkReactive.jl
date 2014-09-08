## one can use the widgets directly
## (there is no real choice for layout beyond push!)
using Reactive, Winston

w = mainwindow(title="Simple test")
n = slider(1:10, label="n"); push!(w, n)
m = slider(1:10, label="m"); push!(w, m)
btn = button("update"); push!(w, btn)

## this is kinda ugly... but click on the button to print the product..
lift(_ -> println(signal(n).value * signal(m).value), btn)



## This is much nicer
w = mainwindow(title="Simple test")
n = slider(1:10, label="n"); push!(w, n)
m = slider(11:20, label="m"); push!(w, m)
cg = cairographic(); push!(w, cg)

@lift push!(cg, plot(sin, n*pi, m*pi))
w = mainwindow


## kitchen sink
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
