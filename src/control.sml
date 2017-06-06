                                         
functor LibControlFn (V: VCS_CONTROL) :> LIB_CONTROL = struct

    (* Valid states for unpinned libraries:

       - CORRECT: We are on the right branch and are up-to-date with
         it as far as we can tell. (If not using the network, this
         should be reported to user as "Present" rather than "Correct"
         as the remote repo may have advanced without us knowing.)

       - SUPERSEDED: We are on the right branch but we can see that
         there is a newer revision either locally or on the remote (in
         Git terms, we are at an ancestor of the desired branch tip).

       - WRONG: We are on the wrong branch (in Git terms, we are not
         at the desired branch tip or any ancestor of it).

       - ABSENT: Repo doesn't exist here at all.

       Valid states for pinned libraries:

       - CORRECT: We are at the pinned revision.

       - WRONG: We are at any revision other than the pinned one.

       - ABSENT: Repo doesn't exist here at all.
    *)

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
