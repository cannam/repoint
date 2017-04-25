
structure AnyLibControl :> LIB_CONTROL = struct

    structure H = LibControlFn(HgControl)
    structure G = LibControlFn(GitControl)

    fun check context (spec as { vcs, ... } : libspec) =
        (fn HG => H.check | GIT => G.check) vcs context spec

    fun update context (spec as { vcs, ... } : libspec) =
        (fn HG => H.update | GIT => G.update) vcs context spec
end
                   
fun load_libspec json libname : libspec =
    let open JsonBits
        val libobj   = lookup_mandatory json ["libs", libname]
        val vcs      = lookup_mandatory_string libobj ["vcs"]
        val retrieve = lookup_optional_string libobj
        val service  = retrieve ["service"]
        val owner    = retrieve ["owner"]
        val repo     = retrieve ["repository"]
        val url      = retrieve ["url"]
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
          source = case (url, service, owner, repo) of
                       (SOME u, NONE, _, _) => URL u
                     | (NONE, SOME ss, owner, repo) =>
                       PROVIDER { service = ss, owner = owner, repo = repo }
                     | _ => raise Fail ("Must have exactly one of service " ^
                                        "or url string"),
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
        val json = JsonBits.load_json specfile
        val extdir = JsonBits.lookup_mandatory_string json ["config", "extdir"]
        val libs = JsonBits.lookup_optional json ["libs"]
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
        fun print_for libname state m = print (state ^ " " ^ libname ^
                                               (case m of
                                                    MODIFIED => " [* modified]"
                                                  | UNMODIFIED => "") ^ "\n")
    in
        app (fn (n, (ABSENT, _)) => print_for n "ABSENT" UNMODIFIED
              | (n, (CORRECT, m)) => print_for n "CORRECT" m
              | (n, (SUPERSEDED, m)) => print_for n "SUPERSEDED" m
              | (n, (WRONG, m)) => print_for n "WRONG" m)
            outcomes
    end        

fun update (config as { context, libs } : config) =
    let open AnyLibControl
        val outcomes = map (fn lib => (#libname lib, update context lib)) libs
    in
        app (fn (libname, OK) =>
                print ("OK " ^ libname ^ "\n")
              | (libname, ERROR e) =>
                print ("FAILED " ^ libname ^ ": " ^ e ^ "\n"))
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
