using Documenter, GtkReactive

makedocs(format   = :html,
         sitename = "GtkReactive",
         pages    = ["index.md", "controls.md", "drawing.md", "zoom_pan.md", "reference.md"]
         )

deploydocs(repo   = "github.com/JuliaGizmos/GtkReactive.jl",
           target = "build",
           julia  = "0.5",
           deps   = nothing,
           make   = nothing
           )
