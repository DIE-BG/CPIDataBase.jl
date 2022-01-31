using CPIDataBase
using Documenter

DocMeta.setdocmeta!(CPIDataBase, :DocTestSetup, :(using CPIDataBase); recursive=true)

makedocs(;
    modules=[CPIDataBase],
    authors="Rodrigo Chang",
    repo="https://github.com/r2cp/CPIDataBase.jl/blob/{commit}{path}#{line}",
    sitename="CPIDataBase.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://r2cp.github.io/CPIDataBase.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API" => "API.md",
    ],
)

deploydocs(;
    repo="github.com/r2cp/CPIDataBase.jl",
    devbranch="main",
)
