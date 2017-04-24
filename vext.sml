(* DO NOT EDIT THIS FILE! It is automatically generated *)


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

structure FileBits :> sig
    val extpath : context -> string
    val libpath : context -> libname -> string
    val subpath : context -> libname -> string -> string
    val command_output : context -> libname -> string list -> output
    val command : context -> libname -> string list -> result
    val file_contents : string -> string
    val mydir : unit -> string
    val mkpath : string -> result
    val vexfile : unit -> string
    val vexpath : string -> string
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

    fun vexfile () = "vextspec.json"

    fun vexpath rootpath =
        let val { isAbs, vol, arcs } = OS.Path.fromString rootpath
        in OS.Path.toString {
                isAbs = isAbs,
                vol = vol,
                arcs = arcs @ [ vexfile () ]
            }
        end
            
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
                let val valid = explode " /#:;?,._-{}"
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
            
    fun run_command context libname cmdlist redirect =
        let open OS
            val dir = libpath context libname
            val _ = FileSys.chDir dir
            val cmd = expand_commandline cmdlist
            val _ = print ("Running: " ^ cmd ^ " (in dir " ^ dir ^ ")...\n")
            val status = case redirect of
                             NONE => Process.system cmd
                           | SOME file => Process.system (cmd ^ ">" ^ file)
        in
            if Process.isSuccess status
            then OK
            else ERROR ("Command failed: " ^ cmd ^ " (in dir " ^ dir ^ ")")
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

    fun mydir () =
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

structure HgControl :> VCS_CONTROL = struct
                            
    type vcsstate = { id: string, modified: bool,
                      branch: string, tags: string list }
                  
    fun exists context libname =
        OS.FileSys.isDir (FileBits.subpath context libname ".hg")
        handle _ => false

    fun remote_for (libname, provider) =
        case provider of
            URL u => u
          | SERVICE { host, owner, repo } =>
            let val r = case repo of
                            SOME r => r
                          | NONE => libname
            in
                case host of
                    "bitbucket" => "https://bitbucket.org/" ^ owner ^ "/" ^ r 
                  | other => raise Fail ("Unsupported implicit hg provider \"" ^
                                         other ^ "\"")
            end

    fun current_state context libname : vcsstate =
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

    fun branch_name branch = case branch of
                                 DEFAULT_BRANCH => "default"
                               | BRANCH b => b

    fun is_at context libname id_or_tag =
        case current_state context libname of
            { id, tags, ... } => 
            String.isPrefix id_or_tag id orelse
            String.isPrefix id id_or_tag orelse
            List.exists (fn t => t = id_or_tag) tags

    fun has_incoming context (libname, provider, branch) =
        case FileBits.command_output
                 context libname
                 ["hg", "incoming", "-l1", "-b", branch_name branch,
                  "--template", "{node}"] of
            FAIL err => false (* hg incoming is odd that way *)
          | SUCCEED incoming => 
            incoming <> "" andalso
            not (String.isSubstring "no changes found" incoming)
                        
    fun is_newest context (libname, provider, branch) =
        case FileBits.command_output
                 context libname
                 ["hg", "log", "-l1", "-b", branch_name branch,
                  "--template", "{node}"] of
            FAIL err => raise Fail err
          | SUCCEED newest_in_repo => 
            is_at context libname newest_in_repo andalso
            not (has_incoming context (libname, provider, branch))

    fun checkout context (libname, provider, branch) =
        let val command = FileBits.command context ""
            val url = remote_for (libname, provider)
        in
            case FileBits.mkpath (FileBits.extpath context) of
                OK => command ["hg", "clone", "-u", branch_name branch,
                               url, libname]
              | ERROR e => ERROR e
        end
                                                    
    fun update context (libname, provider, branch) =
        let val command = FileBits.command context libname
            val url = remote_for (libname, provider)
            val pull_result = command ["hg", "pull", url]
        in
            case command ["hg", "update", branch_name branch] of
                OK => pull_result
              | ERROR e => ERROR e
        end

    fun update_to context (libname, provider, "") =
        raise Fail "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, provider, id) = 
        let val command = FileBits.command context libname
            val url = remote_for (libname, provider)
        in
            case command ["hg", "update", "-r" ^ id] of
                OK => OK
              | ERROR _ => 
                case command ["hg", "pull", url] of
                    OK => command ["hg", "update", "-r" ^ id]
                  | ERROR e => ERROR e
        end
                  
end

