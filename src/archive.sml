
structure Archive :> sig

    val archive : string -> project -> OS.Process.status
        
end = struct

    (* The idea of "archive" is to replace hg archive, which can't
       include files (such as the Vext-introduced external library
       files) that are not under version control at all.

       An archive process should (probably?) go like this.
       
       - Identify the version control system used for the *project*
         repo (this is not something Vext has ever had to take an
         interest in before) - bearing in mind that the vext-project
         file might not be in the project root

       - Using that VCS, clone the project repo to a temporary
         location

       - Acting within that temporary location, run "vext install"
         to install the correct dependent libraries

       - Archive up the temporary location, excluding the .hg/.git
         directories from the main directory and each of the dependent
         libraries

       - Also omit the vext-project.json file and any trace of Vext?
         After all, it can't properly be run in a directory where the
         external project folders already exist but their repo 
         history does not

       Should this be done in a shell script, rather than from
       Vext itself? That would be easier, but it would be more
       pleasing to have this built in.

       There doesn't appear to be a mkdtemp equivalent in the Basis
       library... we could put the temporary target within
       .vext-archive in the local project directory, or something.

       Let's translate this into Vext actions:

       - Obtain from the user a name for the target directory.
       This will be the basename of the target archive file, and
       the directory name that the archive unpacks to.

       - Identify the version control system used for the project
       repo - seems to be one inescapable action?

       - Make a subdir of the project repo, named something like
       .vext-archive

       - Synthesise a Vext project with .vext-archive as its
       root path, "." as its extdir, having one provider which has
       file:///path/to/original/project/root as its anonymous URL,
       with one library whose name is the user-supplied basename;
       update that project (thus cloning the original project to
       a subdir of .vext-archive)

       - Synthesise a Vext project identical to the original one
       for this project, but with that newly-cloned copy as its
       root path; update that project (thus checking out clean
       copies of its external library dirs)

       - Call out to an archive program to archive up the now-
       updated copy of the project, running e.g.
       tar cvzf project-release.tar.gz \
           --exclude=.hg --exclude=.git project-release
       in the .vext-archive dir

       - Clean up by deleting the new copy

       (What should we do if the target directory or archive name
       already exists?)

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

    fun make_archive_dir context =
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
                                 
    fun make_archive_copy target_name vcs ({ context, ... } : project) =
        let val archive_dir = make_archive_dir context
            val synthetic_context = {
                rootpath = archive_dir,
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
        in
            case AnyLibControl.update synthetic_context synthetic_library of
                ERROR e => ERROR ("Failed to clone original project to "
                                  ^ archive_dir ^ "/" ^ target_name
                                  ^ ": " ^ e)
              | OK _ => OK archive_dir
        end

    fun update_archive archive_dir target_name (project as { context, ... }) =
        let val synthetic_context = {
                rootpath = OS.Path.joinDirFile {
                    dir = archive_dir,
                    file = target_name
                },
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

    fun pack_archive archive_dir target_name target_path =
        FileBits.command {
            rootpath = archive_dir,
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
        ]

    fun basename path =
        let val filename = OS.Path.file path
            val bits = String.tokens (fn c => c = #".") filename
        in
            case bits of
                [] => raise Fail "Target filename must not be empty"
              | b::_ => b
        end

    fun check_nonexistent path =
        case SOME (OS.FileSys.fileSize path) handle OS.SysErr _ => NONE of
            NONE => ()
          | _ => raise Fail ("File " ^ path ^ " exists, not overwriting")
            
    fun archive target_path (project : project) =
        let val _ = check_nonexistent target_path
            val name = basename target_path
            val outcome =
                case identify_vcs (#rootpath (#context project)) of
                    ERROR e => ERROR e
                  | OK vcs =>
                    case make_archive_copy name vcs project of
                        ERROR e => ERROR e
                      | OK archive_dir => 
                        case update_archive archive_dir name project of
                            ERROR e => ERROR e
                          | OK _ =>
                            case pack_archive archive_dir name target_path of
                                ERROR e => ERROR e
                              | OK _ => OK ()
        in
            case outcome of
                ERROR e => raise Fail e
              | OK () => OS.Process.success
        end
            
end
