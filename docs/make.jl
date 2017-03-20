using Documenter, GtkReactive

makedocs(format   = :html,
         sitename = "GtkReactive",
         pages    = ["index.md", "reference.md"]
         )

deploydocs(repo   = "github.com/JuliaGizmos/GtkReactive.jl",
           target = "build",
           deps   = nothing,
           make   = nothing
           )
