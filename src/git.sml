
structure GitControl :> VCS_CONTROL = struct
                            
    fun exists context libname =
        OS.FileSys.isDir (FileBits.subpath context libname ".git")
        handle _ => false

    fun remote_for (libname, provider) =
        case provider of
            URL u => u
          | SERVICE { host, owner, repo } =>
            let val r = case repo of
                            SOME r => r
                          | NONE => libname
            in
                case host of
                    "github" => "https://github.com/" ^ owner ^ "/" ^ r
                  | "bitbucket" => "https://bitbucket.org/" ^ owner ^ "/" ^ r
                  | other => raise Fail ("Unsupported implicit git provider \"" ^
                                         other ^ "\"")
            end

    fun checkout context (libname, provider) =
        let val command = FileBits.command context ""
            val url = remote_for (libname, provider)
        in
            case FileBits.mkpath (FileBits.extpath context) of
               OK => command ["git", "clone", url, libname]
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
            case FileBits.command_output context libname
                                         ["git", "rev-list", "-1", id_or_tag] of
                FAIL err => raise Fail err
              | SUCCEED tid =>
                tid = id andalso
                tid <> id_or_tag (* otherwise id_or_tag was an id, not a tag *)

    fun is_newest context (libname, provider, branch) = false (*!!! *)

    fun update context (libname, provider, branch) =
        let val branch_name = case branch of
                                  DEFAULT_BRANCH => "master"
                                | BRANCH b => b
        in
            update_to context (libname, provider, branch_name)
        end

    and update_to context (libname, provider, "") = 
        raise Fail "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, provider, id) = 
        let val command = FileBits.command context libname
            val url = remote_for (libname, provider)
        in
            case command ["git", "checkout", "--detach", id] of
                OK => OK
              | ERROR _ => 
                case command ["git", "pull", url] of
                    OK => command ["git", "checkout", "--detach", id]
                  | ERROR e => ERROR e
        end
end
