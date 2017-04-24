
datatype vcs =
         HG |
         GIT

datatype provider =
         URL of string |
         SERVICE of {
             host : string,
             owner : string,
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

datatype result =
         OK |
         ERROR of string

datatype output =
         SUCCEED of string |
         FAIL of string

datatype branch =
         BRANCH of string |
         DEFAULT_BRANCH
                                        
type libname = string

type libspec = {
    libname : libname,
    vcs : vcs,
    provider : provider,
    branch : branch,
    pin : pin
}

type context = {
    rootpath : string,
    extdir : string
}

type config = {
    context : context,
    libs : libspec list
}

signature VCS_CONTROL = sig
    val exists : context -> libname -> bool
    val is_at : context -> libname -> string -> bool
    val is_newest : context -> libname * provider * branch -> bool
    val checkout : context -> libname * provider * branch -> result
    val update : context -> libname * provider * branch -> result
    val update_to : context -> libname * provider * string -> result
end

signature LIB_CONTROL = sig
    val check : context -> libspec -> libstate
    val update : context -> libspec -> result
end
