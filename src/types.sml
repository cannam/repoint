
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

datatype branch =
         BRANCH of string |
         DEFAULT_BRANCH
             
(* If we can recover from an error, for example by reporting failure
   for this one thing and going on to the next thing, then the error
   should usually be returned through a result type rather than an
   exception. *)
             
datatype 'a result =
         OK of 'a |
         ERROR of string

type libname = string

type id_or_tag = string

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
    val exists : context -> libname -> bool result
    val is_at : context -> libname * id_or_tag -> bool result
    val is_newest : context -> libname * source * branch -> bool result
    val is_locally_modified : context -> libname -> bool result
    val checkout : context -> libname * source * branch -> unit result
    val update : context -> libname * source * branch -> unit result
    val update_to : context -> libname * source * string -> unit result
end

signature LIB_CONTROL = sig
    val review : context -> libspec -> (libstate * localstate) result
    val status : context -> libspec -> (libstate * localstate) result
    val update : context -> libspec -> unit result
end
