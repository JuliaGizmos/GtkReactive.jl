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


## An example by @stevengj (https://github.com/JuliaLang/Interact.jl/issues/36)

# n steps of Newton iteration for sqrt(a), starting at x
function newton(a, x, n)
    for i = 1:n
        x = 0.5 * (x + a/x)
    end
    return x
end

# output x as HTML, with digits matching x0 printed in bold
function matchdigits(x::Number, x0::Number)
    s = string(x)
    s0 = string(x0)
    buf = IOBuffer()
    matches = true
    i = 0
    print(buf, "<b>")           # pango <b> matches HTML
    while (i += 1) <= length(s)
        i % 30 == 0 && print(buf, "\n") # not <br>
        if matches && i <= length(s0) && isdigit(s[i])
            if s[i] == s0[i]
                print(buf, s[i])
                continue
            end
            print(buf, "</b>")
            matches = false
        end
        print(buf, s[i])
    end
    matches && print(buf, "</b>")
    takebuf_string(buf)
end

set_bigfloat_precision(1024)
sqrt2 = sqrt(big(2))

@manipulate for l=label("Number of steps"), n = slider(0:9, value=0, label="n")
   matchdigits(newton(big(2), 2, n), sqrt2)
end


