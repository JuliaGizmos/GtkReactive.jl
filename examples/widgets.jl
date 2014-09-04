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
