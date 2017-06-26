
structure GitControl :> VCS_CONTROL = struct

    (* With Git repos we always operate in detached HEAD state. Even
       the master branch is checked out using the remote reference,
       origin/master. *)

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
                               | BRANCH "" => "master"
                               | BRANCH b => b

    fun remote_branch_name branch = "origin/" ^ branch_name branch

    fun checkout context (libname, source, branch) =
        let val url = remote_for context (libname, source)
        in
            case FileBits.mkpath (FileBits.extpath context) of
                OK () => git_command context ""
                                     ["clone", "-b",
                                      branch_name branch,
                                      url, libname]
              | ERROR e => ERROR e
        end

    (* NB git rev-parse HEAD shows revision id of current checkout;
       git rev-list -1 <tag> shows revision id of revision with that tag *)

    fun id_of context libname =
        git_command_output context libname ["rev-parse", "HEAD"]
            
    fun is_at context (libname, id_or_tag) =
        case id_of context libname of
            ERROR e => ERROR e
          | OK id =>
            if String.isPrefix id_or_tag id orelse
               String.isPrefix id id_or_tag
            then OK true
            else 
                case git_command_output context libname
                                        ["rev-list", "-1", id_or_tag] of
                    ERROR e => OK false (* id_or_tag is not an id or tag, but
                                           that could just mean it hasn't been
                                           fetched *)
                  | OK tid => OK (tid = id)

    fun branch_tip context (libname, branch) =
        git_command_output context libname
                           ["rev-list", "-1",
                            remote_branch_name branch]
                       
    fun is_newest_locally context (libname, branch) =
        case branch_tip context (libname, branch) of
            ERROR e => ERROR e
          | OK rev => is_at context (libname, rev)

    fun is_on_branch context (libname, branch) =
        case branch_tip context (libname, branch) of
            ERROR e => ERROR e
          | OK rev =>
            case is_at context (libname, rev) of
                ERROR e => ERROR e
              | OK true => OK true
              | OK false =>
                case git_command context libname
                                 ["merge-base", "--is-ancestor",
                                  "HEAD", remote_branch_name branch] of
                    ERROR e => OK false  (* cmd returns non-zero for no *)
                  | _ => OK true

    fun is_newest context (libname, branch) =
        case is_newest_locally context (libname, branch) of
            ERROR e => ERROR e
          | OK false => OK false
          | OK true =>
            case git_command context libname ["fetch"] of
                ERROR e => ERROR e
              | _ => is_newest_locally context (libname, branch)

    fun is_modified_locally context libname =
        case git_command_output context libname ["status", "--porcelain"] of
            ERROR e => ERROR e
          | OK "" => OK false
          | OK _ => OK true

    (* This function updates to the latest revision on a branch rather
       than to a specific id or tag. We can't just checkout the given
       branch, as that will succeed even if the branch isn't up to
       date. We could checkout the branch and then fetch and merge,
       but it's perhaps cleaner not to maintain a local branch at all,
       but instead checkout the remote branch as a detached head. *)

    fun update context (libname, branch) =
        case git_command context libname ["fetch"] of
            ERROR e => ERROR e
          | _ =>
            case git_command context libname ["checkout", "--detach",
                                              remote_branch_name branch] of
                ERROR e => ERROR e
              | _ => id_of context libname

    (* This function is dealing with a specific id or tag, so if we
       can successfully check it out (detached) then that's all we need
       to do. Otherwise we need to fetch and try again *)

    fun update_to context (libname, "") = 
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, id) =
        case git_command context libname ["checkout", "--detach", id] of
            OK () => id_of context libname
          | ERROR _ => 
            case git_command context libname ["fetch"] of
                ERROR e => ERROR e
              | _ =>
                case git_command context libname ["checkout", "--detach", id] of
                    ERROR e => ERROR e
                  | _ => id_of context libname
end
