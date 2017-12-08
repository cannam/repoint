
structure SvnControl :> VCS_CONTROL = struct

    fun svn_command context libname args =
        FileBits.command context libname ("svn" :: args)

    fun svn_command_output context libname args =
        FileBits.command_output context libname ("svn" :: args)
                        
    fun exists context libname =
        OK (OS.FileSys.isDir (FileBits.subpath context libname ".svn"))
        handle _ => OK false

    fun remote_for context (libname, source) =
        Provider.remote_url context SVN source libname

    fun id_of context libname =
        case svn_command_output context libname
                                ["info", "--show-item", "revision"] of
            ERROR e => ERROR e
          | OK output =>
            case String.tokens (fn c => c = #" " orelse c = #"\t") output of
                [token] => OK token
              | _ => ERROR ("Unable to extract single revision ID from \"" ^
                            output ^ "\"")

    fun is_at context (libname, id_or_tag) =
        case id_of context libname of
            ERROR e => ERROR e
          | OK id => OK (id = id_or_tag)

    fun is_on_branch context (libname, b) =
        OK (b = DEFAULT_BRANCH)
               
    fun is_newest context (libname, source, branch) =
        case svn_command_output context libname ["status", "--show-updates"] of 
            ERROR e => ERROR e
          | OK output =>
            case rev (String.tokens (fn c => c = #"\n") output) of
                [] => ERROR "No result returned for server status"
              | last_line::_ =>
                case rev (String.tokens (fn c => c = #" ") last_line) of
                    [] => ERROR "No revision field found in server status"
                  | server_id::_ => is_at context (libname, server_id)

    fun is_newest_locally context (libname, branch) =
        OK true

    fun is_modified_locally context libname =
        case svn_command_output context libname ["status"] of
            ERROR e => ERROR e
          | OK "" => OK false
          | OK _ => OK true

    fun checkout context (libname, source, branch) =
        let val url = remote_for context (libname, source)
            val path = FileBits.libpath context libname
        in
            if FileBits.nonempty_dir_exists path
            then (* Surprisingly, SVN itself has no problem with
                    this. But for consistency with other VCSes we 
                    don't allow it *)
                ERROR ("Refusing to checkout to nonempty target dir \"" ^
                        path ^ "\"")
            else 
                (* make the lib dir rather than just the ext dir, since
                   the lib dir might be nested and svn will happily check
                   out into an existing empty dir anyway *)
                case FileBits.mkpath (FileBits.libpath context libname) of
                    ERROR e => ERROR e
                  | _ => svn_command context "" ["checkout", url, libname]
        end
                                                    
    fun update context (libname, source, branch) =
        case svn_command context libname
                         ["update", "--accept", "postpone"] of
            ERROR e => ERROR e
          | _ => id_of context libname

    fun update_to context (libname, _, "") =
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, source, id) = 
        case svn_command context libname
                         ["update", "-r", id, "--accept", "postpone"] of
            ERROR e => ERROR e
          | OK _ => id_of context libname

    fun copy_url_for context libname =
        svn_command_output context libname ["info", "--show-item", "url"]

end
