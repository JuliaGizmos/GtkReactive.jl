using GtkReactive
using Plots
backend(:immerse)

## Manipulate can display text output in a label
@manipulate for n=1:10, x=1:10
   (n,x)
end

## Similary, a plot can be made. Here we use Immerse through Plots:
@manipulate for n=1:10
    plot(sin, 0, n*pi)
end


## Unicode works, as does passing along functions through Options.
@manipulate for ϕ = 0:π/16:4π, f = Dict(:sin => sin, :cos => cos)
   plot(x -> f(x + ϕ), 0, pi)
end
    

## Can use plot! for adding layers
@manipulate for n=1:10
    plot(sin, 0, n*pi)
    plot!(cos, 0, n*pi, color=:red)
end

## and we can combine (mimicing an example from Interact)
@manipulate for ϕ = 0:π/16:4π, f = Dict(:sin => sin, :cos => cos), both = false
    if both
        plot(θ -> sin(θ + ϕ), 0, 8)
	plot!(θ -> cos(θ + ϕ), 0, 8, color=:red)
    else
       plot(θ -> f(θ + ϕ), 0, 8)
    end
end

## immerse works as directly, as well. In this case, the immerse toolbar is available:

using Immerse
@manipulate for n=1:10
    Immerse.plot(x=rand(n*10), y=rand(n*10))
end


# Text output
## The basic text output uses a label.
## This allows for some PANGO markup
## (https://developer.gnome.org/pango/stable/PangoMarkupFormat.html)
@manipulate for n = 1:20
    x = n > 10 ? "<b>$n</b>" : string(n)
    "The value is $x"
end


## Sadly, no latex output widget. So this example fails to render nicely
using SymPy
x = Sym("x")
@manipulate for n=1:10
    a = diff(sin(x^2), x, n)
    a
    jprint(a)
end

# Output widgets

## There are controls for gathering input, and output widgets for display. These consist of
## cairographic, textarea, label, and progress
## These values are `push!`ed onto within the function call. The function call should return `nothing`,
## else the output will be displayed as well in either a label or plot container.

## The label can be replaced by a multiline text buffer. The syntax is
## a bit awkward.  output widgets have values `push!`ed onto them and a final
## value of `nothing` is used.
@manipulate for n=1:10, x=1:10, out=textarea()
    push!(out, (n,x))
    nothing
end

## The progres bar is another output widget
@manipulate for n=1:100, pb=progress()
    push!(pb, n)
    nothing
end

## We can have more than one output widget
@manipulate for n=1:10, cg1=cairographic(width=300, height=200), cg2=cairographic(width=300, height=200)
    push!(cg1, Plots.plot(cos, 0, n*pi))
    push!(cg2, Plots.plot(sin, 0, n*pi))
    nothing
end


## Control widgets can be used instead of their being derived from the argument. This
## gives some flexibility and allows the labels to be different than the variable
## name associated with the control.
@manipulate for rb=radiobuttons([1,2,3],label="rb"), cb=checkbox(true, label="checkbox")
    (rb, cb)
end


## An example of @vchuravy from https://github.com/JuliaLang/Interact.jl/issues/36
using Distributions
@manipulate for α in 1:100, β = 1:100
    Plots.plot(x -> pdf(Beta(α, β), x), 0, 1)
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


