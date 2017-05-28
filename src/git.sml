
structure GitControl :> VCS_CONTROL = struct
                            
    fun exists context libname =
        OK (OS.FileSys.isDir (FileBits.subpath context libname ".git"))
        handle _ => OK false

    fun remote_for context (libname, source) =
        Provider.remote_url context GIT source libname

    fun branch_name branch = case branch of
                                 DEFAULT_BRANCH => "master"
                               | BRANCH b => b

    fun checkout context (libname, provider, branch) =
        let val command = FileBits.command context ""
            val url = remote_for context (libname, provider)
        in
            case FileBits.mkpath (FileBits.extpath context) of
                OK () => command ["git", "clone", "-b", branch_name branch,
                               url, libname]
              | ERROR e => ERROR e
        end

    (* NB git rev-parse HEAD shows revision id of current checkout;
    git rev-list -1 <tag> shows revision id of revision with that tag *)

    fun is_at context (libname, id_or_tag) =
        case FileBits.command_output context libname
                                     ["git", "rev-parse", "HEAD"] of
            ERROR e => ERROR e
          | OK id =>
            if String.isPrefix id_or_tag id orelse
               String.isPrefix id id_or_tag
            then OK true
            else 
                case FileBits.command_output
                         context libname
                         ["git", "rev-list", "-1", id_or_tag] of
                    ERROR e => ERROR e
                  | OK tid =>
                    OK (tid = id andalso
                        tid <> id_or_tag) (* else id_or_tag was id not tag *)
                   
    fun is_newest context (libname, provider, branch) =
        let fun newest_here () =
              case FileBits.command_output
                       context libname
                       ["git", "rev-list", "-1",
                        "origin/" ^ branch_name branch] of
                  ERROR e => ERROR e
                | OK rev => is_at context (libname, rev)
        in
            case newest_here () of
                ERROR e => ERROR e
              | OK false => OK false
              | OK true => 
                case FileBits.command context libname ["git", "fetch"] of
                    ERROR e => ERROR e
                  | OK () => newest_here ()
        end

    fun is_locally_modified context libname =
        case FileBits.command_output context libname ["git", "status", "-s"] of
            ERROR e => ERROR e
          | OK "" => OK false
          | OK _ => OK true
            
    fun update context (libname, provider, branch) =
        update_to context (libname, provider, branch_name branch)

    and update_to context (libname, provider, "") = 
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, provider, id) = 
        let val command = FileBits.command context libname
            val url = remote_for context (libname, provider)
        in
            case command ["git", "checkout", "--detach", id] of
                OK () => OK ()
              | ERROR _ => 
                case command ["git", "pull", url] of
                    OK () => command ["git", "checkout", "--detach", id]
                  | ERROR e => ERROR e
        end
end
