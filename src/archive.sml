
structure Archive :> sig

    val archive : string -> project -> OS.Process.status
        
end = struct

    (* The idea of "archive" is to replace hg/git archive, which won't
       include files, like the Vext-introduced external libraries,
       that are not under version control with the main repo.

       The process goes like this:

       - Make sure we have a target filename from the user, and take
         its basename as our archive directory name

       - Make an "archive root" subdir of the project repo, named
         typically .vext-archive
       
       - Identify the VCS used for the project repo

       - Synthesise a Vext project with the archive root as its
         root path, "." as its extdir, with one library whose
         name is the user-supplied basename and whose explicit
         source URL is the original project root; update that
         project -- thus cloning the original project to a subdir
         of the archive root

       - Synthesise a Vext project identical to the original one for
         this project, but with the newly-cloned copy as its root
         path; update that project -- thus checking out clean copies
         of the external library dirs

       - Call out to an archive program to archive up the new copy,
         running e.g.
         tar cvzf project-release.tar.gz \
             --exclude=.hg --exclude=.git project-release
         in the archive root dir

       - (We also omit the vext-project.json file and any trace of
         Vext. It can't properly be run in a directory where the
         external project folders already exist but their repo history
         does not. End users shouldn't get to see Vext)

       - Clean up by deleting the new copy
    *)

    fun identify_vcs dir =
        let val metadirs = [
                (".hg",  HG),
                (".git", GIT)
            ]
            fun matching (metadir, vcs) =
                OS.FileSys.isDir (OS.Path.joinDirFile {
                                       dir = dir,
                                       file = metadir
                                 })
                handle _ => false
        in
            case 
                foldl (fn ((metadir, vcs), acc) =>
                          case acc of
                              SOME vcs => SOME vcs
                            | NONE => if matching (metadir, vcs)
                                      then SOME vcs
                                      else NONE)
                      NONE
                      metadirs
             of
                NONE => ERROR ("Unable to identify VCS for directory " ^ dir)
              | SOME vcs => OK vcs
        end

    fun make_archive_root context =
        let val path = OS.Path.joinDirFile {
                    dir = #rootpath context,
                    file = VextFilenames.archive_dir
                }
        in
            case FileBits.mkpath path of
                ERROR e => raise Fail ("Failed to create archive directory \""
                                       ^ path ^ "\": " ^ e)
              | OK () => path
        end

    fun archive_path archive_dir target_name =
        OS.Path.joinDirFile {
            dir = archive_dir,
            file = target_name
        }

    fun check_nonexistent path =
        case SOME (OS.FileSys.fileSize path) handle OS.SysErr _ => NONE of
            NONE => ()
          | _ => raise Fail ("Path " ^ path ^ " exists, not overwriting")
            
    fun make_archive_copy target_name vcs ({ context, ... } : project) =
        let val archive_root = make_archive_root context
            val synthetic_context = {
                rootpath = archive_root,
                extdir = ".",
                providers = [],
                accounts = []
            }
            val synthetic_library = {
                libname = target_name,
                vcs = vcs,
                source = URL_SOURCE ("file://" ^ (#rootpath context)),
                branch = DEFAULT_BRANCH, (*!!! Need current branch of project? *)
                project_pin = UNPINNED,  (*!!! Need current id? *)
                lock_pin = UNPINNED
            }
            val path = archive_path archive_root target_name
            val _ = print ("Cloning original project to " ^ path ^ "...\n");
            val _ = check_nonexistent path
        in
            case AnyLibControl.update synthetic_context synthetic_library of
                ERROR e => ERROR ("Failed to clone original project to "
                                  ^ path ^ ": " ^ e)
              | OK _ => OK archive_root
        end

    fun update_archive archive_root target_name (project as { context, ... }) =
        let val synthetic_context = {
                rootpath = archive_path archive_root target_name,
                extdir = #extdir context,
                providers = #providers context,
                accounts = #accounts context
            }
        in
            foldl (fn (lib, acc) =>
                      case acc of
                          ERROR e => ERROR e
                        | OK _ => AnyLibControl.update synthetic_context lib)
                  (OK "")
                  (#libs project)
        end

    fun pack_archive archive_root target_name target_path =
        case FileBits.command {
                rootpath = archive_root,
                extdir = ".",
                providers = [],
                accounts = []
            } "" [
                "tar", "czf", (*!!! shouldn't be hardcoding this *)
                target_path,
                "--exclude=.hg", (*!!! should come from known-vcs list *)
                "--exclude=.git",
                "--exclude=vext",
                "--exclude=vext.sml",
                "--exclude=vext.ps1",
                "--exclude=vext.bat",
                "--exclude=vext-project.json",
                "--exclude=vext-lock.json",
                target_name
            ] of
            ERROR e => ERROR e
          | OK _ => FileBits.rmpath (archive_path archive_root target_name)
            
    fun basename path =
        (*!!! should strip known archive suffixes, so e.g. 
              release-v1.0.tar.gz -> release-v1.0, not
              release-v1 or release-v1.0.tar *)
        let val filename = OS.Path.file path
            val bits = String.tokens (fn c => c = #".") filename
        in
            case bits of
                [] => raise Fail "Target filename must not be empty"
              | b::_ => b
        end
            
    fun archive target_path (project : project) =
        let val _ = check_nonexistent target_path
            val name = basename target_path
            val outcome =
                case identify_vcs (#rootpath (#context project)) of
                    ERROR e => ERROR e
                  | OK vcs =>
                    case make_archive_copy name vcs project of
                        ERROR e => ERROR e
                      | OK archive_root => 
                        case update_archive archive_root name project of
                            ERROR e => ERROR e
                          | OK _ =>
                            case pack_archive archive_root name target_path of
                                ERROR e => ERROR e
                              | OK _ => OK ()
        in
            case outcome of
                ERROR e => raise Fail e
              | OK () => OS.Process.success
        end
            
end
