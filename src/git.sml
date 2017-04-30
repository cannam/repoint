
structure GitControl :> VCS_CONTROL = struct
                            
    fun exists context libname =
        OS.FileSys.isDir (FileBits.subpath context libname ".git")
        handle _ => false

    fun remote_for context (libname, source) =
        Provider.remote_url (#providers context) GIT source libname

    fun branch_name branch = case branch of
                                 DEFAULT_BRANCH => "master"
                               | BRANCH b => b

    fun checkout context (libname, provider, branch) =
        let val command = FileBits.command context ""
            val url = remote_for context (libname, provider)
        in
            case FileBits.mkpath (FileBits.extpath context) of
                OK => command ["git", "clone", "-b", branch_name branch,
                               url, libname]
              | ERROR e => ERROR e
        end

    (* NB git rev-parse HEAD shows revision id of current checkout;
    git rev-list -1 <tag> shows revision id of revision with that tag *)

    fun is_at context libname id_or_tag =
        case FileBits.command_output context libname
                                     ["git", "rev-parse", "HEAD"] of
            FAIL err => raise Fail err
          | SUCCEED id =>
            String.isPrefix id_or_tag id orelse
            String.isPrefix id id_or_tag orelse
            case FileBits.command_output context libname
                                         ["git", "rev-list", "-1", id_or_tag] of
                FAIL err => raise Fail err
              | SUCCEED tid =>
                tid = id andalso
                tid <> id_or_tag (* otherwise id_or_tag was an id, not a tag *)

    fun is_newest context (libname, provider, branch) =
        let fun newest_here () =
              case FileBits.command_output
                       context libname
                       ["git", "rev-list", "-1", branch_name branch] of
                  FAIL err => raise Fail err
                | SUCCEED rev => is_at context libname rev
        in
            if not (newest_here ())
            then false
            else case FileBits.command context libname ["git", "fetch"] of
                     ERROR err => raise Fail err
                   | OK => newest_here ()
        end

    fun is_locally_modified context libname =
        case FileBits.command_output context libname ["git", "status", "-s"] of
            FAIL err => raise Fail err
          | SUCCEED "" => false
          | SUCCEED _ => true
            
    fun update context (libname, provider, branch) =
        update_to context (libname, provider, branch_name branch)

    and update_to context (libname, provider, "") = 
        raise Fail "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, provider, id) = 
        let val command = FileBits.command context libname
            val url = remote_for context (libname, provider)
        in
            case command ["git", "checkout", "--detach", id] of
                OK => OK
              | ERROR _ => 
                case command ["git", "pull", url] of
                    OK => command ["git", "checkout", "--detach", id]
                  | ERROR e => ERROR e
        end
end
