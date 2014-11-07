using GtkInteract
using Winston

## Manipulate can display text output in a label
@manipulate for n=1:10, x=1:10
   (n,x)
end

## Similary, a plot can be made
## (It is important the `Winston` have the `:gtk` output type, which may be achieved
## by loading `GtkInteract` first).
@manipulate for n=1:10
    plot(sin, 0, n*pi)
end


## Unicode works, as does passing along functions through Options.
@manipulate for ϕ = 0:π/16:4π, f = [:sin => sin, :cos => cos]
   plot(x -> f(x + ϕ), 0, pi)
end
    

## Can use oplot for adding layers
@manipulate for n=1:10
    plot(sin, 0, n*pi)
    oplot(cos, 0, n*pi, "b")
end

## and we can combine (mimicing an example from Interact)
@manipulate for ϕ = 0:π/16:4π, f = [:sin => sin, :cos => cos], both = false
    if both
        plot(θ -> sin(θ + ϕ), 0, 8)
	oplot(θ -> cos(θ + ϕ), 0, 8, "b")
    else
       plot(θ -> f(θ + ϕ), 0, 8)
    end
end


## can use lower level Winston commands
@manipulate for n=1.0:0.1:5.0, m=1.0:0.1:5.0
    t = linspace(0, 2pi, 1000)
    xs = map(x -> sin(n*pi*x), t)
    ys = map(x -> cos(m*pi*x), t)
    p = Winston.FramedPlot(title="parametric")
    Winston.add(p, Winston.Curve(xs, ys))
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
    SymPy.latex(a)
    jprint(a)
end

## The label can be replaced by a multiline text buffer. The syntax is
## a bit awkward.  output widgets have values `push!`ed onto them and a final
## value of `nothing` is used.
@manipulate for n=1:10, x=1:10, out=:text
    push!(out, (n,x))
    nothing
end




## Control widgets can be used instead of their being derived from the argument. This
## gives some flexibility and allows the labels to be different than the variable
## name associated with the control.
@manipulate for rb=radiobuttons([1,2,3],label="rb"), cb=checkbox(true, label="checkbox")
    (rb, cb)
end


## An example of @vchuravy from https://github.com/JuliaLang/Interact.jl/issues/36
using Distributions, Winston
@manipulate for α in 1:100, β = 1:100
    plot(x -> pdf(Beta(α, β), x), 0, 1)
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


