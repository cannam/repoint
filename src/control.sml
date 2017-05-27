                                         
functor LibControlFn (V: VCS_CONTROL) :> LIB_CONTROL = struct

    fun review context ({ libname, source,
                         branch, pin, ... } : libspec) =
        let fun review' () =
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
            then (ABSENT, UNMODIFIED)
            else (review' (), if V.is_locally_modified context libname
                             then MODIFIED
                             else UNMODIFIED)
        end

    (* status is like review, except that it avoids using the network
       and so can't report SUPERSEDED state *)
    fun status context ({ libname, source,
                          branch, pin, ... } : libspec) =
        let fun status' () =
            case pin of
                UNPINNED => CORRECT
              | PINNED target =>
                if V.is_at context libname target
                then CORRECT
                else WRONG
        in
            if not (V.exists context libname)
            then (ABSENT, UNMODIFIED)
            else (status' (), if V.is_locally_modified context libname
                              then MODIFIED
                              else UNMODIFIED)
        end
                         
    fun update context ({ libname, source, branch, pin, ... } : libspec) =
        let fun update' () =
            case pin of
                UNPINNED =>
                if not (V.is_newest context (libname, source, branch))
                then V.update context (libname, source, branch)
                else OK ()

              | PINNED target =>
                if V.is_at context libname target
                then OK ()
                else V.update_to context (libname, source, target)
        in
            if not (V.exists context libname)
            then V.checkout context (libname, source, branch)
            else update' ()
        end
end
