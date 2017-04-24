                                         
functor LibControlFn (V: VCS_CONTROL) :> LIB_CONTROL = struct

    fun check_libstate context ({ libname, source,
                                  branch, pin, ... } : libspec) =
        let fun check' () =
            case pin of
                UNPINNED =>
                if not (V.is_newest context (libname, source, branch))
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

    fun check context (spec as { libname, ... } : libspec) =
        case check_libstate context spec of
            ABSENT => (ABSENT, UNMODIFIED)
          | state => (state, if V.is_locally_modified context libname
                             then MODIFIED
                             else UNMODIFIED)
            
    fun update context ({ libname, source, branch, pin, ... } : libspec) =
        let fun update' () =
            case pin of
                UNPINNED =>
                if not (V.is_newest context (libname, source, branch))
                then V.update context (libname, source, branch)
                else OK

              | PINNED target =>
                if V.is_at context libname target
                then OK
                else V.update_to context (libname, source, target)
        in
            if not (V.exists context libname)
            then V.checkout context (libname, source, branch)
            else update' ()
        end
end
