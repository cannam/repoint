
structure GitControl :> VCS_CONTROL = struct

    fun git_command context libname args =
        FileBits.command context libname ("git" :: args)

    fun git_command_output context libname args =
        FileBits.command_output context libname ("git" :: args)
                            
    fun exists context libname =
        OK (OS.FileSys.isDir (FileBits.subpath context libname ".git"))
        handle _ => OK false

    fun remote_for context (libname, source) =
        Provider.remote_url context GIT source libname

    fun branch_name branch = case branch of
                                 DEFAULT_BRANCH => "master"
                               | BRANCH b => b

    fun checkout context (libname, provider, branch) =
        let val url = remote_for context (libname, provider)
        in
            case FileBits.mkpath (FileBits.extpath context) of
                OK () => git_command context ""
                                     ["clone", "-b", branch_name branch,
                                      url, libname]
              | ERROR e => ERROR e
        end

    (* NB git rev-parse HEAD shows revision id of current checkout;
       git rev-list -1 <tag> shows revision id of revision with that tag *)

    fun is_at context (libname, id_or_tag) =
        case git_command_output context libname
                                ["rev-parse", "HEAD"] of
            ERROR e => ERROR e
          | OK id =>
            if String.isPrefix id_or_tag id orelse
               String.isPrefix id id_or_tag
            then OK true
            else 
                case git_command_output context libname
                                        ["rev-list", "-1", id_or_tag] of
                    ERROR e => ERROR e
                  | OK tid =>
                    OK (tid = id andalso
                        tid <> id_or_tag) (* else id_or_tag was id not tag *)

    fun is_newest context (libname, provider, branch) =
        let fun newest_here () =
              case git_command_output context libname
                                      ["rev-list", "-1",
                                       "origin/" ^ branch_name branch] of
                  ERROR e => ERROR e
                | OK rev => is_at context (libname, rev)
        in
            case newest_here () of
                ERROR e => ERROR e
              | OK false => OK false
              | OK true =>
                case git_command context libname ["fetch"] of
                    ERROR e => ERROR e
                  | OK () => newest_here ()
        end

    fun is_locally_modified context libname =
        case git_command_output context libname ["status", "-s"] of
            ERROR e => ERROR e
          | OK "" => OK false
          | OK _ => OK true

    fun pull context (libname, branch) =
        case git_command context libname ["fetch"] of
            ERROR e => ERROR e
          | OK () => 
            case git_command context libname ["checkout", branch_name branch] of
                ERROR e => ERROR e
              | OK () => 
                git_command context libname ["merge", "--ff-only"]

    (* This function updates to the latest revision on a branch rather
       than to a specific id or tag. We can't just checkout the given
       branch, as that will succeed even if the branch isn't up to
       date. We need to checkout the branch and then fetch and merge. *)

    (*!!! I think this doesn't do the right thing for switching to a
       new remote branch - but it would be better to figure out how to
       test this properly and work backwards from there. Maybe rather
       than trying to maintain a local branch like this, we should
       always just checkout the remote branch in detached head state?
       *)
                            
    fun update context (libname, provider, branch) =
        case git_command context libname ["checkout", branch_name branch] of
            ERROR e => ERROR e
          | OK () => 
            case git_command context libname ["fetch"] of
                ERROR e => ERROR e
              | OK () => 
                git_command context libname ["merge", "--ff-only"]

    (* This function is dealing with a specific id or tag, so if we
       can successfully check it out (detached) then that's all we need
       to do. Otherwise we need to fetch and try again *)

    fun update_to context (libname, provider, "") = 
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, provider, id) =
        case git_command context libname ["checkout", "--detach", id] of
            OK () => OK ()
          | ERROR _ => 
            case git_command context libname ["fetch"] of
                ERROR e => ERROR e
              | OK () =>
                git_command context libname ["checkout", "--detach", id]
end
