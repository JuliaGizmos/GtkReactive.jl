using GtkInteract
using Winston

## manipulate with a plot device requires an output widget
@manipulate for n=1:10, cg = :plot
    p = plot(sin, 0, n*pi)
     push!(cg, p)
 end

## Unicode works, as does passing along functions through Options.
@manipulate for ϕ = 0:π/16:4π, f = [:sin => sin, :cos => cos], out=:plot
    push!(out, plot(x -> ϕ + f(x), 0, pi))
end
    

## Can use oplot
@manipulate for n=1:10, out=:plot
    p = plot(sin, 0, n*pi)
    oplot(cos, 0, n*pi)
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
@manipulate for n=1:10, x=1:10, cg=:text
    push!(cg, (n,x))
end

## Can put more than one output, but this should be laid out better...
@manipulate for n=1:10, m=1:10, out=:plot, out1=:text
    push!(out, plot(sin, 0, n*pi))
    push!(out1, m)
end
