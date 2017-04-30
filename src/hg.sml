
structure HgControl :> VCS_CONTROL = struct
                            
    type vcsstate = { id: string, modified: bool,
                      branch: string, tags: string list }
                  
    fun exists context libname =
        OS.FileSys.isDir (FileBits.subpath context libname ".hg")
        handle _ => false

    fun remote_for context (libname, source) =
        Provider.remote_url (#providers context) HG source libname

    fun current_state context libname : vcsstate =
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
            and state_for (id, branch, tags) = { id = extract_id id,
                                                 modified = is_modified id,
                                                 branch = extract_branch branch,
                                                 tags = split_tags tags }
        in        
            case FileBits.command_output context libname ["hg", "id"] of
                FAIL err => raise Fail err
              | SUCCEED out =>
                case String.tokens (fn x => x = #" ") out of
                    [id, branch, tags] => state_for (id, branch, tags)
                  | [id, other] => if is_branch other
                                   then state_for (id, other, "")
                                   else state_for (id, "", other)
                  | [id] => state_for (id, "", "")
                  | _ => raise Fail ("Unexpected output from hg id: " ^ out)
        end

    fun branch_name branch = case branch of
                                 DEFAULT_BRANCH => "default"
                               | BRANCH b => b

    fun is_at context libname id_or_tag =
        case current_state context libname of
            { id, tags, ... } => 
            String.isPrefix id_or_tag id orelse
            String.isPrefix id id_or_tag orelse
            List.exists (fn t => t = id_or_tag) tags

    fun has_incoming context (libname, source, branch) =
        case FileBits.command_output
                 context libname
                 ["hg", "incoming", "-l1", "-b", branch_name branch,
                  "--template", "{node}"] of
            FAIL err => false (* hg incoming is odd that way *)
          | SUCCEED incoming => 
            incoming <> "" andalso
            not (String.isSubstring "no changes found" incoming)
                        
    fun is_newest context (libname, source, branch) =
        case FileBits.command_output
                 context libname
                 ["hg", "log", "-l1", "-b", branch_name branch,
                  "--template", "{node}"] of
            FAIL err => raise Fail err
          | SUCCEED newest_in_repo => 
            is_at context libname newest_in_repo andalso
            not (has_incoming context (libname, source, branch))

    fun is_locally_modified context libname =
        case current_state context libname of
            { modified, ... } => modified
                
    fun checkout context (libname, source, branch) =
        let val command = FileBits.command context ""
            val url = remote_for context (libname, source)
        in
            case FileBits.mkpath (FileBits.extpath context) of
                OK => command ["hg", "clone", "-u", branch_name branch,
                               url, libname]
              | ERROR e => ERROR e
        end
                                                    
    fun update context (libname, source, branch) =
        let val command = FileBits.command context libname
            val url = remote_for context (libname, source)
            val pull_result = command ["hg", "pull", url]
        in
            case command ["hg", "update", branch_name branch] of
                OK => pull_result
              | ERROR e => ERROR e
        end

    fun update_to context (libname, source, "") =
        raise Fail "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, source, id) = 
        let val command = FileBits.command context libname
            val url = remote_for context (libname, source)
        in
            case command ["hg", "update", "-r" ^ id] of
                OK => OK
              | ERROR _ => 
                case command ["hg", "pull", url] of
                    OK => command ["hg", "update", "-r" ^ id]
                  | ERROR e => ERROR e
        end
                  
end
