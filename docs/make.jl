using CBLS
using Documenter

DocMeta.setdocmeta!(CBLS, :DocTestSetup, :(using CBLS); recursive = true)

makedocs(;
    modules = [CBLS],
    authors = "Jean-Francois Baffier",
    repo = "https://github.com/JuliaConstraints/CBLS.jl/blob/{commit}{path}#{line}",
    sitename = "CBLS.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://JuliaConstraints.github.io/CBLS.jl",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md"
    ]
)

deploydocs(;
    repo = "github.com/JuliaConstraints/CBLS.jl",
    devbranch = "main"
)