structure GitControl :> VCS_CONTROL = struct
                            
    fun exists context libname =
        OS.FileSys.isDir (FileBits.subpath context libname ".git")
        handle _ => false

    fun remote_for (libname, provider) =
        case provider of
            URL u => u
          | SERVICE { host, owner, repo } =>
            let val r = case repo of
                            SOME r => r
                          | NONE => libname
            in
                case host of
                    "github" => "https://github.com/" ^ owner ^ "/" ^ r
                  | "bitbucket" => "https://bitbucket.org/" ^ owner ^ "/" ^ r
                  | other => raise Fail ("Unsupported implicit git provider \"" ^
                                         other ^ "\"")
            end

    fun branch_name branch = case branch of
                                 DEFAULT_BRANCH => "master"
                               | BRANCH b => b

    fun checkout context (libname, provider, branch) =
        let val command = FileBits.command context ""
            val url = remote_for (libname, provider)
        in
            case FileBits.mkpath (FileBits.extpath context) of
                OK => command ["git", "clone", "-b", branch_name branch,
                               url, libname]
              | ERROR e => ERROR e
        end

    (* NB git rev-parse HEAD shows revision id of current checkout;
    git rev-list -1 <tag> shows revision id of revision with that tag *)

    fun is_at context libname id_or_tag =
        case FileBits.command_output context libname
                                     ["git", "rev-parse", "HEAD"] of
            FAIL err => raise Fail err
          | SUCCEED id =>
            String.isPrefix id_or_tag id orelse
            String.isPrefix id id_or_tag orelse
            case FileBits.command_output context libname
                                         ["git", "rev-list", "-1", id_or_tag] of
                FAIL err => raise Fail err
              | SUCCEED tid =>
                tid = id andalso
                tid <> id_or_tag (* otherwise id_or_tag was an id, not a tag *)

    fun is_newest context (libname, provider, branch) =
      let fun newest_here () =
            case FileBits.command_output
                     context libname
                     ["git", "rev-list", "-1", branch_name branch] of
                FAIL err => raise Fail err
              | SUCCEED rev => is_at context libname rev
      in
          if not (newest_here ())
          then false
          else case FileBits.command context libname ["git", "fetch"] of
                   ERROR err => raise Fail err
                 | OK => newest_here ()
      end

    fun update context (libname, provider, branch) =
        update_to context (libname, provider, branch_name branch)

    and update_to context (libname, provider, "") = 
        raise Fail "Non-empty id (tag or revision id) required for update_to"
      | update_to context (libname, provider, id) = 
        let val command = FileBits.command context libname
            val url = remote_for (libname, provider)
        in
            case command ["git", "checkout", "--detach", id] of
                OK => OK
              | ERROR _ => 
                case command ["git", "pull", url] of
                    OK => command ["git", "checkout", "--detach", id]
                  | ERROR e => ERROR e
        end
end
                                         
functor LibControlFn (V: VCS_CONTROL) :> LIB_CONTROL = struct

    fun check context ({ libname, provider, branch, pin, ... } : libspec) =
        let fun check' () =
            case pin of
                UNPINNED =>
                if not (V.is_newest context (libname, provider, branch))
                then SUPERSEDED
                else CORRECT

              | PINNED target =>
                if V.is_at context libname target
                then CORRECT
                else WRONG
        in
            if not (V.exists context libname)
            then ABSENT
            else check' ()
        end

    fun update context ({ libname, provider, branch, pin, ... } : libspec) =
        let fun update' () =
            case pin of
                UNPINNED =>
                if not (V.is_newest context (libname, provider, branch))
                then V.update context (libname, provider, branch)
                else OK

              | PINNED target =>
                if V.is_at context libname target
                then OK
                else V.update_to context (libname, provider, target)
        in
            if not (V.exists context libname)
            then V.checkout context (libname, provider, branch)
            else update' ()
        end
end

structure AnyLibControl :> LIB_CONTROL = struct

    structure H = LibControlFn(HgControl)
    structure G = LibControlFn(GitControl)

    fun check context (spec as { vcs, ... } : libspec) =
        (fn HG => H.check | GIT => G.check) vcs context spec

    fun update context (spec as { vcs, ... } : libspec) =
        (fn HG => H.update | GIT => G.update) vcs context spec
end

