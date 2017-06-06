
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
                else "default"
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
                               | BRANCH "" => "default"
                               | BRANCH b => b

    fun id_of context libname =
        case current_state context libname of
            ERROR e => ERROR e
          | OK { id, ... } => OK id

    fun is_at context (libname, id_or_tag) =
        case current_state context libname of
            ERROR e => ERROR e
          | OK { id, tags, ... } => 
            OK (String.isPrefix id_or_tag id orelse
                String.isPrefix id id_or_tag orelse
                List.exists (fn t => t = id_or_tag) tags)

    fun is_on_branch context (libname, b) =
        case current_state context libname of
            ERROR e => ERROR e
          | OK { branch, ... } => OK (branch = branch_name b)
               
    fun is_newest_locally context (libname, branch) =
        case hg_command_output context libname
                               ["log", "-l1",
                                "-b", branch_name branch,
                                "--template", "{node}"] of
            ERROR e => ERROR e
          | OK newest_in_repo => is_at context (libname, newest_in_repo)

    fun pull context libname =
        hg_command context libname
                   (if FileBits.verbose ()
                    then ["pull"]
                    else ["pull", "-q"])

    fun is_newest context (libname, branch) =
        case is_newest_locally context (libname, branch) of
            ERROR e => ERROR e
          | OK false => OK false
          | OK true =>
            case pull context libname of
                ERROR e => ERROR e
              | _ => is_newest_locally context (libname, branch)

    fun is_modified_locally context libname =
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
                                                    
    fun update context (libname, branch) =
        let val pull_result = pull context libname
        in
            case hg_command context libname ["update", branch_name branch] of
                ERROR e => ERROR e
              | _ =>
                case pull_result of
                    ERROR e => ERROR e
                  | _ => id_of context libname
        end

    fun update_to context (libname, "") =
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, id) = 
        case hg_command context libname ["update", "-r" ^ id] of
            OK () => id_of context libname
          | ERROR _ => 
            case pull context libname of
                ERROR e => ERROR e
              | _ =>
                case hg_command context libname ["update", "-r" ^ id] of
                    ERROR e => ERROR e
                  | _ => id_of context libname
                  
end
