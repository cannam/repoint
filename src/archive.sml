
structure Archive = struct

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
        let val metadirs = [ (".hg",  HG), (".git", GIT) ]
            fun matching (metadir, vcs) =
                OS.FileSys.isDir
                    (OS.Path.joinDirFile { dir = dir, file = metadir })
                handle _ => false
        in
            foldl (fn ((metadir, vcs), acc) =>
                      case acc of
                          SOME vcs => SOME vcs
                        | NONE => if matching (metadir, vcs)
                                  then SOME vcs
                                  else NONE)
                  NONE
                  metadirs
        end

    fun archive_project target_filename ({ context, ... } : project) =
        (case identify_vcs (#rootpath context) of
             SOME HG => print "it's Mercurial!\n"
           | SOME GIT => print "it's Git!\n"
           | NONE => print "I don't know what it is!";
         OS.Process.success)
        
end
