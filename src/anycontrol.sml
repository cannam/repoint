
structure AnyLibControl :> LIB_CONTROL = struct

    structure H = LibControlFn(HgControl)
    structure G = LibControlFn(GitControl)

    fun review context (spec as { vcs, ... } : libspec) =
        (fn HG => H.review | GIT => G.review) vcs context spec

    fun status context (spec as { vcs, ... } : libspec) =
        (fn HG => H.status | GIT => G.status) vcs context spec

    fun update context (spec as { vcs, ... } : libspec) =
        (fn HG => H.update | GIT => G.update) vcs context spec

    fun id_of context (spec as { vcs, ... } : libspec) =
        (fn HG => H.id_of | GIT => G.id_of) vcs context spec
end

