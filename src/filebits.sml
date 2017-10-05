
structure FileBits :> sig
    val extpath : context -> string
    val libpath : context -> libname -> string
    val subpath : context -> libname -> string -> string
    val command_output : context -> libname -> string list -> string result
    val command : context -> libname -> string list -> unit result
    val file_contents : string -> string
    val mydir : unit -> string
    val homedir : unit -> string
    val mkpath : string -> unit result
    val rmpath : string -> unit result
    val project_spec_path : string -> string
    val project_lock_path : string -> string
    val verbose : unit -> bool
end = struct

    fun verbose () =
        case OS.Process.getEnv "VEXT_VERBOSE" of
            SOME "0" => false
          | SOME _ => true
          | NONE => false

    fun extpath ({ rootpath, extdir, ... } : context) =
        let val { isAbs, vol, arcs } = OS.Path.fromString rootpath
        in OS.Path.toString {
                isAbs = isAbs,
                vol = vol,
                arcs = arcs @ [ extdir ]
            }
        end
    
    fun subpath ({ rootpath, extdir, ... } : context) libname remainder =
        (* NB libname is allowed to be a path fragment, e.g. foo/bar *)
        let val { isAbs, vol, arcs } = OS.Path.fromString rootpath
            val split = String.fields (fn c => c = #"/")
        in OS.Path.toString {
                isAbs = isAbs,
                vol = vol,
                arcs = arcs @ [ extdir ] @ split libname @ split remainder
            }
        end

    fun libpath context "" =
        extpath context
      | libpath context libname =
        subpath context libname ""

    fun project_file_path rootpath filename =
        let val { isAbs, vol, arcs } = OS.Path.fromString rootpath
        in OS.Path.toString {
                isAbs = isAbs,
                vol = vol,
                arcs = arcs @ [ filename ]
            }
        end
                
    fun project_spec_path rootpath =
        project_file_path rootpath (VextFilenames.project_file)

    fun project_lock_path rootpath =
        project_file_path rootpath (VextFilenames.project_lock_file)

    fun trim str =
        hd (String.fields (fn x => x = #"\n" orelse x = #"\r") str)
        
    fun file_contents filename =
        let val stream = TextIO.openIn filename
            fun read_all str acc =
                case TextIO.inputLine str of
                    SOME line => read_all str (trim line :: acc)
                  | NONE => rev acc
            val contents = read_all stream []
            val _ = TextIO.closeIn stream
        in
            String.concatWith "\n" contents
        end

    fun expand_commandline cmdlist =
        (* We are quite [too] strict about what we accept here, except
           for the first element in cmdlist which is assumed to be a
           known command location rather than arbitrary user input. NB
           only ASCII accepted at this point. *)
        let open Char
            fun quote arg =
                if List.all
                       (fn c => isAlphaNum c orelse c = #"-" orelse c = #"_")
                       (explode arg)
                then arg
                else "\"" ^ arg ^ "\""
            fun check arg =
                let val valid = explode " /#:;?,._-{}@="
                in
                    app (fn c =>
                            if isAlphaNum c orelse
                               List.exists (fn v => v = c) valid
                            then ()
                            else raise Fail ("Invalid character '" ^
                                             (Char.toString c) ^
                                             "' in command list"))
                        (explode arg);
                    arg
                end
        in
            String.concatWith " "
                              (map quote
                                   (hd cmdlist :: map check (tl cmdlist)))
        end

    val tick_cycle = ref 0
    val tick_chars = Vector.fromList (map String.str (explode "|/-\\"))

    fun tick libname cmdlist =
        let val n = Vector.length tick_chars
            fun pad_to n str =
                if n <= String.size str then str
                else pad_to n (str ^ " ")
            val name = if libname <> "" then libname
                       else if cmdlist = nil then ""
                       else hd (rev cmdlist)
        in
            print ("  " ^
                   Vector.sub(tick_chars, !tick_cycle) ^ " " ^
                   pad_to 24 name ^
                   "\r");
            tick_cycle := (if !tick_cycle = n - 1 then 0 else 1 + !tick_cycle)
        end
            
    fun run_command context libname cmdlist redirect =
        let open OS
            val dir = libpath context libname
            val cmd = expand_commandline cmdlist
            val _ = if verbose ()
                    then print ("Running: " ^ cmd ^
                                " (in dir " ^ dir ^ ")...\n")
                    else tick libname cmdlist
            val _ = FileSys.chDir dir
            val status = case redirect of
                             NONE => Process.system cmd
                           | SOME file => Process.system (cmd ^ ">" ^ file)
        in
            if Process.isSuccess status
            then OK ()
            else ERROR ("Command failed: " ^ cmd ^ " (in dir " ^ dir ^ ")")
        end
        handle ex => ERROR ("Unable to run command: " ^ exnMessage ex)

    fun command context libname cmdlist =
        run_command context libname cmdlist NONE
            
    fun command_output context libname cmdlist =
        let open OS
            val tmpFile = FileSys.tmpName ()
            val result = run_command context libname cmdlist (SOME tmpFile)
            val contents = file_contents tmpFile
        in
            FileSys.remove tmpFile handle _ => ();
            case result of
                OK () => OK contents
              | ERROR e => ERROR e
        end

    fun mydir () =
        let open OS
            val { dir, file } = Path.splitDirFile (CommandLine.name ())
        in
            FileSys.realPath
                (if Path.isAbsolute dir
                 then dir
                 else Path.concat (FileSys.getDir (), dir))
        end

    fun homedir () =
        (* Failure is not routine, so we use an exception here *)
        case (OS.Process.getEnv "HOME",
              OS.Process.getEnv "HOMEPATH") of
            (SOME home, _) => home
          | (NONE, SOME home) => home
          | (NONE, NONE) =>
            raise Fail "Failed to look up home directory from environment"

    fun mkpath path =
        if OS.FileSys.isDir path handle _ => false
        then OK ()
        else case OS.Path.fromString path of
                 { arcs = nil, ... } => OK ()
               | { isAbs = false, ... } => ERROR "mkpath requires absolute path"
               | { isAbs, vol, arcs } => 
                 case mkpath (OS.Path.toString {      (* parent *)
                                   isAbs = isAbs,
                                   vol = vol,
                                   arcs = rev (tl (rev arcs)) }) of
                     ERROR e => ERROR e
                   | OK () => ((OS.FileSys.mkDir path; OK ())
                               handle OS.SysErr (e, _) =>
                                      ERROR ("Directory creation failed: " ^ e))

    fun rmpath path =
        let open OS
            fun files_from dirstream =
                case FileSys.readDir dirstream of
                    NONE => []
                  | SOME file =>
                    (* readDir is supposed to filter these, 
                       but let's be extra cautious: *)
                    if file = Path.parentArc orelse file = Path.currentArc
                    then files_from dirstream
                    else file :: files_from dirstream
            fun contents dir =
                let val stream = FileSys.openDir dir
                    val files = map (fn f => Path.joinDirFile
                                                 { dir = dir, file = f })
                                    (files_from stream)
                    val _ = FileSys.closeDir stream
                in files
                end
            fun remove path =
                if FileSys.isLink path (* dangling links bother isDir *)
                then FileSys.remove path
                else if FileSys.isDir path
                then (app remove (contents path); FileSys.rmDir path)
                else FileSys.remove path
        in
            (remove path; OK ())
            handle SysErr (e, _) => ERROR ("Path removal failed: " ^ e)
        end
end
