
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
            
    fun remote_branch_name context (libname, branch) =
        our_remote ^ "/" ^ local_branch_name context (libname, branch)

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
            
    fun is_at context (libname, id_or_tag) =
        case id_of context libname of
            ERROR e => OK false (* HEAD nonexistent, expected in empty repo *)
          | OK id =>
            if String.isPrefix id_or_tag id orelse
               String.isPrefix id id_or_tag
            then OK true
            else is_at_tag context (libname, id, id_or_tag)

    and is_at_tag context (libname, id, tag) =
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
                           
    fun branch_tip context (libname, branch) =
        (* We don't have access to the source info or the network
           here, as this is used by status (e.g. via is_on_branch) as
           well as review. It's possible the remote branch won't exist,
           e.g. if the repo was checked out by something other than
           Repoint, and if that's the case, we can't add it here; we'll
           just have to fail, since checking against local branches
           instead could produce the wrong result. *)
        git_command_output context libname
                           ["rev-list", "-1",
                            remote_branch_name context (libname, branch),
                            "--"]
                       
    fun is_newest_locally context (libname, branch) =
        case branch_tip context (libname, branch) of
            ERROR e => OK false
          | OK rev => is_at context (libname, rev)

    fun is_on_branch context (libname, branch) =
        case branch_tip context (libname, branch) of
            ERROR e => OK false
          | OK rev =>
            case is_at context (libname, rev) of
                ERROR e => ERROR e
              | OK true => OK true
              | OK false =>
                case git_command context libname
                                 ["merge-base", "--is-ancestor",
                                  "HEAD",
                                  remote_branch_name context (libname, branch)
                                 ] of
                    ERROR e => OK false  (* cmd returns non-zero for no *)
                  | _ => OK true

    fun fetch context (libname, source) =
        case add_our_remote context (libname, source) of
            ERROR e => ERROR e
          | _ => git_command context libname ["fetch", our_remote]
                            
    fun is_newest context (libname, source, branch) =
        case add_our_remote context (libname, source) of
            ERROR e => ERROR e
          | OK () => 
            case is_newest_locally context (libname, branch) of
                ERROR e => ERROR e
              | OK false => OK false
              | OK true =>
                case fetch context (libname, source) of
                    ERROR e => ERROR e
                  | _ => is_newest_locally context (libname, branch)

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

    (* This function updates to the latest revision on a branch rather
       than to a specific id or tag. We can't just checkout the given
       local branch, as that will succeed even if it isn't up to
       date. Instead fetch and reset the branch based on the
       remote. *)

    fun update context (libname, source, branch) =
        case fetch context (libname, source) of
            ERROR e => ERROR e
          | _ =>
            case git_command context libname
                             ["checkout",
                              "-B",
                              local_branch_name context (libname, branch),
                              "--track",
                              remote_branch_name context (libname, branch)] of
                ERROR e => ERROR e
              | _ => OK ()

    (* This function is dealing with a specific id or tag, so if we
       can successfully check it out (detached) then that's all we
       need to do, regardless of whether fetch succeeded or not. We do
       attempt the fetch first, though, purely in order to avoid ugly
       error messages in the common case where we're being asked to
       update to a new pin (from the lock file) that hasn't been
       fetched yet. And after checking out detached, test whether we
       are actually somewhere on the branch we are supposed to be
       using and if so, reset it to this commit locally. *)

    fun update_to context (libname, _, _, "") = 
        ERROR "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, source, branch, id) =
        let val fetch_result = fetch context (libname, source)
        in
            case git_command context libname
                             ["checkout", "--detach", id] of
                OK () =>
                (case is_on_branch context (libname, branch) of
                     OK true => 
                     git_command context libname
                                 ["checkout", "-B",
                                  local_branch_name context (libname, branch),
                                  id]
                   | OK false => OK ()
                   | ERROR e' => ERROR e')
              | ERROR e =>
                case fetch_result of
                    ERROR e' => ERROR e' (* this was the ur-error *)
                  | _ => ERROR e
        end

    fun copy_url_for context libname =
        OK (FileBits.file_url (FileBits.libpath context libname))
            
end
