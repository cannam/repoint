
structure HgControl :> VCS_CONTROL = struct
                            
    type vcsstate = { id: string, modified: bool,
                      branch: string, tags: string list }

    val hg_args = [ "--config", "ui.interactive=true" ]
                        
    fun hg_command context libname args =
        FileBits.command context libname ("hg" :: hg_args @ args)

    fun hg_command_output context libname args =
        FileBits.command_output context libname ("hg" :: hg_args @ args)
                        
    fun exists context libname =
        OK (OS.FileSys.isDir (FileBits.subpath context libname ".hg"))
        handle _ => OK false

    fun remote_for context (libname, source) =
        Provider.remote_url context HG source libname

    fun current_state context libname : vcsstate result =
        let fun is_branch text = text <> "" andalso #"(" = hd (explode text)
            and extract_branch b =
                if is_branch b     (* need to remove enclosing parens *)
                then (implode o rev o tl o rev o tl o explode) b
                else ""
            and is_modified id = id <> "" andalso #"+" = hd (rev (explode id))
            and extract_id id =
                if is_modified id  (* need to remove trailing "+" *)
                then (implode o rev o tl o rev o explode) id
                else id
            and split_tags tags = String.tokens (fn c => c = #"/") tags
            and state_for (id, branch, tags) =
                OK { id = extract_id id,
                     modified = is_modified id,
                     branch = extract_branch branch,
                     tags = split_tags tags }
        in        
            case hg_command_output context libname ["id"] of
                ERROR e => ERROR e
              | OK out =>
                case String.tokens (fn x => x = #" ") out of
                    [id, branch, tags] => state_for (id, branch, tags)
                  | [id, other] => if is_branch other
                                   then state_for (id, other, "")
                                   else state_for (id, "", other)
                  | [id] => state_for (id, "", "")
                  | _ => ERROR ("Unexpected output from hg id: " ^ out)
        end

    fun branch_name branch = case branch of
                                 DEFAULT_BRANCH => "default"
                               | BRANCH b => b

    fun is_at context (libname, id_or_tag) =
        case current_state context libname of
            ERROR e => ERROR e
          | OK { id, tags, ... } => 
            OK (String.isPrefix id_or_tag id orelse
                String.isPrefix id id_or_tag orelse
                List.exists (fn t => t = id_or_tag) tags)

    fun has_nothing_incoming context (libname, source, branch) =
        case hg_command_output context libname
                               ["incoming", "-l1",
                                "-b", branch_name branch,
                                "--template", "{node}"] of
            ERROR err => OK true (* hg incoming is odd that way *)
          | OK incoming => 
            OK (incoming = "" orelse
                String.isSubstring "no changes found" incoming)

    fun is_newest context (libname, source, branch) =
        case hg_command_output context libname
                               ["log", "-l1",
                                "-b", branch_name branch,
                                "--template", "{node}"] of
            ERROR e => ERROR e
          | OK newest_in_repo =>
            case is_at context (libname, newest_in_repo) of
                ERROR e => ERROR e
              | OK false => OK false
              | OK true => 
                has_nothing_incoming context (libname, source, branch)

    fun is_locally_modified context libname =
        case current_state context libname of
            ERROR e => ERROR e
          | OK { modified, ... } => OK modified
                
    fun checkout context (libname, source, branch) =
        let val url = remote_for context (libname, source)
        in
            case FileBits.mkpath (FileBits.extpath context) of
                ERROR e => ERROR e
              | _ => hg_command context ""
                                ["clone", "-u", branch_name branch,
                                 url, libname]
        end
                                                    
    fun update context (libname, source, branch) =
        let val url = remote_for context (libname, source)
            val pull_result = hg_command context libname ["pull", url]
        in
            case hg_command context libname ["update", branch_name branch] of
                ERROR e => ERROR e
              | _ => pull_result
        end

    fun update_to context (libname, source, "") =
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, source, id) = 
        let val url = remote_for context (libname, source)
        in
            case hg_command context libname ["update", "-r" ^ id] of
                OK () => OK ()
              | ERROR _ => 
                case hg_command context libname ["pull", url] of
                    OK () => hg_command context libname ["update", "-r" ^ id]
                  | ERROR e => ERROR e
        end
                  
end
