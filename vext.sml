datatype vcs = HG | GIT
datatype uri = EXPLICIT of string | IMPLICIT
datatype pin = UNPINNED | PINNED of string
datatype state = ABSENT | CORRECT | SUPERSEDED | WRONG
datatype result = OK | ERROR of string
datatype output = SUCCEED of string | FAIL of string
                                        
type provider = {
    name : string,
    user : string,
    uri : uri
}

type libname = string

type libspec = {
    name : libname,
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
    val libpath : context -> libname -> string
    val subpath : context -> libname -> string -> string
    val command_output : context -> libname -> string -> output
    val command : context -> libname -> string -> result
    val my_dir : unit -> string
end = struct

    fun subpath { rootpath, extdir } libname remainder =
        let val { isAbs, vol, arcs } = OS.Path.fromString rootpath
        in OS.Path.toString {
                isAbs = isAbs,
                vol = vol,
                arcs = arcs @ [ extdir, libname ] @
                       String.tokens (fn c => c = #"/") remainder
            }
        end

    fun libpath context libname =
        subpath context libname ""

    fun file_contents filename =
        let val stream = TextIO.openIn filename
            fun read_all str acc =
                case TextIO.inputLine str of
                    SOME line => read_all str (line :: acc)
                  | NONE => rev acc
            val contents = read_all stream []
            val _ = TextIO.closeIn stream
        in
            String.concatWith "\\n" contents
        end
            
    fun command_output context libname command =
        let open OS
            val dir = libpath context libname
            val tmpFile = FileSys.tmpName ()
        in
            let val _ = FileSys.chDir dir
                val status = Process.system (command ^ ">" ^ tmpFile)
                val contents = file_contents tmpFile
            in
                FileSys.remove tmpFile;
                if Process.isSuccess status
                then SUCCEED contents
                else FAIL ("Command failed: \"" ^ command ^
                           "\" (in dir \"" ^ dir ^ "\")")
            end
            handle ex => (FileSys.remove tmpFile; raise ex) (*!!!*)
        end

    fun command context libname command =
        case command_output context libname command of
            SUCCEED _ => OK
          | FAIL err => ERROR err

    fun my_dir () =
        let open OS
            val { dir, file } = Path.splitDirFile (CommandLine.name ())
        in
            FileSys.realPath (Path.concat (FileSys.getDir (), dir))
        end
end
                  
signature VCS_CONTROL = sig
    val exists : context -> libname -> bool
    val current_id : context -> libname -> string
    val is_newest : context -> libname * provider -> bool
    val update : context -> libname * provider -> result
    val update_to : context -> libname * provider * string -> result
end

structure HgControl :> VCS_CONTROL = struct

    fun exists context libname =
        OS.FileSys.isDir (FileBits.subpath context libname ".hg")
        handle _ => false

    fun current_id context libname =
        case FileBits.command_output context libname "hg id" of
            SUCCEED out => out
          | FAIL err => raise Fail err

    fun is_newest context (libname, provider) = false

    fun update context (libname, provider) = raise Fail "blah"

    fun update_to context (libname, provider, id) = raise Fail "blah"
                            
end

signature LIB_CONTROL = sig
    val check : context -> libspec -> state
    val update : context -> libspec -> result
end
                                         
functor LibControlFn (V: VCS_CONTROL) :> LIB_CONTROL = struct

    fun check context ({ name, pin, ... } : libspec) =
        if not (V.exists context name)
        then ABSENT
        else CORRECT (*!!!*)
             
    fun update context ({ name, provider, pin = UNPINNED, ... } : libspec) =
        V.update context (name, provider)
      | update context (spec : libspec) = ERROR "not implemented"
             
end

structure HgLibControl = LibControlFn(HgControl)
                                              
fun main () =
    let open HgLibControl
        val rootpath = FileBits.my_dir ();
        val _ = print ("path is " ^ rootpath ^ "\n")
    in
        (*
        case check { rootpath = rootpath, extdir = "ext" }
               { name = "sml-log", vcs = HG,
                 provider = { name = "bitbucket", uri = IMPLICIT, user = "cannam" },
                 pin = UNPINNED } of
            ABSENT => print "absent\n"
          | CORRECT => print "correct\n"
          | SUPERSEDED => print "superseded\n"
          | WRONG => print "wrong\n"
        *)
        case update { rootpath = rootpath, extdir = "ext" }
                    { name = "sml-log", vcs = HG,
                      provider = { name = "bitbucket", uri = IMPLICIT, user = "cannam" },
                      pin = UNPINNED } of
            OK => print "done\n"
          | ERROR text => print ("error: " ^ text ^ "\n")
    end
    handle Fail err => print ("failed with error: " ^ err ^ "\n");
        
(*
structure GitControl :> VCS_CONTROL = struct

end
*)
