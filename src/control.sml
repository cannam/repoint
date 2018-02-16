                                         
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
              ({ libname, source, branch,
                 project_pin, lock_pin, ... } : libspec) =
        let fun check_unpinned () =
                let val newest =
                        if with_network
                        then V.is_newest context (libname, source, branch)
                        else V.is_newest_locally context (libname, branch)
                in
                    case newest of
                         ERROR e => ERROR e
                       | OK true => OK CORRECT
                       | OK false =>
                         case V.is_on_branch context (libname, branch) of
                             ERROR e => ERROR e
                           | OK true => OK SUPERSEDED
                           | OK false => OK WRONG
                end
            fun check_pinned target =
                case V.is_at context (libname, target) of
                    ERROR e => ERROR e
                  | OK true => OK CORRECT
                  | OK false => OK WRONG
            fun check_remote () =
                case project_pin of
                    UNPINNED => check_unpinned ()
                  | PINNED target => check_pinned target
            fun check_local () =
                case V.is_modified_locally context libname of
                    ERROR e => ERROR e
                  | OK true  => OK MODIFIED
                  | OK false => 
                    case lock_pin of
                        UNPINNED => OK CLEAN
                      | PINNED target =>
                        case V.is_at context (libname, target) of
                            ERROR e => ERROR e
                          | OK true => OK CLEAN
                          | OK false => OK LOCK_MISMATCHED
        in
            case V.exists context libname of
                ERROR e => ERROR e
              | OK false => OK (ABSENT, CLEAN)
              | OK true =>
                case (check_remote (), check_local ()) of
                    (ERROR e, _) => ERROR e
                  | (_, ERROR e) => ERROR e
                  | (OK r, OK l) => OK (r, l)
        end

    val review = check true
    val status = check false

    fun update context
               ({ libname, source, branch,
                  project_pin, lock_pin, ... } : libspec) =
        let fun update_unpinned () =
                case V.is_newest context (libname, source, branch) of
                    ERROR e => ERROR e
                  | OK true => OK ()
                  | OK false => V.update context (libname, source, branch)
            fun update_pinned target =
                case V.is_at context (libname, target) of
                    ERROR e => ERROR e
                  | OK true => OK ()
                  | OK false => V.update_to context (libname, source, target)
            fun update' () =
                case lock_pin of
                    PINNED target => update_pinned target
                  | UNPINNED =>
                    case project_pin of
                        PINNED target => update_pinned target
                      | UNPINNED => update_unpinned ()
        in
            case V.exists context libname of
                ERROR e => ERROR e
              | OK true => update' ()
              | OK false =>
                case V.checkout context (libname, source, branch) of
                    ERROR e => ERROR e
                  | OK () => update' ()
        end

    fun id_of context ({ libname, ... } : libspec) =
        V.id_of context libname

    fun is_working context vcs =
        V.is_working context
                
end
