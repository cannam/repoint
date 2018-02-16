
structure AnyLibControl :> LIB_CONTROL = struct

    structure H = LibControlFn(HgControl)
    structure G = LibControlFn(GitControl)
    structure S = LibControlFn(SvnControl)

    fun review context (spec as { vcs, ... } : libspec) =
        (fn HG => H.review | GIT => G.review | SVN => S.review) vcs context spec

    fun status context (spec as { vcs, ... } : libspec) =
        (fn HG => H.status | GIT => G.status | SVN => S.status) vcs context spec

    fun update context (spec as { vcs, ... } : libspec) =
        (fn HG => H.update | GIT => G.update | SVN => S.update) vcs context spec

    fun id_of context (spec as { vcs, ... } : libspec) =
        (fn HG => H.id_of | GIT => G.id_of | SVN => S.id_of) vcs context spec

    fun is_working context vcs =
        (fn HG => H.is_working | GIT => G.is_working | SVN => S.is_working)
            vcs context vcs

end

