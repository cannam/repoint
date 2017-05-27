
datatype vcs =
         HG |
         GIT

datatype source =
         URL of string |
         PROVIDER of {
             service : string,
             owner : string option,
             repo : string option
         }

datatype pin =
         UNPINNED |
         PINNED of string

datatype libstate =
         ABSENT |
         CORRECT |
         SUPERSEDED |
         WRONG

datatype localstate =
         MODIFIED |
         UNMODIFIED
             
(* If we can recover from an error, for example by reporting failure
   for this one thing and going on to the next thing, then the error
   should probably be reported using a result type. *)
             
datatype 'a result =
         OK of 'a |
         ERROR of string

(* If we can't recover from it, then it should be an exception, like
   this one. *)

exception UsageError of string

(*!!! That doesn't tell us what to do about errors that occur at a
   lower level than the function being called. For example, we call
   is_at on a VCS_CONTROL structure, but the invocation of hg/git
   fails. *)
                            
datatype branch =
         BRANCH of string |
         DEFAULT_BRANCH

type libname = string

type libspec = {
    libname : libname,
    vcs : vcs,
    source : source,
    branch : branch,
    pin : pin
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
                    
type context = {
    rootpath : string,
    extdir : string,
    providers : provider list,
    accounts : account list
}

type userconfig = {
    providers : provider list,
    accounts : account list
}
                   
type project = {
    context : context,
    libs : libspec list
}

signature VCS_CONTROL = sig
    val exists : context -> libname -> bool
    val is_at : context -> libname -> string -> bool
    val is_newest : context -> libname * source * branch -> bool
    val is_locally_modified : context -> libname -> bool
    val checkout : context -> libname * source * branch -> unit result
    val update : context -> libname * source * branch -> unit result
    val update_to : context -> libname * source * string -> unit result
end

signature LIB_CONTROL = sig
    val review : context -> libspec -> libstate * localstate
    val status : context -> libspec -> libstate * localstate
    val update : context -> libspec -> unit result
end
