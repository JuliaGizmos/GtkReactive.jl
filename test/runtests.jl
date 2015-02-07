using GtkInteract
using Base.Test

## test manipulate
@manipulate for n=1:10
    n
end



## tests widgets
using Reactive
opts = ["one", "two", "three"]
# write your own tests here
w = mainwindow(title="test")
sl = slider(1:10)         # one from range
cb = checkbox(true, label="check")      # bool
tb = togglebutton(true, label="toggle") # bool
dd = dropdown(opts)       # 1 of n
rbs = radiobuttons(opts)  # 1 of n
sel = select(opts)        # 1 of n
tbs = togglebuttons(opts) # 1 of n
bg = buttongroup(opts)    # 0,1,...,n of n


btn = button("button")
out = label()

controls = [sl, cb, tb, dd, rbs, sel, tbs, bg]
append!(w, controls)
append!(w, [btn, out])

lift(controls...) do sl, cb, tb, dd, rbs, sel, tbs, bg
    push!(out, """
          $(string(sl))
          $(string(cb))
          $(string(tb))
          $(string(dd))
          $(string(rbs))
          $(string(sel))
          $(string(tbs))
          $(string(bg))
          """)
end
