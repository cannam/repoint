
structure HgControl :> VCS_CONTROL = struct

    (* Pulls always use an explicit URL, never just the default
       remote, in order to ensure we update properly if the location
       given in the project file changes. *)

    type vcsstate = { id: string, modified: bool,
                      branch: string, tags: string list }

    val hg_program = "hg"
                        
    val hg_args = [ "--config", "ui.interactive=true",
                    "--config", "ui.merge=:merge" ]

    val hg_extra_clone_pull_args = if FileBits.insecure ()
				   then [ "--insecure" ]
				   else []
                        
    fun hg_command context libname args =
        FileBits.command context libname (hg_program :: hg_args @ args)

    fun hg_command_output context libname args =
        FileBits.command_output context libname (hg_program :: hg_args @ args)

    fun is_working context =
        case hg_command_output context "" ["--version"] of
            OK "" => OK false
          | OK _ => OK true
          | ERROR e => ERROR e

    fun exists context libname =
        OK (OS.FileSys.isDir (FileBits.subpath context libname ".hg"))
        handle _ => OK false

    fun remote_for context (libname, source) =
        Provider.remote_url context HG source libname

    val default_branch_name = "default"
                            
    fun current_state (context : context) libname : vcsstate result =
        let fun is_branch text = text <> "" andalso #"(" = hd (explode text)
            and extract_branch b =
                if is_branch b     (* need to remove enclosing parens *)
                then (implode o rev o tl o rev o tl o explode) b
                else default_branch_name
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
                   
            val status =
                case StatusCache.lookup libname (#cache context) of
                    SOME status => OK status
                  | NONE =>
                    case hg_command_output context libname ["id"] of
                        ERROR e => ERROR e
                      | OK status =>
                        (StatusCache.add { libname = libname, status = status }
                                         (#cache context);
                         OK status)
        in        
            case status of
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
                                 DEFAULT_BRANCH => default_branch_name
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
            ERROR e => OK false (* desired branch does not exist *)
          | OK newest_in_repo => is_at context (libname, newest_in_repo)

    fun is_modified_locally context libname =
        case current_state context libname of
            ERROR e => ERROR e
          | OK { modified, ... } => OK modified

    (* Actions below this line may in theory modify the repo, and
       so must invalidate the status cache *)

    fun invalidate (context : context) libname : unit =
        StatusCache.drop libname (#cache context)        
            
    fun pull context (libname, source) =
        let val () = invalidate context libname
            val url = remote_for context (libname, source)
        in
            hg_command context libname
                       ((if FileBits.verbose ()
                         then ["pull", url]
                         else ["pull", "-q", url])
			@ hg_extra_clone_pull_args)
        end

    fun is_newest context (libname, source, branch) =
        case is_newest_locally context (libname, branch) of
            ERROR e => ERROR e
          | OK false => OK false
          | OK true =>
            (* only this branch needs to invalidate the status cache,
               and pull does that *)
            case pull context (libname, source) of
                ERROR e => ERROR e
              | _ => is_newest_locally context (libname, branch)
                
    fun checkout context (libname, source, branch) =
        let val () = invalidate context libname
            val url = remote_for context (libname, source)
        in
            (* make the lib dir rather than just the ext dir, since
               the lib dir might be nested and hg will happily check
               out into an existing empty dir anyway *)
            case FileBits.mkpath (FileBits.libpath context libname) of
                ERROR e => ERROR e
              | _ => hg_command context ""
                                (["clone", "-u", branch_name branch,
                                  url, libname] @ hg_extra_clone_pull_args)
        end
                                                    
    fun update context (libname, source, branch) =
        let (* pull invalidates the cache, as we must here *)
            val pull_result = pull context (libname, source)
        in
            case hg_command context libname ["update", branch_name branch] of
                ERROR e => ERROR e
              | _ =>
                case pull_result of
                    ERROR e => ERROR e
                  | _ =>
                    let val () = StatusCache.drop libname (#cache context)
                    in
                        OK ()
                    end
        end

    fun update_to context (libname, _, "") =
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, source, id) = 
        let (* pull invalidates the cache, as we must here *)
            val pull_result = pull context (libname, source)
        in
            case hg_command context libname ["update", "-r", id] of
                OK _ => OK ()
              | ERROR e =>
                case pull_result of
                    ERROR e' => ERROR e' (* this was the ur-error *)
                  | _ => ERROR e
        end

    fun copy_url_for context libname =
        OK (FileBits.file_url (FileBits.libpath context libname))
            
end
