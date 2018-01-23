
structure SvnControl :> VCS_CONTROL = struct

    fun svn_command context libname args =
        FileBits.command context libname ("svn" :: args)

    fun svn_command_output context libname args =
        FileBits.command_output context libname ("svn" :: args)

    fun svn_command_lines context libname args =
        case svn_command_output context libname args of
            ERROR e => ERROR e
          | OK s => OK (String.tokens (fn c => c = #"\n" orelse c = #"\r") s)

    fun split_line_pair line =
        let fun strip_leading_ws str = case explode str of
                                           #" "::rest => implode rest
                                         | _ => str
        in
            case String.tokens (fn c => c = #":") line of
                [] => ("", "")
              | first::rest =>
                (first, strip_leading_ws (String.concatWith ":" rest))
        end
            
    fun svn_info_item context libname key =
        (* SVN 1.9 has info --show-item which is what we need, but at
           this point we still have 1.8 on the CI boxes so we might as 
           well aim to support it *)
        case svn_command_lines context libname ["info"] of
            ERROR e => ERROR e
          | OK lines =>
            case List.find (fn (k, v) => k = key) (map split_line_pair lines) of
                NONE => ERROR ("Key \"" ^ key ^ "\" not found in output")
              | SOME (_, v) => OK v
            
    fun exists context libname =
        OK (OS.FileSys.isDir (FileBits.subpath context libname ".svn"))
        handle _ => OK false

    fun remote_for context (libname, source) =
        Provider.remote_url context SVN source libname

    fun id_of context libname =
        svn_info_item context libname "Revision" (*!!! check: does svn localise this? should we ensure C locale? *)

    fun is_at context (libname, id_or_tag) =
        case id_of context libname of
            ERROR e => ERROR e
          | OK id => OK (id = id_or_tag)

    fun is_on_branch context (libname, b) =
        OK (b = DEFAULT_BRANCH)

    fun check_remote context (libname, source) =
        let val url = remote_for context (libname, source)
        in
            case svn_info_item context libname "URL" of
                ERROR e => ERROR e
              | OK actual =>
                if actual = url
                then OK ()
                else svn_command context libname ["relocate", url]
        end
               
    fun is_newest context (libname, source, branch) =
        case check_remote context (libname, source) of
            ERROR e => ERROR e
          | OK () => 
            case svn_command_lines context libname
                                   ["status", "--show-updates"] of
                ERROR e => ERROR e
              | OK lines =>
                case rev lines of
                    [] => ERROR "No result returned for server status"
                  | last_line::_ =>
                    case rev (String.tokens (fn c => c = #" ") last_line) of
                        [] => ERROR "No revision field found in server status"
                      | server_id::_ => is_at context (libname, server_id)

    fun is_newest_locally context (libname, branch) =
        OK true (* no local history *)

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
                ERROR ("Refusing checkout to nonempty dir \"" ^ path ^ "\"")
            else 
                (* make the lib dir rather than just the ext dir, since
                   the lib dir might be nested and svn will happily check
                   out into an existing empty dir anyway *)
                case FileBits.mkpath (FileBits.libpath context libname) of
                    ERROR e => ERROR e
                  | _ => svn_command context "" ["checkout", url, libname]
        end
                                                    
    fun update context (libname, source, branch) =
        case check_remote context (libname, source) of
            ERROR e => ERROR e
          | OK () => 
            case svn_command context libname
                             ["update", "--accept", "postpone"] of
                ERROR e => ERROR e
              | _ => OK ()

    fun update_to context (libname, _, "") =
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, source, id) = 
        case check_remote context (libname, source) of
            ERROR e => ERROR e
          | OK () => 
            case svn_command context libname
                             ["update", "-r", id, "--accept", "postpone"] of
                ERROR e => ERROR e
              | OK _ => OK ()

    fun copy_url_for context libname =
        svn_info_item context libname "URL"

end
