
fun lookup_optional json kk =
    let fun lookup key =
            case json of
                Json.OBJECT kvs => (case List.find (fn (k, v) => k = key) kvs of
                                        SOME (k, v) => SOME v
                                      | NONE => NONE)
              | _ => raise Fail "Object expected"
    in
        case kk of
            [] => NONE
          | key::[] => lookup key
          | key::kk => case lookup key of
                           NONE => NONE
                         | SOME j => lookup_optional j kk
    end

fun lookup_mandatory json kk =
    case lookup_optional json kk of
        SOME v => v
      | NONE => raise Fail ("Config value is mandatory: " ^
                            (String.concatWith " -> " kk))
                   
fun lookup_mandatory_string json kk =
    case lookup_optional json kk of
        SOME (Json.STRING s) => s
      | _ => raise Fail ("Config value must be string: " ^
                         (String.concatWith " -> " kk))
                   
fun lookup_optional_string json kk =
    case lookup_optional json kk of
        SOME (Json.STRING s) => SOME s
      | SOME _ => raise Fail ("Config value (if present) must be string: " ^
                              (String.concatWith " -> " kk))
      | NONE => NONE
                   
fun load_libspec json libname : libspec =
    let val libobj   = lookup_mandatory json ["libs", libname]
        val vcs      = lookup_mandatory_string libobj ["vcs"]
        val retrieve = lookup_optional_string libobj
        val service  = retrieve ["provider", "service"]
        val owner    = retrieve ["provider", "owner"]
        val repo     = retrieve ["provider", "repository"]
        val url      = retrieve ["provider", "url"]
        val branch   = retrieve ["branch"]
        val pin      = retrieve ["pin"]
    in
        {
          libname = libname,
          vcs = case vcs of
                    "hg" => HG
                  | "git" => GIT
                  | other => raise Fail ("Unknown version-control system \"" ^
                                         other ^ "\""),
          provider = case (url, service, owner, repo) of
                         (SOME u, _, _, _) => URL u
                       | (NONE, SOME ss, SOME os, r) =>
                         SERVICE { host = ss, owner = os, repo = r }
                       | _ => raise Fail ("Must have both service and owner " ^
                                          "strings in provider if no " ^
                                          "explicit url supplied"),
          pin = case pin of
                    SOME p => PINNED p
                  | NONE => UNPINNED,
          branch = case branch of
                       SOME b => BRANCH b
                     | NONE => DEFAULT_BRANCH
        }
    end  

fun load_config rootpath : config =
    let val specfile = FileBits.vexpath rootpath
        val _ = if OS.FileSys.access (specfile, [OS.FileSys.A_READ])
                then ()
                else raise Fail ("Failed to open project spec " ^
                                 (FileBits.vexfile ()) ^ " in " ^ rootpath ^
                                 ".\nPlease ensure the spec file is in the " ^
                                 "project root and run this from there.")
        val json = case Json.parse (FileBits.file_contents specfile) of
                       Json.OK json => json
                     | Json.ERROR e => raise Fail e
        val extdir = lookup_mandatory_string json ["config", "extdir"]
        val libs = lookup_optional json ["libs"]
        val libnames = case libs of
                           NONE => []
                         | SOME (Json.OBJECT ll) => map (fn (k, v) => k) ll
                         | _ => raise Fail "Object expected for libs"
    in
        {
          context = {
            rootpath = rootpath,
            extdir = extdir
          },
          libs = map (load_libspec json) libnames
        }
    end

fun usage () =
    let open TextIO in
	output (stdErr,
	    "Usage:\n" ^
            "    vext <check|update>\n");
        raise Fail "Incorrect arguments specified"
    end

fun check (config as { context, libs } : config) =
    let open AnyLibControl
        val outcomes = map (fn lib => (#libname lib, check context lib)) libs
    in
        app (fn (libname, ABSENT) => print ("ABSENT " ^ libname ^ "\n")
              | (libname, CORRECT) => print ("CORRECT " ^ libname ^ "\n")
              | (libname, SUPERSEDED) => print ("SUPERSEDED " ^ libname ^ "\n")
              | (libname, WRONG) => print ("WRONG " ^ libname ^ "\n"))
            outcomes
    end        

fun update (config as { context, libs } : config) =
    let open AnyLibControl
        val outcomes = map (fn lib => (#libname lib, update context lib)) libs
    in
        app (fn (libname, OK) => print ("OK " ^ libname ^ "\n")
              | (libname, ERROR e) => print ("FAILED " ^ libname ^ ": " ^ e ^ "\n"))
            outcomes
    end        
       
fun main () =
    let val rootpath = OS.FileSys.getDir ()
        val config = load_config rootpath
    in
        case CommandLine.arguments () of
            ["check"] => check config
          | ["update"] => update config
          | _ => usage ()
    end
    handle Fail err => print ("ERROR: " ^ err ^ "\n")
         | e => print ("Failed with exception: " ^ (exnMessage e) ^ "\n")
