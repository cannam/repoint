
fun archive_project ({ context, ... } : project) =

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
       Vext itself?

       There doesn't appear to be a mkdtemp equivalent in the Basis
       library... we could put the temporary target within
       .vext-archive in the local project directory, or something.
     *)