(* An RFC-compliant JSON parser in one SML file with no dependency 
   on anything outside the Basis library. Also includes a simple
   serialiser.

   Parser notes:

   * Complies with RFC 7159, The JavaScript Object Notation (JSON)
     Data Interchange Format

   * Passes all of the JSONTestSuite parser accept/reject tests that
     exist at the time of writing, as listed in "Parsing JSON is a
     Minefield" (http://seriot.ch/parsing_json.php)
 
   * Two-pass parser using naive exploded strings, therefore not very
     fast and not suitable for large input files

   * Only supports UTF-8 input, not UTF-16 or UTF-32. Doesn't check
     that JSON strings are valid UTF-8 -- the caller must do that --
     but does handle \u escapes

   * Converts all numbers to type "real". If that is a 64-bit IEEE
     float type (common but not guaranteed in SML) then we're pretty
     standard for a JSON parser

   Some of this is based on the JSON parser in the Ponyo library by
   Phil Eaton.

   Copyright 2017 Chris Cannam.

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation
   files (the "Software"), to deal in the Software without
   restriction, including without limitation the rights to use, copy,
   modify, merge, publish, distribute, sublicense, and/or sell copies
   of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR
   ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
   CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
   WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

   Except as contained in this notice, the names of Chris Cannam and
   Particular Programs Ltd shall not be used in advertising or
   otherwise to promote the sale, use or other dealings in this
   Software without prior written authorization.
*)

signature JSON = sig

    datatype json = OBJECT of (string * json) list
                  | ARRAY of json list
                  | NUMBER of real
                  | STRING of string
                  | BOOL of bool
                  | NULL

    datatype 'a result = OK of 'a
                       | ERROR of string

    val parse : string -> json result
    val serialise : json -> string

end

