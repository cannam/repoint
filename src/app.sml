
val libobjname = "libraries"
                                             
fun load_libspec spec_json lock_json libname : libspec =
    let open JsonBits
        val libobj   = lookup_mandatory spec_json [libobjname, libname]
        val vcs      = lookup_mandatory_string libobj ["vcs"]
        val retrieve = lookup_optional_string libobj
        val service  = retrieve ["service"]
        val owner    = retrieve ["owner"]
        val repo     = retrieve ["repository"]
        val url      = retrieve ["url"]
        val branch   = retrieve ["branch"]
        val project_pin = case retrieve ["pin"] of
                              NONE => UNPINNED
                            | SOME p => PINNED p
        val lock_pin = case lookup_optional lock_json [libobjname, libname] of
                           NONE => UNPINNED
                         | SOME ll => case lookup_optional_string ll ["pin"] of
                                          SOME p => PINNED p
                                        | NONE => UNPINNED
    in
        {
          libname = libname,
          vcs = case vcs of
                    "hg" => HG
                  | "git" => GIT
                  | "svn" => SVN
                  | other => raise Fail ("Unknown version-control system \"" ^
                                         other ^ "\""),
          source = case (url, service, owner, repo) of
                       (SOME u, NONE, _, _) => URL_SOURCE u
                     | (NONE, SOME ss, owner, repo) =>
                       SERVICE_SOURCE { service = ss, owner = owner, repo = repo }
                     | _ => raise Fail ("Must have exactly one of service " ^
                                        "or url string"),
          project_pin = project_pin,
          lock_pin = lock_pin,
          branch = case branch of
                       NONE => DEFAULT_BRANCH
                     | SOME b => 
                       case vcs of
                           "svn" => raise Fail ("Branches not supported for " ^
                                                "svn repositories; change " ^
                                                "URL instead")
                         | _ => BRANCH b
        }
    end  

fun load_userconfig () : userconfig =
    let val home = FileBits.homedir ()
        val conf_json = 
            JsonBits.load_json_from
                (OS.Path.joinDirFile {
                      dir = home,
                      file = RepointFilenames.user_config_file })
            handle IO.Io _ => Json.OBJECT []
    in
        {
          accounts = case JsonBits.lookup_optional conf_json ["accounts"] of
                         NONE => []
                       | SOME (Json.OBJECT aa) =>
                         map (fn (k, (Json.STRING v)) =>
                                 { service = k, login = v }
                             | _ => raise Fail
                                          "String expected for account name")
                             aa
                       | _ => raise Fail "Array expected for accounts",
          providers = Provider.load_providers conf_json
        }
    end

datatype pintype =
         NO_LOCKFILE |
         USE_LOCKFILE
        
