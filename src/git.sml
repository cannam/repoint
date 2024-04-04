
structure GitControl :> VCS_CONTROL = struct

    (* With Git repos we are intentionally careless about the state of
       the local branch whose name we are given - we work by checking
       out either a specific commit (perhaps in detached HEAD state)
       or resetting our local branch based on the remote. The remote
       we use is always named repoint, and we update it to the
       expected URL each time we fetch, in order to ensure we update
       properly if the location given in the project file changes. *)

    val git_program = "git"
                      
    fun git_command context libname args =
        FileBits.command context libname (git_program :: args)

    fun git_command_output context libname args =
        FileBits.command_output context libname (git_program :: args)

    fun is_working context =
        case git_command_output context "" ["--version"] of
            OK "" => OK false
          | OK _ => OK true
          | ERROR e => ERROR e
                            
    fun exists context libname =
        OK (OS.FileSys.isDir (FileBits.subpath context libname ".git"))
        handle _ => OK false

    fun remote_for context (libname, source) =
        Provider.remote_url context GIT source libname

    val our_remote = "repoint"
    val fallback_default_branch = "master" (* only if it can't be determined *)
                                        
    fun default_branch_name context libname =
        let fun return_fallback msg =
                (if FileBits.verbose ()
                 then print ("\n" ^ msg ^ "\n")
                 else ();
                 fallback_default_branch)
        in
            let val headfile = FileBits.subpath
                                   context libname
                                   (".git/refs/remotes/" ^ our_remote ^ "/HEAD")
                val headspec = FileBits.file_contents headfile
            in
                case String.tokens (fn c => c = #" ") headspec of
                    ["ref:", refpath] =>
                    (case String.fields (fn c => c = #"/") refpath of
                         "refs" :: "remotes" :: _ :: rest =>
                         String.concatWith "/" rest
                       | _ =>
                         return_fallback
                             ("Unable to extract default branch from "
                              ^ "HEAD ref \"" ^ refpath ^ "\""))
                  | _ =>
                    return_fallback ("Unable to extract HEAD ref from \""
                                     ^ headspec ^ "\"")
            end
            handle IO.Io _ =>
                   return_fallback "Unable to read HEAD ref file"
        end

    fun local_branch_name context (libname, branch) =
        case branch of
            BRANCH b => b
          | DEFAULT_BRANCH => default_branch_name context libname

    fun remote_branch_for branch_name =
        our_remote ^ "/" ^ branch_name
                                                  
    fun add_our_remote context (libname, source) =
        (* When we do the checkout ourselves (above), we add the
           remote at the same time. But if the repo was cloned by
           someone else, we'll need to do it after the fact. Git
           doesn't seem to have a means to add a remote or change its
           url if it already exists; seems we have to do this: *)
        let val url = remote_for context (libname, source)
        in
            case git_command context libname
                             ["remote", "set-url", our_remote, url] of
                OK () => OK ()
              | ERROR e => git_command context libname
                                       ["remote", "add", "-f", our_remote, url]
        end

    (* NB git rev-parse HEAD shows revision id of current checkout;
       git rev-list -1 <tag> shows revision id of revision with that tag *)

    fun id_of context libname =
        git_command_output context libname ["rev-parse", "HEAD"]

    fun symbolic_id_of context libname =
        git_command_output context libname ["rev-parse", "--abbrev-ref", "HEAD"]

    fun is_at_tag context (libname, id, tag) =
        (* For annotated tags (with message) show-ref returns the tag
           object ref rather than that of the revision being tagged;
           we need the subsequent rev-list to chase that up. In fact
           the rev-list on its own is enough to get us the id direct
           from the tag name, but it fails with an error if the tag
           doesn't exist, whereas we want to handle that quietly in
           case the tag simply hasn't been pulled yet *)
        case git_command_output context libname
                                ["show-ref", "refs/tags/" ^ tag, "--"] of
            OK "" => OK false (* Not a tag *)
          | ERROR _ => OK false
          | OK s =>
            let val tag_ref = hd (String.tokens (fn c => c = #" ") s)
            in
                case git_command_output context libname
                                        ["rev-list", "-1", tag_ref] of
                    OK tagged => OK (id = tagged)
                  | ERROR _ => OK false
            end

    fun ids_match id1 id2 =
        String.isPrefix id1 id2 orelse
        String.isPrefix id2 id1

    fun is_commit_at context (libname, id_or_tag) id =
        if ids_match id_or_tag id
        then OK true
        else is_at_tag context (libname, id, id_or_tag)
                        
    fun is_at context (libname, id_or_tag) =
        case id_of context libname of
            ERROR e => OK false (* HEAD nonexistent, expected in empty repo *)
          | OK id => is_commit_at context (libname, id_or_tag) id
                           
    fun branch_tip context (libname, branch_name) =
        (* We don't have access to the source info or the network
           here, as this is used by status (e.g. via is_on_branch) as
           well as review. It's possible the remote branch won't exist,
           e.g. if the repo was checked out by something other than
           Repoint, and if that's the case, we can't add it here; we'll
           just have to fail, since checking against local branches
           instead could produce the wrong result. *)
        git_command_output context libname
                           ["rev-list", "-1",
                            remote_branch_for branch_name,
                            "--"]

    fun is_branch_ancestor context (libname, branch_name) commit =
        case git_command context libname
                         ["merge-base", "--is-ancestor",
                          commit,
                          remote_branch_for branch_name
                         ] of
            ERROR e => OK false  (* cmd returns non-zero for no *)
          | _ => OK true
                            
    fun is_tip_or_ancestor_by_name context (libname, branch_name) =
        case branch_tip context (libname, branch_name) of
            ERROR e => OK false
          | OK rev =>
            case is_at context (libname, rev) of
                ERROR e => ERROR e
              | OK true => OK true
              | OK false =>
                is_branch_ancestor context (libname, branch_name) "HEAD"
                            
    fun is_commit_tip_or_ancestor_by_name context (libname, branch_name) id =
        case branch_tip context (libname, branch_name) of
            ERROR e => OK false
          | OK rev =>
            case is_commit_at context (libname, rev) id of
                ERROR e => ERROR e
              | OK true => OK true
              | OK false =>
                is_branch_ancestor context (libname, branch_name) id
                            
    fun is_on_branch context (libname, branch) =
        let val branch_name = local_branch_name context (libname, branch)
        in
            is_tip_or_ancestor_by_name context (libname, branch_name)
        end
                       
    fun is_newest_locally_by_name context (libname, branch_name) =
        case branch_tip context (libname, branch_name) of
            ERROR e => OK false
          | OK rev => is_at context (libname, rev)
                            
    fun is_newest_locally context (libname, branch) =
        let val branch_name = local_branch_name context (libname, branch)
        in
            is_newest_locally_by_name context (libname, branch_name)
        end

    fun fetch context (libname, source) =
        case add_our_remote context (libname, source) of
            ERROR e => ERROR e
          | _ => git_command context libname ["fetch", our_remote]
                            
    fun is_newest_by_name context (libname, source, branch_name) =
        case add_our_remote context (libname, source) of
            ERROR e => ERROR e
          | OK () => 
            case is_newest_locally_by_name context (libname, branch_name) of
                ERROR e => ERROR e
              | OK false => OK false
              | OK true =>
                case fetch context (libname, source) of
                    ERROR e => ERROR e
                  | _ =>
                    is_newest_locally_by_name context (libname, branch_name)

    fun is_newest context (libname, source, branch) =
        let val branch_name = local_branch_name context (libname, branch)
        in
            is_newest_by_name context (libname, source, branch_name)
        end

    fun is_modified_locally context libname =
        case git_command_output context libname
                                ["status", "--porcelain",
                                 "--untracked-files=no" ] of
            ERROR e => ERROR e
          | OK "" => OK false
          | OK _ => OK true

    fun checkout context (libname, source, branch) =
        let val url = remote_for context (libname, source)
        in
            (* make the lib dir rather than just the ext dir, since
               the lib dir might be nested and git will happily check
               out into an existing empty dir anyway *)
            case FileBits.mkpath (FileBits.libpath context libname) of
                ERROR e => ERROR e
              | OK () =>
                git_command context ""
                            (case branch of
                                 DEFAULT_BRANCH =>
                                 ["clone", "--origin", our_remote,
                                  url, libname]
                               | BRANCH b => 
                                 ["clone", "--origin", our_remote,
                                  "--branch", b,
                                  url, libname])
        end

    (* Generally speaking, when updating to a new commit from a remote
       branch, we can reset the local branch to that commit only if it
       was previously pointing at an ancestor of it. Otherwise it's
       possible the user has made some unpushed commits locally that
       we would lose, and we should avoid moving the local branch. *)

    fun can_reset_for context (libname, branch_name) =
        case git_command_output context libname ["rev-parse", branch_name] of
            ERROR _ => true
          | OK id => 
            case is_commit_tip_or_ancestor_by_name
                     context (libname, branch_name) id of
                ERROR _ => true
              | OK result => result
            
    (* This function updates to the latest revision on a branch rather
       than to a specific id or tag. We can't just checkout the given
       local branch, as that will succeed even if it isn't up to
       date. Instead fetch and check out the commit identified by the
       remote branch, resetting the local branch if can_reset_for says
       we can. *)

    fun update context (libname, source, branch) =
        let val branch_name = local_branch_name context (libname, branch)
            val remote_branch_name = remote_branch_for branch_name
            val fetch_result = fetch context (libname, source)
            (* NB it matters that we do the fetch before can_reset_for *)
            val should_reset = can_reset_for context (libname, branch_name)
        in
            case fetch_result of
                ERROR e => ERROR e
              | _ =>
                case git_command context libname
                                 (if should_reset
                                  then ["checkout",
                                        "-B", branch_name, "--track",
                                        remote_branch_name]
                                  else ["checkout",
                                        "--detach",
                                        remote_branch_name]
                                 ) of
                    ERROR e => ERROR e
                  | _ => OK ()
        end

    (* This function is dealing with a specific id or tag, so if we
       can successfully check it out then that's all we strictly need
       to do. As with update, we reset the local branch if
       can_reset_for says we can, but with the extra condition that
       the commit we're resetting to is also on the given branch. *)

    fun update_to context (libname, _, _, "") = 
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, source, branch, id) =
        let val branch_name = local_branch_name context (libname, branch)
            val fetch_result = fetch context (libname, source)
            (* NB it matters that we do the fetch before can_reset_for *)
            val should_reset =
                if can_reset_for context (libname, branch_name)
                then case branch_tip context (libname, branch_name) of
                         ERROR _ => true
                       | OK tip_id =>
                         if ids_match tip_id id
                         then true
                         else case is_branch_ancestor
                                       context (libname, branch_name) id of
                                  ERROR _ => true
                                | OK result => result 
                else false
        in
            case git_command context libname
                             (if should_reset
                              then ["checkout",
                                    "-B", branch_name,
                                    id]
                              else ["checkout",
                                    "--detach",
                                    id]
                             ) of
                OK _ => OK()
              | ERROR e =>
                case fetch_result of
                    ERROR e' => ERROR e' (* this was the ur-error *)
                  | _ => ERROR e
        end

    fun copy_url_for context libname =
        OK (FileBits.file_url (FileBits.libpath context libname))
            
end
