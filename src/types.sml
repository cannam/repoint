
datatype vcs =
         HG |
         GIT |
         SVN

datatype source =
         URL_SOURCE of string |
         SERVICE_SOURCE of {
             service : string,
             owner : string option,
             repo : string option
         }

type id_or_tag = string

datatype pin =
         UNPINNED |
         PINNED of id_or_tag

datatype libstate =
         ABSENT |
         CORRECT |
         SUPERSEDED |
         WRONG

datatype localstate =
         MODIFIED |
         LOCK_MISMATCHED |
         CLEAN

datatype branch =
         BRANCH of string |  (* Non-empty *)
         DEFAULT_BRANCH
             
(* If we can recover from an error, for example by reporting failure
   for this one thing and going on to the next thing, then the error
   should usually be returned through a result type rather than an
   exception. *)
             
datatype 'a result =
         OK of 'a |
         ERROR of string

type libname = string

type libspec = {
    libname : libname,
    vcs : vcs,
    source : source,
    branch : branch,
    project_pin : pin,
    lock_pin : pin
}

type lock = {
    libname : libname,
    id_or_tag : id_or_tag
}

type remote_spec = {
    anon : string option,
    auth : string option
}

type provider = {
    service : string,
    supports : vcs list,
    remote_spec : remote_spec
}

type account = {
    service : string,
    login : string
}

type status_rec = {
    libname : libname,
    status : string
}

type status_cache = status_rec list ref
                  
type context = {
    rootpath : string,
    extdir : string,
    providers : provider list,
    accounts : account list,
    cache : status_cache
}

type userconfig = {
    providers : provider list,
    accounts : account list
}
                   
type project = {
    context : context,
    libs : libspec list
}

structure RepointFilenames = struct
    val project_file = "repoint-project.json"
    val project_lock_file = "repoint-lock.json"
    val project_completion_file = ".repoint.point"
    val user_config_file = ".repoint.json"
    val archive_dir = ".repoint-archive"
end
                   
signature VCS_CONTROL = sig

    (** Check whether the given VCS is installed and working *)
    val is_working : context -> bool result
    
    (** Test whether the library is present locally at all *)
    val exists : context -> libname -> bool result
                                            
    (** Return the id (hash) of the current revision for the library *)
    val id_of : context -> libname -> id_or_tag result

    (** Test whether the library is at the given id *)
    val is_at : context -> libname * id_or_tag -> bool result

    (** Test whether the library is on the given branch, i.e. is at
        the branch tip or an ancestor of it *)
    val is_on_branch : context -> libname * branch -> bool result

    (** Test whether the library is at the newest revision for the
        given branch. False may indicate that the branch has advanced
        or that the library is not on the branch at all. This function
        may use the network to check for new revisions *)
    val is_newest : context -> libname * source * branch -> bool result

    (** Test whether the library is at the newest revision available
        locally for the given branch. False may indicate that the
        branch has advanced or that the library is not on the branch
        at all. This function must not use the network *)
    val is_newest_locally : context -> libname * branch -> bool result

    (** Test whether the library has been modified in the local
        working copy *)
    val is_modified_locally : context -> libname -> bool result

    (** Check out, i.e. clone a fresh copy of, the repo for the given
        library on the given branch *)
    val checkout : context -> libname * source * branch -> unit result

    (** Update the library to the given branch tip. Assumes that a
        local copy of the library already exists *)
    val update : context -> libname * source * branch -> unit result

    (** Update the library to the given specific id or tag,
        understanding that we are expected to be on the given branch *)
    val update_to : context -> libname * source * branch * id_or_tag -> unit result

    (** Return a URL from which the library can be cloned, given that
        the local copy already exists. For a DVCS this can be the
        local copy, but for a centralised VCS it will have to be the
        remote repository URL. Used for archiving *)
    val copy_url_for : context -> libname -> string result
end

signature LIB_CONTROL = sig
    val review : context -> libspec -> (libstate * localstate) result
    val status : context -> libspec -> (libstate * localstate) result
    val update : context -> libspec -> unit result
    val id_of : context -> libspec -> id_or_tag result
    val is_working : context -> vcs -> bool result
end
