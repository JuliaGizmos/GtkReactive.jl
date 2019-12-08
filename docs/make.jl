using Documenter, GtkReactive

makedocs(sitename = "GtkReactive",
         format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
         pages    = ["index.md", "controls.md", "drawing.md", "zoom_pan.md", "reference.md"]
         )

deploydocs(repo   = "github.com/JuliaGizmos/GtkReactive.jl.git",
           )
