datatype vcs = HG | GIT
datatype url = EXPLICIT of string | IMPLICIT
datatype pin = UNPINNED | PINNED of string
datatype libstate = ABSENT | CORRECT | SUPERSEDED | WRONG
datatype result = OK | ERROR of string
datatype output = SUCCEED of string | FAIL of string
                                        
type provider = {
    service : string,
    user : string,
    url : url
}

type libname = string

type libspec = {
    libname : libname,
    vcs : vcs,
    provider : provider,
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

structure FileBits :> sig
    val extpath : context -> string
    val libpath : context -> libname -> string
    val subpath : context -> libname -> string -> string
    val command_output : context -> libname -> string list -> output
    val command : context -> libname -> string list -> result
    val my_dir : unit -> string
    val mkpath : string -> result
end = struct

    fun extpath { rootpath, extdir } =
        let val { isAbs, vol, arcs } = OS.Path.fromString rootpath
        in OS.Path.toString {
                isAbs = isAbs,
                vol = vol,
                arcs = arcs @ [ extdir ]
            }
        end
    
    fun subpath { rootpath, extdir } libname remainder =
        let val { isAbs, vol, arcs } = OS.Path.fromString rootpath
        in OS.Path.toString {
                isAbs = isAbs,
                vol = vol,
                arcs = arcs @ [ extdir, libname ] @
                       String.tokens (fn c => c = #"/") remainder
            }
        end

    fun libpath context "" =
        extpath context
      | libpath context libname =
        subpath context libname ""

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
            String.concatWith "\\n" contents
        end

    fun expand_commandline cmdlist =
        (* We are quite strict about what we accept here, except for
           the first element in cmdlist which is assumed to be a known
           command location rather than arbitrary user input. NB only
           ASCII accepted at this point. *)
        let open Char
            fun quote arg =
                if List.all isAlphaNum (explode arg)
                then arg
                else "\"" ^ arg ^ "\""
            fun check arg =
                let val valid = explode " /#:;?,._-"
                in
                    app (fn c =>
                            if isAlphaNum c orelse
                               List.find (fn x => x = c) valid <> NONE
                            then ()
                            else raise Fail ("Invalid character '" ^
                                             (Char.toString c) ^
                                             "' in command list"))
                        (explode arg);
                    arg
                end
        in
            String.concatWith " "
                              (map quote (hd cmdlist :: map check (tl cmdlist)))
        end
            
    fun run_command context libname cmdlist redirect =
        let open OS
            val dir = libpath context libname
            val _ = FileSys.chDir dir
            val cmd = expand_commandline cmdlist
            val _ = print ("Running command: " ^ cmd ^
                           " (in dir \"" ^ dir ^ "\")...\n")
            val status = case redirect of
                             NONE => Process.system cmd
                           | SOME file => Process.system (cmd ^ ">" ^ file)
        in
            if Process.isSuccess status
            then OK
            else ERROR ("Command failed: \"" ^ cmd ^
                        "\" (in dir \"" ^ dir ^ "\")")
        end
        handle ex => ERROR (exnMessage ex)

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
                OK => SUCCEED contents
              | ERROR e => FAIL e
        end

    fun my_dir () =
        let open OS
            val { dir, file } = Path.splitDirFile (CommandLine.name ())
        in
            FileSys.realPath
                (if Path.isAbsolute dir
                 then dir
                 else Path.concat (FileSys.getDir (), dir))
        end

    fun mkpath path =
        if OS.FileSys.isDir path handle _ => false
        then OK
        else case OS.Path.fromString path of
                 { arcs = nil, ... } => OK
               | { isAbs = false, ... } => ERROR "mkpath requires absolute path"
               | { isAbs, vol, arcs } => 
                 case mkpath (OS.Path.toString {      (* parent *)
                                   isAbs = isAbs,
                                   vol = vol,
                                   arcs = rev (tl (rev arcs)) }) of
                     ERROR e => ERROR e
                   | OK => ((OS.FileSys.mkDir path; OK)
                            handle OS.SysErr (e, _) => ERROR e)
end
                  
signature VCS_CONTROL = sig
    val exists : context -> libname -> bool
    val current_state : context -> libname ->
                        { id: string, modified: bool,
                          branch: string, tags: string list }
    val is_newest : context -> libname * provider -> bool
    val checkout : context -> libname * provider -> result
    val update : context -> libname * provider -> result
    val update_to : context -> libname * provider * string -> result
end

structure HgControl :> VCS_CONTROL = struct
                            
    fun exists context libname =
        OS.FileSys.isDir (FileBits.subpath context libname ".hg")
        handle _ => false

    fun remote_for (libname, { user, service, url }) =
        case url of
            EXPLICIT u => u
          | IMPLICIT =>
            case service of
                "bitbucket" => "https://bitbucket.org/" ^ user ^ "/" ^ libname
              | other => raise Fail ("Unsupported implicit hg provider \"" ^
                                     other ^ "\"")

    fun current_state context libname =
        let fun is_branch text = text <> "" andalso #"(" = hd (explode text)
            and extract_branch b =
                if is_branch b     (* need to remove enclosing parens *)
                then (implode o rev o tl o rev o tl o explode) b
                else ""
            and is_modified id = id <> "" andalso #"+" = hd (rev (explode id))
            and extract_id id =
                if is_modified id  (* need to remove trailing "+" *)
                then (implode o rev o tl o rev o explode) id
                else id
            and split_tags tags = String.tokens (fn c => c = #"/") tags
            and state_for (id, branch, tags) = { id = extract_id id,
                                                 modified = is_modified id,
                                                 branch = extract_branch branch,
                                                 tags = split_tags tags }
        in        
            case FileBits.command_output context libname ["hg", "id"] of
                FAIL err => raise Fail err
              | SUCCEED out =>
                case String.tokens (fn x => x = #" ") out of
                    [id, branch, tags] => state_for (id, branch, tags)
                  | [id, other] => if is_branch other
                                   then state_for (id, other, "")
                                   else state_for (id, "", other)
                  | [id] => state_for (id, "", "")
                  | _ => raise Fail ("Unexpected output from hg id: " ^ out)
        end

    fun is_newest context (libname, provider) = false

    fun checkout context (libname, provider) =
        let val command = FileBits.command context ""
            val url = remote_for (libname, provider)
        in
            case FileBits.mkpath (FileBits.extpath context) of
               OK => command ["hg", "clone", url, libname]
             | ERROR e => ERROR e
        end
                                                    
    fun update context (libname, provider) =
        let val command = FileBits.command context libname
            val url = remote_for (libname, provider)
            val pull_result = command ["hg", "pull", url]
        in
            case command ["hg", "update"] of
                OK => pull_result
              | ERROR e => ERROR e
        end

    fun update_to context (libname, provider, "") =
        update context (libname, provider)
      | update_to context (libname, provider, id) = 
        let val command = FileBits.command context libname
            val url = remote_for (libname, provider)
        in
            if command ["hg", "update", "-r" ^ id] = OK
            then OK
            else
                case command ["hg", "pull", url] of
                    OK => command ["hg", "update", "-r" ^ id]
                  | ERROR e => ERROR e
        end
                  
end

structure GitControl :> VCS_CONTROL = struct
                            
    fun exists context libname =
        OS.FileSys.isDir (FileBits.subpath context libname ".git")
        handle _ => false

    fun remote_for (libname, { user, service, url }) =
        case url of
            EXPLICIT u => u
          | IMPLICIT =>
            case service of
                "github" => "https://github.com/" ^ user ^ "/" ^ libname
              | "bitbucket" => "https://bitbucket.org/" ^ user ^ "/" ^ libname
              | other => raise Fail ("Unsupported implicit git provider \"" ^
                                     other ^ "\"")

    fun checkout context (libname, provider) =
        let val command = FileBits.command context ""
            val url = remote_for (libname, provider)
        in
            case FileBits.mkpath (FileBits.extpath context) of
               OK => command ["git", "clone", url, libname]
             | ERROR e => ERROR e
        end
end

signature LIB_CONTROL = sig
    val check : context -> libspec -> libstate
    val update : context -> libspec -> result
end
                                         
functor LibControlFn (V: VCS_CONTROL) :> LIB_CONTROL = struct

    fun check context ({ libname, provider, pin, ... } : libspec) =
        if not (V.exists context libname)
        then ABSENT
        else
            case pin of
                UNPINNED => if not (V.is_newest context (libname, provider))
                            then SUPERSEDED
                            else CORRECT
              | PINNED target => 
                case V.current_state context libname of
                    { id, ... } => if target <> id
                                   then WRONG
(*!!!???                                   else if not (V.is_newest context (libname, provider))
                                   then SUPERSEDED *)
                                   else CORRECT

    fun update context (spec as { libname, provider, pin, ... } : libspec) =
        let fun update' () =
            case pin of
                UNPINNED => if not (V.is_newest context (libname, provider))
                            then V.update context (libname, provider)
                            else OK
              | PINNED target =>
                case V.current_state context libname of
                    { id, ... } => if target <> id
                                   then V.update_to context
                                                    (libname, provider, target)
                                   else OK
        in
            if not (V.exists context libname)
            then case V.checkout context (libname, provider) of
                     OK => update' ()
                   | ERROR e => ERROR e
            else update' ()
        end
end

structure HgLibControl = LibControlFn(HgControl)
                                              
fun main () =
    let open HgLibControl
        (*!!! options: require that this program is in the root dir,
        and so use the location of this program as the root dir
        location; or require that the program is only ever run from
        the root dir; or use some mechanism to scan upwards in the dir
        hierarchy until we find a plausible root (e.g. a .vex file is
        present [and we are not within an ext dir?] *)
        val rootpath = FileBits.my_dir ();
        val _ = print ("path is " ^ rootpath ^ "\n")
    in

(*        case check { rootpath = rootpath, extdir = "ext" }
               { libname = "sml-fft", vcs = HG,
                 provider = { service = "bitbucket", url = IMPLICIT, user = "cannam" },
                 pin = PINNED "393e07cc4a53" } of
            ABSENT => print "absent\n"
          | CORRECT => print "correct\n"
          | SUPERSEDED => print "superseded\n"
          | WRONG => print "wrong\n"
*)
        case update { rootpath = rootpath, extdir = "ext" }
                    { libname = "sml-fft",
                      vcs = HG,
                      provider = {
                          service = "bitbucket",
                          url = IMPLICIT,
                          user = "cannam"
                      },
                      pin = PINNED "393e07cc4a53"
                    } of
            OK => print "done\n"
          | ERROR text => print ("error: " ^ text ^ "\n")

    end
    handle Fail err => print ("failed with error: " ^ err ^ "\n")
         | e => print ("failed with exception: " ^ (exnMessage e) ^ "\n")

val _ = main ()

             
