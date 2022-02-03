using CPIDataBase
using Documenter

DocMeta.setdocmeta!(CPIDataBase, :DocTestSetup, :(using CPIDataBase); recursive=true)

makedocs(;
    modules=[CPIDataBase],
    authors="Rodrigo Chang and DIE-BG collaborators",
    repo="https://github.com/die-bg/CPIDataBase.jl/blob/{commit}{path}#{line}",
    sitename="CPIDataBase.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://die-bg.github.io/CPIDataBase.jl",
        assets=String[],
    ),
    # format=Documenter.LaTeX(), 
    pages=[
        "Home" => "index.md",
        "API" => "API.md",
    ],
)

deploydocs(;
    repo="github.com/die-bg/CPIDataBase.jl",
    devbranch="main",
)
