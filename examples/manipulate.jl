using GtkInteract
using Winston

## Manipulate can be used to display at the console.
## Note the need to call `println`, as otherwise there is no display. This is a difference
## from `Interact`.
@manipulate for n=1:10, x=1:10
    println((n,x))
end

## Similary, a plot can be made
## again, we need to call `display` to get the graphics window to open
## (It is important the `Winston` have the `:gtk` output type, which may be achieved
## by loading `GtkInteract` first).
@manipulate for n=1:10
    display(plot(sin, 0, n*pi))
end


## Output widgets
##
## In general, `GtkInteract` uses an output widget to incorprate different outputs into the GUI
## There are three: `:plot`, `:text` and `:label`. Within the expression, the `push!` function
## is used to write to the output widget.

## manipulate with a plot device can use an output widget
@manipulate for n=1:10, out = :plot
    p = plot(sin, 0, n*pi)
    push!(out, p)
end

## Unicode works, as does passing along functions through Options.
@manipulate for ϕ = 0:π/16:4π, f = [:sin => sin, :cos => cos], out=:plot
    push!(out, plot(x -> f(x + ϕ), 0, pi))
end
    

## Can use oplot
@manipulate for n=1:10, out=:plot
    p = plot(sin, 0, n*pi)
    oplot(cos, 0, n*pi)
    push!(out, p)
end

## and we can combine (mimicing an example from Interact)
@manipulate for ϕ = 0:π/16:4π, f = [:sin => sin, :cos => cos], both = false, out=:plot
    if both
        p = plot(θ -> sin(θ + ϕ), 0, 8)
	oplot(θ -> cos(θ + ϕ), 0, 8)
    else
        p = plot(θ -> f(θ + ϕ), 0, 8)
    end
    push!(out, p)
end


## can use lower level Winston commands
@manipulate for n=1.0:0.1:5.0, m=1.0:0.1:5.0, out=:plot
    t = linspace(0, 2pi, 1000)
    xs = map(x -> sin(n*pi*x), t)
    ys = map(x -> cos(m*pi*x), t)
    p = Winston.FramedPlot(title="parametric")
    Winston.add(p, Winston.Curve(xs, ys))
    push!(out, p)
end
                 
   
#### Text based output ### 
## The `:text` output uses a text area with a scrolled window for the display of larger amounts of data.
## The `:label` output widget uses a label. This is useful, as PANGO markup can be utilized.    

## the value (n,x) is rendered after going through writemime("text/plain", ⋅̇) 
@manipulate for n=1:10, x=1:10, out=:text
    push!(out, (n,x))
end


## Sadly, no latex output widget. So this example fails to render nicely
using SymPy
x = Sym("x")
@manipulate for n=1:10, out=:text
    a = diff(sin(x^2), x, n)
    ## push!(out, a)            # poor alignment of rows
    ## push!(out, latex(a))     # no native latex
    push!(out, jprint(a))       # better, not great
end


## We can also use a label for output. This allows for some PANGO markup
## (https://developer.gnome.org/pango/stable/PangoMarkupFormat.html)
@manipulate for n = 1:20, out=:label
    x = n > 10 ? "<b>$n</b>" : string(n)
    push!(out, "The value is $x")
end


## Can put more than one output, but this should be laid out better...
@manipulate for n=1:10, m=1:10, out=:plot, out1=:text
    push!(out, plot(sin, 0, n*pi))
    push!(out1, m)
end


## Control widgets can be used instead of their being derived from the argument. This
## gives some flexibility and allows the labels to be different than the variable
## name associated with the control.
@manipulate for rb=radiobuttons([1,2,3],label="rb"), cb=checkbox(true, label="checkbox")
    println((rb, cb))
end


## An example of @vchuravy from https://github.com/JuliaLang/Interact.jl/issues/36
using Distributions
@manipulate for α in 1:100, β = 1:100, cg = :plot
    p = plot(x -> pdf(Beta(α, β), x), 0, 1)
    push!(cg, p)
end