structure Json :> JSON = struct

    datatype json = OBJECT of (string * json) list
                  | ARRAY of json list
                  | NUMBER of real
                  | STRING of string
                  | BOOL of bool
                  | NULL

    datatype 'a result = OK of 'a
                       | ERROR of string

    structure T = struct
        datatype token = NUMBER of char list
                       | STRING of string
                       | BOOL of bool
                       | NULL
                       | CURLY_L
                       | CURLY_R
                       | SQUARE_L
                       | SQUARE_R
                       | COLON
                       | COMMA

        fun toString t =
            case t of NUMBER digits => implode digits
                    | STRING s => s
                    | BOOL b => Bool.toString b
                    | NULL => "null"
                    | CURLY_L => "{"
                    | CURLY_R => "}"
                    | SQUARE_L => "["
                    | SQUARE_R => "]"
                    | COLON => ":"
                    | COMMA => ","
    end

    fun bmpToUtf8 cp =  (* convert a codepoint in Unicode BMP to utf8 bytes *)
        let open Word
	    infix 6 orb andb >>
        in
            map (Char.chr o toInt)
                (if cp < 0wx80 then
                     [cp]
                 else if cp < 0wx800 then
                     [0wxc0 orb (cp >> 0w6), 0wx80 orb (cp andb 0wx3f)]
                 else if cp < 0wx10000 then
                     [0wxe0 orb (cp >> 0w12),
                      0wx80 orb ((cp >> 0w6) andb 0wx3f),
		      0wx80 orb (cp andb 0wx3f)]
                 else raise Fail ("Invalid BMP point " ^ (Word.toString cp)))
        end
                      
    fun error pos text = ERROR (text ^ " at character position " ^
                                Int.toString (pos - 1))
    fun token_error pos = error pos ("Unexpected token")

    fun lexNull pos acc (#"u" :: #"l" :: #"l" :: xs) =
        lex (pos + 3) (T.NULL :: acc) xs
      | lexNull pos acc _ = token_error pos

    and lexTrue pos acc (#"r" :: #"u" :: #"e" :: xs) =
        lex (pos + 3) (T.BOOL true :: acc) xs
      | lexTrue pos acc _ = token_error pos

    and lexFalse pos acc (#"a" :: #"l" :: #"s" :: #"e" :: xs) =
        lex (pos + 4) (T.BOOL false :: acc) xs
      | lexFalse pos acc _ = token_error pos

    and lexChar tok pos acc xs =
        lex pos (tok :: acc) xs
        
    and lexString pos acc cc =
        let datatype escaped = ESCAPED | NORMAL
            fun lexString' pos text ESCAPED [] =
                error pos "End of input during escape sequence"
              | lexString' pos text NORMAL [] = 
                error pos "End of input during string"
              | lexString' pos text ESCAPED (x :: xs) =
                let fun esc c = lexString' (pos + 1) (c :: text) NORMAL xs
                in case x of
                       #"\"" => esc x
                     | #"\\" => esc x
                     | #"/"  => esc x
                     | #"b"  => esc #"\b"
                     | #"f"  => esc #"\f"
                     | #"n"  => esc #"\n"
                     | #"r"  => esc #"\r"
                     | #"t"  => esc #"\t"
                     | _     => error pos ("Invalid escape \\" ^
                                           Char.toString x)
                end
              | lexString' pos text NORMAL (#"\\" :: #"u" ::a::b::c::d:: xs) =
                if List.all Char.isHexDigit [a,b,c,d]
                then case Word.fromString ("0wx" ^ (implode [a,b,c,d])) of
                         SOME w => (let val utf = rev (bmpToUtf8 w) in
                                        lexString' (pos + 6) (utf @ text)
                                                   NORMAL xs
                                    end
                                    handle Fail err => error pos err)
                       | NONE => error pos "Invalid Unicode BMP escape sequence"
                else error pos "Invalid Unicode BMP escape sequence"
              | lexString' pos text NORMAL (x :: xs) =
                if Char.ord x < 0x20
                then error pos "Invalid unescaped control character"
                else
                    case x of
                        #"\"" => OK (rev text, xs, pos + 1)
                      | #"\\" => lexString' (pos + 1) text ESCAPED xs
                      | _     => lexString' (pos + 1) (x :: text) NORMAL xs
        in
            case lexString' pos [] NORMAL cc of
                OK (text, rest, newpos) =>
                lex newpos (T.STRING (implode text) :: acc) rest
              | ERROR e => ERROR e
        end

    and lexNumber firstChar pos acc cc =
        let val valid = explode ".+-e"
            fun lexNumber' pos digits [] = (rev digits, [], pos)
              | lexNumber' pos digits (x :: xs) =
                if x = #"E" then lexNumber' (pos + 1) (#"e" :: digits) xs
                else if Char.isDigit x orelse List.exists (fn c => x = c) valid
                then lexNumber' (pos + 1) (x :: digits) xs
                else (rev digits, x :: xs, pos)
            val (digits, rest, newpos) =
                lexNumber' (pos - 1) [] (firstChar :: cc)
        in
            case digits of
                [] => token_error pos
              | _ => lex newpos (T.NUMBER digits :: acc) rest
        end
                                           
    and lex pos acc [] = OK (rev acc)
      | lex pos acc (x::xs) = 
        (case x of
             #" "  => lex
           | #"\t" => lex
           | #"\n" => lex
           | #"\r" => lex
           | #"{"  => lexChar T.CURLY_L
           | #"}"  => lexChar T.CURLY_R
           | #"["  => lexChar T.SQUARE_L
           | #"]"  => lexChar T.SQUARE_R
           | #":"  => lexChar T.COLON
           | #","  => lexChar T.COMMA
           | #"\"" => lexString
           | #"t"  => lexTrue
           | #"f"  => lexFalse
           | #"n"  => lexNull
           | x     => lexNumber x) (pos + 1) acc xs

    fun show [] = "end of input"
      | show (tok :: _) = T.toString tok

    fun parseNumber digits =
        (* Note lexNumber already case-insensitised the E for us *)
        let open Char

            fun chkExpNumber [] = false
              | chkExpNumber (c :: []) = isDigit c
              | chkExpNumber (c :: rest) = isDigit c andalso chkExpNumber rest

            fun chkExp [] = false
              | chkExp (#"+" :: rest) = chkExpNumber rest
              | chkExp (#"-" :: rest) = chkExpNumber rest
              | chkExp cc = chkExpNumber cc

            fun chkAfterDotAndDigit [] = true
              | chkAfterDotAndDigit (c :: rest) =
                (isDigit c andalso chkAfterDotAndDigit rest) orelse
                (c = #"e" andalso chkExp rest)

            fun chkAfterDot [] = false
              | chkAfterDot (c :: rest) =
                isDigit c andalso chkAfterDotAndDigit rest

            fun chkPosAfterFirst [] = true
              | chkPosAfterFirst (#"." :: rest) = chkAfterDot rest
              | chkPosAfterFirst (#"e" :: rest) = chkExp rest
              | chkPosAfterFirst (c :: rest) =
                isDigit c andalso chkPosAfterFirst rest
                                                      
            fun chkPos [] = false
              | chkPos (#"0" :: []) = true
              | chkPos (#"0" :: #"." :: rest) = chkAfterDot rest
              | chkPos (#"0" :: #"e" :: rest) = chkExp rest
              | chkPos (#"0" :: rest) = false
              | chkPos (c :: rest) = isDigit c andalso chkPosAfterFirst rest
                    
            fun chkNumber (#"-" :: rest) = chkPos rest
              | chkNumber cc = chkPos cc
        in
            if chkNumber digits
            then case Real.fromString (implode digits) of
                     NONE => ERROR "Number out of range"
                   | SOME r => OK r
            else ERROR ("Invalid number \"" ^ (implode digits) ^ "\"")
        end
                                     
    fun parseObject (T.CURLY_R :: xs) = OK (OBJECT [], xs)
      | parseObject tokens =
        let fun parsePair (T.STRING key :: T.COLON :: xs) =
                (case parseTokens xs of
                     ERROR e => ERROR e
                   | OK (j, xs) => OK ((key, j), xs))
              | parsePair other =
                ERROR ("Object key/value pair expected around \"" ^
                       show other ^ "\"")
            fun parseObject' acc [] = ERROR "End of input during object"
              | parseObject' acc tokens =
                case parsePair tokens of
                    ERROR e => ERROR e
                  | OK (pair, T.COMMA :: xs) => parseObject' (pair :: acc) xs
                  | OK (pair, T.CURLY_R :: xs) => OK (OBJECT (pair :: acc), xs)
                  | OK (_, _) => ERROR "Expected , or } after object element"
        in
            parseObject' [] tokens
        end

    and parseArray (T.SQUARE_R :: xs) = OK (ARRAY [], xs)
      | parseArray tokens =
        let fun parseArray' acc [] = ERROR "End of input during array"
              | parseArray' acc tokens =
                case parseTokens tokens of
                    ERROR e => ERROR e
                  | OK (j, T.COMMA :: xs) => parseArray' (j :: acc) xs
                  | OK (j, T.SQUARE_R :: xs) => OK (ARRAY (rev (j :: acc)), xs)
                  | OK (_, _) => ERROR "Expected , or ] after array element"
        in
            parseArray' [] tokens
        end

    and parseTokens [] = ERROR "Value expected"
      | parseTokens (tok :: xs) =
        (case tok of
             T.NUMBER d => (case parseNumber d of
                                OK r => OK (NUMBER r, xs)
                              | ERROR e => ERROR e)
           | T.STRING s => OK (STRING s, xs)
           | T.BOOL b   => OK (BOOL b, xs)
           | T.NULL     => OK (NULL, xs)
           | T.CURLY_L  => parseObject xs
           | T.SQUARE_L => parseArray xs
           | _ => ERROR ("Unexpected token " ^ T.toString tok ^
                         " before " ^ show xs))
                                   
    fun parse str =
        case lex 1 [] (explode str) of
           ERROR e => ERROR e
         | OK tokens => case parseTokens tokens of
                            OK (value, []) => OK value
                          | OK (_, _) => ERROR "Extra data after input"
                          | ERROR e => ERROR e

    fun stringEscape s =
        let fun esc x = [x, #"\\"]
            fun escape' acc [] = rev acc
              | escape' acc (x :: xs) =
                escape' (case x of
                             #"\"" => esc x @ acc
                           | #"\\" => esc x @ acc
                           | #"\b" => esc #"b" @ acc
                           | #"\f" => esc #"f" @ acc
                           | #"\n" => esc #"n" @ acc
                           | #"\r" => esc #"r" @ acc
                           | #"\t" => esc #"t" @ acc
                           | _ =>
                             let val c = Char.ord x
                             in
                                 if c < 0x20
                                 then let val hex = Word.toString (Word.fromInt c)
                                      in (rev o explode) (if c < 0x10
                                                          then ("\\u000" ^ hex)
                                                          else ("\\u00" ^ hex))
                                      end @ acc
                                 else 
                                     x :: acc
                             end)
                        xs
        in
            implode (escape' [] (explode s))
        end
        
    fun serialise json =
        case json of
            OBJECT pp => "{" ^ String.concatWith
                                   "," (map (fn (key, value) =>
                                                serialise (STRING key) ^ ":" ^
                                                serialise value) pp) ^
                         "}"
          | ARRAY arr => "[" ^ String.concatWith "," (map serialise arr) ^ "]"
          | NUMBER n => implode (map (fn #"~" => #"-" | c => c) 
                                     (explode (Real.toString n)))
          | STRING s => "\"" ^ stringEscape s ^ "\""
          | BOOL b => Bool.toString b
          | NULL => "null"
                                             
end


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
val _ = main ()

             
