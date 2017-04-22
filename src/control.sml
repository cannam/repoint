                                         
functor LibControlFn (V: VCS_CONTROL) :> LIB_CONTROL = struct

    fun check context ({ libname, provider, pin, ... } : libspec) =
        let fun check' () =
            case pin of
                UNPINNED =>
                if not (V.is_newest context (libname, provider))
                then SUPERSEDED
                else CORRECT

              | PINNED target =>
                if V.is_at context libname target
                then CORRECT
                else WRONG
        in
            if not (V.exists context libname)
            then ABSENT
            else check' ()
        end

    fun update context (spec as { libname, provider, pin, ... } : libspec) =
        let fun update' () =
            case pin of
                UNPINNED =>
                if not (V.is_newest context (libname, provider))
                then V.update context (libname, provider)
                else OK

              | PINNED target =>
                if V.is_at context libname target
                then OK
                else V.update_to context (libname, provider, target)
        in
            if not (V.exists context libname)
            then case V.checkout context (libname, provider) of
                     OK => update' ()
                   | ERROR e => ERROR e
            else update' ()
        end
end

structure AnyLibControl :> LIB_CONTROL = struct

    structure H = LibControlFn(HgControl)
    structure G = LibControlFn(GitControl)

    fun check context (spec as { vcs, ... } : libspec) =
        (fn HG => H.check | GIT => G.check) vcs context spec

    fun update context (spec as { vcs, ... } : libspec) =
        (fn HG => H.update | GIT => G.update) vcs context spec
end