fun load_project (userconfig : userconfig) rootpath pintype : project =
    let val spec_file = FileBits.project_spec_path rootpath
        val lock_file = FileBits.project_lock_path rootpath
        val _ = if OS.FileSys.access (spec_file, [OS.FileSys.A_READ])
                   handle OS.SysErr _ => false
                then ()
                else raise Fail ("Failed to open project spec file " ^
                                 (RepointFilenames.project_file) ^ " in " ^
                                 rootpath ^
                                 ".\nPlease ensure the spec file is in the " ^
                                 "project root and run this from there.")
        val spec_json = JsonBits.load_json_from spec_file
        val lock_json = if pintype = USE_LOCKFILE
                        then JsonBits.load_json_from lock_file
                             handle IO.Io _ => Json.OBJECT []
                        else Json.OBJECT []
        val extdir = JsonBits.lookup_mandatory_string spec_json
                                                      ["config", "extdir"]
        val spec_libs = JsonBits.lookup_optional spec_json [libobjname]
        val lock_libs = JsonBits.lookup_optional lock_json [libobjname]
        val providers = Provider.load_more_providers
                            (#providers userconfig) spec_json
        val libnames = case spec_libs of
                           NONE => []
                         | SOME (Json.OBJECT ll) => map (fn (k, v) => k) ll
                         | _ => raise Fail "Object expected for libs"
    in
        {
          context = {
            rootpath = rootpath,
            extdir = extdir,
            providers = providers,
            accounts = #accounts userconfig,
            cache = StatusCache.empty
          },
          libs = map (load_libspec spec_json lock_json) libnames
        }
    end

fun save_lock_file rootpath locks =
    let val lock_file = FileBits.project_lock_path rootpath
        open Json
        val lock_json =
            OBJECT [
                (libobjname,
                 OBJECT (map (fn { libname, id_or_tag } =>
                                 (libname,
                                  OBJECT [ ("pin", STRING id_or_tag) ]))
                             locks))
            ]
    in
        JsonBits.save_json_to lock_file lock_json
    end

fun checkpoint_completion_file rootpath =
    let val completion_file = FileBits.project_completion_path rootpath
        val stream = TextIO.openOut completion_file
    in
        TextIO.closeOut stream
    end
                                                               
fun pad_to n str =
    if n <= String.size str then str
    else pad_to n (str ^ " ")

fun hline_to 0 = ""
  | hline_to n = "-" ^ hline_to (n-1)

val libname_width = 28
val libstate_width = 11
val localstate_width = 17
val notes_width = 5
val divider = " | "
val clear_line = "\r" ^ pad_to 80 "";

fun print_status_header () =
    print (clear_line ^ "\n " ^
           pad_to libname_width "Library" ^ divider ^
           pad_to libstate_width "State" ^ divider ^
           pad_to localstate_width "Local" ^ divider ^
           "Notes" ^ "\n " ^
           hline_to libname_width ^ "-+-" ^
           hline_to libstate_width ^ "-+-" ^
           hline_to localstate_width ^ "-+-" ^
           hline_to notes_width ^ "\n")

fun print_outcome_header () =
    print (clear_line ^ "\n " ^
           pad_to libname_width "Library" ^ divider ^
           pad_to libstate_width "Outcome" ^ divider ^
           "Notes" ^ "\n " ^
           hline_to libname_width ^ "-+-" ^
           hline_to libstate_width ^ "-+-" ^
           hline_to notes_width ^ "\n")
                        
fun print_status with_network (lib : libspec, status) =
    let val libstate_str =
            case status of
                OK (ABSENT, _) => "Absent"
              | OK (CORRECT, _) => if with_network then "Correct" else "Present"
              | OK (SUPERSEDED, _) => "Superseded"
              | OK (WRONG, _) => "Wrong"
              | ERROR _ => "Error"
        val localstate_str =
            case status of
                OK (_, MODIFIED) => "Modified"
              | OK (_, LOCK_MISMATCHED) => "Differs from Lock"
              | OK (_, CLEAN) => "Clean"
              | ERROR _ => ""
        val error_str =
            case status of
                ERROR e => e
              | _ => ""
    in
        print (" " ^
               pad_to libname_width (#libname lib) ^ divider ^
               pad_to libstate_width libstate_str ^ divider ^
               pad_to localstate_width localstate_str ^ divider ^
               error_str ^ "\n")
    end

fun print_update_outcome (lib : libspec, outcome) =
    let val outcome_str =
            case outcome of
                OK id => "Ok"
              | ERROR e => "Failed"
        val error_str =
            case outcome of
                ERROR e => e
              | _ => ""
    in
        print (" " ^
               pad_to libname_width (#libname lib) ^ divider ^
               pad_to libstate_width outcome_str ^ divider ^
               error_str ^ "\n")
    end

fun vcs_name HG = ("Mercurial", "hg")
  | vcs_name GIT = ("Git", "git")
  | vcs_name SVN = ("Subversion", "svn")
        
fun print_problem_summary context lines =
    let val failed_vcs =
            foldl (fn (({ vcs, ... } : libspec, ERROR _), acc) => vcs::acc
                  | (_, acc) => acc) [] lines
        fun report_nonworking vcs error =
            print ((if error = "" then "" else error ^ "\n\n") ^
                   "Error: The project uses the " ^ (#1 (vcs_name vcs)) ^
                   " version control system, but its\n" ^
                   "executable program (" ^ (#2 (vcs_name vcs)) ^
                   ") does not appear to be installed in the program path\n\n")
        fun check_working [] checked = ()
          | check_working (vcs::rest) checked =
            if List.exists (fn v => vcs = v) checked
            then check_working rest checked
            else
                case AnyLibControl.is_working context vcs of
                    OK true => check_working rest checked
                  | OK false => (report_nonworking vcs "";
                                 check_working rest (vcs::checked))
                  | ERROR e => (report_nonworking vcs e;
                                check_working rest (vcs::checked))
    in
        print "\nError: Some operations failed\n\n";
        check_working failed_vcs []
    end
        
fun act_and_print action print_header print_line context (libs : libspec list) =
    let val lines = map (fn lib => (lib, action lib)) libs
        val imperfect = List.exists (fn (_, ERROR _) => true | _ => false) lines
        val _ = print_header ()
    in
        app print_line lines;
        if imperfect then print_problem_summary context lines else ();
        lines
    end

fun return_code_for outcomes =
    foldl (fn ((_, result), acc) =>
              case result of
                  ERROR _ => OS.Process.failure
                | _ => acc)
          OS.Process.success
          outcomes
        
fun status_of_project ({ context, libs } : project) =
    return_code_for (act_and_print (AnyLibControl.status context)
                                   print_status_header (print_status false)
                                   context libs)
                                             
fun review_project ({ context, libs } : project) =
    return_code_for (act_and_print (AnyLibControl.review context)
                                   print_status_header (print_status true)
                                   context libs)

fun lock_project ({ context, libs } : project) =
    let val _ = if FileBits.verbose ()
                then print ("Scanning IDs for lock file...\n")
                else ()
        val outcomes = map (fn lib => (lib, AnyLibControl.id_of context lib))
                           libs
        val locks =
            List.concat
                (map (fn (lib : libspec, result) =>
                         case result of
                             ERROR _ => []
                           | OK id => [{ libname = #libname lib,
                                         id_or_tag = id }])
                     outcomes)
        val return_code = return_code_for outcomes
        val _ = print clear_line
    in
        if OS.Process.isSuccess return_code
        then save_lock_file (#rootpath context) locks
        else ();
        return_code
    end

fun update_project (project as { context, libs }) =
    let val outcomes = act_and_print
                           (AnyLibControl.update context)
                           print_outcome_header print_update_outcome
                           context libs
        val _ = if List.exists (fn (_, OK _) => true | _ => false) outcomes
                then lock_project project
                else OS.Process.success
        val return_code = return_code_for outcomes
    in
        if OS.Process.isSuccess return_code
        then checkpoint_completion_file (#rootpath context)
        else ();
        return_code
    end
    
fun load_local_project pintype =
    let val userconfig = load_userconfig ()
        val rootpath = OS.FileSys.getDir ()
    in
        load_project userconfig rootpath pintype
    end    

fun with_local_project pintype f =
  let open OS.Process
      val return_code =
          f (load_local_project pintype)
          handle Fail msg =>
                 failure before print ("Error: " ^ msg)
               | JsonBits.Config msg =>
                 failure before print ("Error in configuration: " ^ msg)
               | e =>
                 failure before print ("Error: " ^ exnMessage e)
        val _ = print "\n";
    in
        return_code
    end
        
fun review () = with_local_project USE_LOCKFILE review_project
fun status () = with_local_project USE_LOCKFILE status_of_project
fun update () = with_local_project NO_LOCKFILE update_project
fun lock () = with_local_project NO_LOCKFILE lock_project
fun install () = with_local_project USE_LOCKFILE update_project

fun version () =
    (print ("v" ^ repoint_version ^ "\n");
     OS.Process.success)
                      
fun usage () =
    (print "\nRepoint ";
     version ();
     print ("\n  A simple manager for third-party source code dependencies.\n"
            ^ "  https://all-day-breakfast.com/repoint/\n\n"
            ^ "Usage:\n\n"
            ^ "  repoint <command> [<options>]\n\n"
            ^ "where <command> is one of:\n\n"
            ^ "  status   print quick report on local status only, without using network\n"
            ^ "  review   check configured libraries against their providers, and report\n"
            ^ "  install  update configured libraries according to project specs and lock file\n"
            ^ "  update   update configured libraries and lock file according to project specs\n"
            ^ "  lock     rewrite lock file to match local library status\n"
            ^ "  archive  pack up project and all libraries into an archive file:\n"
            ^ "           invoke as 'repoint archive targetfile.tar.gz --exclude unwanted.txt'\n"
            ^ "  version  print the Repoint version number and exit\n\n"
            ^ "and <options> may include:\n\n"
            ^ "  --directory <dir>\n"
            ^ "           change to directory <dir> before doing anything; in particular,\n"
            ^ "           expect to find project spec file in that directory\n\n");
    OS.Process.failure)

fun archive target args =
    case args of
        [] =>
        with_local_project USE_LOCKFILE (Archive.archive (target, []))
      | "--exclude"::xs =>
        with_local_project USE_LOCKFILE (Archive.archive (target, xs))
      | _ => usage ()

fun handleSystemArgs args =
    let fun handleSystemArgs' leftover args =
            case args of
                "--directory"::dir::rest =>
                (OS.FileSys.chDir dir;
                 handleSystemArgs' leftover rest)
              | arg::rest =>
                handleSystemArgs' (leftover @ [arg]) rest
              | [] => leftover
    in
        OK (handleSystemArgs' [] args)
        handle e => ERROR (exnMessage e)
    end
                   
fun repoint args =
    case handleSystemArgs args of
        ERROR e => (print ("Error: " ^ e ^ "\n");
                    OS.Process.exit OS.Process.failure)
      | OK args => 
        let val return_code = 
            case args of
                ["review"] => review ()
              | ["status"] => status ()
              | ["install"] => install ()
              | ["update"] => update ()
              | ["lock"] => lock ()
              | ["version"] => version ()
              | "archive"::target::args => archive target args
              | arg::_ => (print ("Error: unknown argument \"" ^ arg ^ "\"\n");
                           usage ())
              | _ => usage ()
        in
            OS.Process.exit return_code
        end
        
fun main () =
    repoint (CommandLine.arguments ())
