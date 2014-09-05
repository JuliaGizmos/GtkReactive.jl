using GtkInteract
using Winston

## manipulate with a plot device requires an output widget
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
    


## manipulate for text can use console. Function would need to manage erasing previous
@manipulate for n=1:10, x=1:10
    (n,x)
end


## manipulate can also use a textarea widget
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
