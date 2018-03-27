
type exclusions = string list
              
structure Archive :> sig

    val archive : string * exclusions -> project -> OS.Process.status
        
end = struct

    (* The idea of "archive" is to replace hg/git archive, which won't
       include files, like the Repoint-introduced external libraries,
       that are not under version control with the main repo.

       The process goes like this:

       - Make sure we have a target filename from the user, and take
         its basename as our archive directory name

       - Make an "archive root" subdir of the project repo, named
         typically .repoint-archive
       
       - Identify the VCS used for the project repo. Note that any
         explicit references to VCS type in this structure are to
         the VCS used for the project (something Repoint doesn't 
         otherwise care about), not for an individual library

       - Synthesise a Repoint project with the archive root as its
         root path, "." as its extdir, with one library whose
         name is the user-supplied basename and whose explicit
         source URL is the original project root; update that
         project -- thus cloning the original project to a subdir
         of the archive root

       - Synthesise a Repoint project identical to the original one for
         this project, but with the newly-cloned copy as its root
         path; update that project -- thus checking out clean copies
         of the external library dirs

       - Call out to an archive program to archive up the new copy,
         running e.g.
         tar cvzf project-release.tar.gz \
             --exclude=.hg --exclude=.git project-release
         in the archive root dir

       - (We also omit the repoint-project.json file and any trace of
         Repoint. It can't properly be run in a directory where the
         external project folders already exist but their repo history
         does not. End users shouldn't get to see Repoint)

       - Clean up by deleting the new copy
    *)

    fun project_vcs_id_and_url dir =
        let val context = {
                rootpath = dir,
                extdir = ".",
                providers = [],
                accounts = []
            }
            val vcs_maybe = 
                case [HgControl.exists context ".",
                      GitControl.exists context ".",
                      SvnControl.exists context "."] of
                    [OK true, OK false, OK false] => OK HG
                  | [OK false, OK true, OK false] => OK GIT
                  | [OK false, OK false, OK true] => OK SVN
                  | _ => ERROR ("Unable to identify VCS for directory " ^ dir)
        in
            case vcs_maybe of
                ERROR e => ERROR e
              | OK vcs =>
                case (fn HG => HgControl.id_of
                       | GIT => GitControl.id_of 
                       | SVN => SvnControl.id_of)
                         vcs context "." of
                    ERROR e => ERROR ("Unable to find id of project repo: " ^ e)
                  | OK id =>
                    case (fn HG => HgControl.copy_url_for
                           | GIT => GitControl.copy_url_for
                           | SVN => SvnControl.copy_url_for)
                             vcs context "." of
                        ERROR e => ERROR ("Unable to find URL of project repo: "
                                          ^ e)
                      | OK url => OK (vcs, id, url)
        end
            
    fun make_archive_root (context : context) =
        let val path = OS.Path.joinDirFile {
                    dir = #rootpath context,
                    file = RepointFilenames.archive_dir
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
            
    fun make_archive_copy target_name (vcs, project_id, source_url)
                          ({ context, ... } : project) =
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
                source = URL_SOURCE source_url,
                branch = DEFAULT_BRANCH, (* overridden by pinned id below *)
                project_pin = PINNED project_id,
                lock_pin = PINNED project_id
            }
            val path = archive_path archive_root target_name
            val _ = print ("Cloning original project to " ^ path
                           ^ " at revision " ^ project_id ^ "...\n");
            val _ = check_nonexistent path
        in
            case AnyLibControl.update synthetic_context synthetic_library of
                ERROR e => ERROR ("Failed to clone original project to "
                                  ^ path ^ ": " ^ e)
              | OK _ => OK archive_root
        end

    fun update_archive archive_root target_name
                       (project as { context, ... } : project) =
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
                        | OK () => AnyLibControl.update synthetic_context lib)
                  (OK ())
                  (#libs project)
        end

    datatype packer = TAR
                    | TAR_GZ
                    | TAR_BZ2
                    | TAR_XZ
    (* could add other packers, e.g. zip, if we knew how to
       handle the file omissions etc properly in pack_archive *)
                          
    fun packer_and_basename path =
        let val extensions = [ (".tar", TAR),
                               (".tar.gz", TAR_GZ),
                               (".tar.bz2", TAR_BZ2),
                               (".tar.xz", TAR_XZ)]
            val filename = OS.Path.file path
        in
            foldl (fn ((ext, packer), acc) =>
                      if String.isSuffix ext filename
                      then SOME (packer,
                                 String.substring (filename, 0,
                                                   String.size filename -
                                                   String.size ext))
                      else acc)
                  NONE
                  extensions
        end
            
    fun pack_archive archive_root target_name target_path packer exclusions =
        case FileBits.command {
                rootpath = archive_root,
                extdir = ".",
                providers = [],
                accounts = []
            } "" ([
                     "tar",
                     case packer of
                         TAR => "cf"
                       | TAR_GZ => "czf"
                       | TAR_BZ2 => "cjf"
                       | TAR_XZ => "cJf",
                     target_path,
                     "--exclude=.hg",
                     "--exclude=.git",
                     "--exclude=.svn",
                     "--exclude=repoint",
                     "--exclude=repoint.sml",
                     "--exclude=repoint.ps1",
                     "--exclude=repoint.bat",
                     "--exclude=repoint-project.json",
                     "--exclude=repoint-lock.json"
                 ] @ (map (fn e => "--exclude=" ^ e) exclusions) @
                  [ target_name ])
         of
            ERROR e => ERROR e
          | OK _ => FileBits.rmpath (archive_path archive_root target_name)
            
    fun archive (target_path, exclusions) (project : project) =
        let val _ = check_nonexistent target_path
            val (packer, name) =
                case packer_and_basename target_path of
                    NONE => raise Fail ("Unsupported archive file extension in "
                                        ^ target_path)
                  | SOME pn => pn
            val details =
                case project_vcs_id_and_url (#rootpath (#context project)) of
                    ERROR e => raise Fail e
                  | OK details => details
            val archive_root =
                case make_archive_copy name details project of
                    ERROR e => raise Fail e
                  | OK archive_root => archive_root
            val outcome = 
                case update_archive archive_root name project of
                    ERROR e => ERROR e
                  | OK _ =>
                    case pack_archive archive_root name
                                      target_path packer exclusions of
                        ERROR e => ERROR e
                      | OK _ => OK ()
        in
            case outcome of
                ERROR e => raise Fail e
              | OK () => OS.Process.success
        end
            
end
