                                         
functor LibControlFn (V: VCS_CONTROL) :> LIB_CONTROL = struct

    fun check with_network context
              ({ libname, source, branch, pin, ... } : libspec) =
        let fun check_unpinned () =
                if with_network
                then case V.is_newest context (libname, source, branch) of
                         ERROR e => ERROR e
                       | OK true => OK CORRECT
                       (*!!! We can't currently tell the difference
                             between superseded (on the same branch) and
                             wrong branch checked out *)
                       | OK false => OK SUPERSEDED
                else OK CORRECT
            fun check_pinned target =
                case V.is_at context (libname, target) of
                    ERROR e => ERROR e
                  | OK true => OK CORRECT
                  | OK false => OK WRONG
            fun check' () =
                case pin of
                    UNPINNED => check_unpinned ()
                  | PINNED target => check_pinned target
        in
            case V.exists context libname of
                ERROR e => ERROR e
              | OK false => OK (ABSENT, UNMODIFIED)
              | OK true =>
                case (check' (), V.is_locally_modified context libname) of
                    (ERROR e, _) => ERROR e
                  | (_, ERROR e) => ERROR e
                  | (OK state, OK true) => OK (state, MODIFIED)
                  | (OK state, OK false) => OK (state, UNMODIFIED)
        end

    val review = check true
    val status = check false
                         
    fun update context ({ libname, source, branch, pin, ... } : libspec) =
        let fun update_unpinned () =
                case V.is_newest context (libname, source, branch) of
                    ERROR e => ERROR e
                  | OK true => V.id_of context libname
                  | OK false => V.update context (libname, source, branch)
            fun update_pinned target =
                case V.is_at context (libname, target) of
                    ERROR e => ERROR e
                  | OK true => OK target
                  | OK false => V.update_to context (libname, source, target)
            fun update' () =
                case pin of
                    UNPINNED => update_unpinned ()
                  | PINNED target => update_pinned target
        in
            case V.exists context libname of
                ERROR e => ERROR e
              | OK true => update' ()
              | OK false =>
                case V.checkout context (libname, source, branch) of
                    ERROR e => ERROR e
                  | OK () => update' ()
        end
end
