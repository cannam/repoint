
(* SubXml - A parser for a subset of XML
   https://bitbucket.org/cannam/sml-subxml
   Copyright 2018 Chris Cannam. BSD licence.
*)

signature SUBXML = sig

    datatype node = ELEMENT of { name : string, children : node list }
                  | ATTRIBUTE of { name : string, value : string }
                  | TEXT of string
                  | CDATA of string
                  | COMMENT of string

    datatype document = DOCUMENT of { name : string, children : node list }

    datatype 'a result = OK of 'a
                       | ERROR of string

    val parse : string -> document result
    val serialise : document -> string
                                  
end

structure SubXml :> SUBXML = struct

    datatype node = ELEMENT of { name : string, children : node list }
                  | ATTRIBUTE of { name : string, value : string }
                  | TEXT of string
                  | CDATA of string
                  | COMMENT of string

    datatype document = DOCUMENT of { name : string, children : node list }

    datatype 'a result = OK of 'a
                       | ERROR of string

    structure T = struct
        datatype token = ANGLE_L
                       | ANGLE_R
                       | ANGLE_SLASH_L
                       | SLASH_ANGLE_R
                       | EQUAL
                       | NAME of string
                       | TEXT of string
                       | CDATA of string
                       | COMMENT of string

        fun name t =
            case t of ANGLE_L => "<"
                    | ANGLE_R => ">"
                    | ANGLE_SLASH_L => "</"
                    | SLASH_ANGLE_R => "/>"
                    | EQUAL => "="
                    | NAME s => "name \"" ^ s ^ "\""
                    | TEXT s => "text"
                    | CDATA _ => "CDATA section"
                    | COMMENT _ => "comment"
    end

    structure Lex :> sig
                  val lex : string -> T.token list result
              end = struct
                      
        fun error pos text =
            ERROR (text ^ " at character position " ^ Int.toString (pos-1))
        fun tokenError pos token =
            error pos ("Unexpected token '" ^ Char.toString token ^ "'")

        val nameEnd = explode " \t\n\r\"'</>!=?"
                              
        fun quoted quote pos acc cc =
            let fun quoted' pos text [] =
                    error pos "Document ends during quoted string"
                  | quoted' pos text (x::xs) =
                    if x = quote
                    then OK (rev text, xs, pos+1)
                    else quoted' (pos+1) (x::text) xs
            in
                case quoted' pos [] cc of
                    ERROR e => ERROR e
                  | OK (text, rest, newpos) =>
                    inside newpos (T.TEXT (implode text) :: acc) rest
            end

        and name first pos acc cc =
            let fun name' pos text [] =
                    error pos "Document ends during name"
                  | name' pos text (x::xs) =
                    if List.find (fn c => c = x) nameEnd <> NONE
                    then OK (rev text, (x::xs), pos)
                    else name' (pos+1) (x::text) xs
            in
                case name' (pos-1) [] (first::cc) of
                    ERROR e => ERROR e
                  | OK ([], [], pos) => error pos "Document ends before name"
                  | OK ([], (x::xs), pos) => tokenError pos x
                  | OK (text, rest, pos) =>
                    inside pos (T.NAME (implode text) :: acc) rest
            end

        and comment pos acc cc =
            let fun comment' pos text cc =
                    case cc of
                        #"-" :: #"-" :: #">" :: xs => OK (rev text, xs, pos+3)
                      | x :: xs => comment' (pos+1) (x::text) xs
                      | [] => error pos "Document ends during comment"
            in
                case comment' pos [] cc of
                    ERROR e => ERROR e
                  | OK (text, rest, pos) => 
                    outside pos (T.COMMENT (implode text) :: acc) rest
            end

        and instruction pos acc cc =
            case cc of
                #"?" :: #">" :: xs => outside (pos+2) acc xs
              | #">" :: _ => tokenError pos #">"
              | x :: xs => instruction (pos+1) acc xs
              | [] => error pos "Document ends during processing instruction"

        and cdata pos acc cc =
            let fun cdata' pos text cc =
                    case cc of
                        #"]" :: #"]" :: #">" :: xs => OK (rev text, xs, pos+3)
                      | x :: xs => cdata' (pos+1) (x::text) xs
                      | [] => error pos "Document ends during CDATA section"
            in
                case cdata' pos [] cc of
                    ERROR e => ERROR e
                  | OK (text, rest, pos) =>
                    outside pos (T.CDATA (implode text) :: acc) rest
            end
                
        and doctype pos acc cc =
            case cc of
                #">" :: xs => outside (pos+1) acc xs
              | x :: xs => doctype (pos+1) acc xs
              | [] => error pos "Document ends during DOCTYPE"

        and declaration pos acc cc =
            case cc of
                #"-" :: #"-" :: xs =>
                comment (pos+2) acc xs
              | #"[" :: #"C" :: #"D" :: #"A" :: #"T" :: #"A" :: #"[" :: xs =>
                cdata (pos+7) acc xs
              | #"D" :: #"O" :: #"C" :: #"T" :: #"Y" :: #"P" :: #"E" :: xs =>
                doctype (pos+7) acc xs
              | [] => error pos "Document ends during declaration"
              | _ => error pos "Unsupported declaration type"

        and left pos acc cc =
            case cc of
                #"/" :: xs => inside (pos+1) (T.ANGLE_SLASH_L :: acc) xs
              | #"!" :: xs => declaration (pos+1) acc xs
              | #"?" :: xs => instruction (pos+1) acc xs
              | xs => inside pos (T.ANGLE_L :: acc) xs

        and slash pos acc cc =
            case cc of
                #">" :: xs => outside (pos+1) (T.SLASH_ANGLE_R :: acc) xs
              | x :: _ => tokenError pos x
              | [] => error pos "Document ends before element closed"

        and close pos acc xs = outside pos (T.ANGLE_R :: acc) xs

        and equal pos acc xs = inside pos (T.EQUAL :: acc) xs

        and outside pos acc [] = OK acc
          | outside pos acc cc =
            let fun textOf text = T.TEXT (implode (rev text))
                fun outside' pos [] acc [] = OK acc
                  | outside' pos text acc [] = OK (textOf text :: acc)
                  | outside' pos text acc (x::xs) =
                    case x of
                        #"<" => if text = []
                                then left (pos+1) acc xs
                                else left (pos+1) (textOf text :: acc) xs
                      | x => outside' (pos+1) (x::text) acc xs
            in
                outside' pos [] acc cc
            end
                
        and inside pos acc [] = error pos "Document ends within tag"
          | inside pos acc (#"<"::_) = tokenError pos #"<"
          | inside pos acc (x::xs) =
            (case x of
                 #" " => inside | #"\t" => inside
               | #"\n" => inside | #"\r" => inside
               | #"\"" => quoted x | #"'" => quoted x
               | #"/" => slash | #">" => close | #"=" => equal
               | x => name x) (pos+1) acc xs

        fun lex str =
            case outside 1 [] (explode str) of
                ERROR e => ERROR e
              | OK tokens => OK (rev tokens)
    end

    structure Parse :> sig
                  val parse : string -> document result
              end = struct                            
                  
        fun show [] = "end of input"
          | show (tok :: _) = T.name tok

        fun error toks text = ERROR (text ^ " before " ^ show toks)

        fun attribute elt name toks =
            case toks of
                T.EQUAL :: T.TEXT value :: xs =>
                namedElement {
                    name = #name elt,
                    children = ATTRIBUTE { name = name, value = value } ::
                               #children elt
                } xs
              | T.EQUAL :: xs => error xs "Expected attribute value"
              | toks => error toks "Expected attribute assignment"

        and content elt toks =
            case toks of
                T.ANGLE_SLASH_L :: T.NAME n :: T.ANGLE_R :: xs =>
                if n = #name elt
                then OK (elt, xs)
                else ERROR ("Closing tag </" ^ n ^ "> " ^
                            "does not match opening <" ^ #name elt ^ ">")
              | T.TEXT text :: xs =>
                content {
                    name = #name elt,
                    children = TEXT text :: #children elt
                } xs
              | T.CDATA text :: xs =>
                content {
                    name = #name elt,
                    children = CDATA text :: #children elt
                } xs
              | T.COMMENT text :: xs =>
                content {
                    name = #name elt,
                    children = COMMENT text :: #children elt
                } xs
              | T.ANGLE_L :: xs =>
                (case element xs of
                     ERROR e => ERROR e
                   | OK (child, xs) =>
                     content {
                         name = #name elt,
                         children = ELEMENT child :: #children elt
                     } xs)
              | tok :: xs =>
                error xs ("Unexpected token " ^ T.name tok)
              | [] =>
                ERROR ("Document ends within element \"" ^ #name elt ^ "\"")
                       
        and namedElement elt toks =
            case toks of
                T.SLASH_ANGLE_R :: xs => OK (elt, xs)
              | T.NAME name :: xs => attribute elt name xs
              | T.ANGLE_R :: xs => content elt xs
              | x :: xs => error xs ("Unexpected token " ^ T.name x)
              | [] => ERROR "Document ends within opening tag"
                       
        and element toks =
            case toks of
                T.NAME name :: xs =>
                (case namedElement { name = name, children = [] } xs of
                     ERROR e => ERROR e 
                   | OK ({ name, children }, xs) =>
                     OK ({ name = name, children = rev children }, xs))
              | toks => error toks "Expected element name"

        and document [] = ERROR "Empty document"
          | document (tok :: xs) =
            case tok of
                T.TEXT _ => document xs
              | T.COMMENT _ => document xs
              | T.ANGLE_L =>
                (case element xs of
                     ERROR e => ERROR e
                   | OK (elt, []) => OK (DOCUMENT elt)
                   | OK (elt, (T.TEXT _ :: xs)) => OK (DOCUMENT elt)
                   | OK (elt, xs) => error xs "Extra data after document")
              | _ => error xs ("Unexpected token " ^ T.name tok)

        fun parse str =
            case Lex.lex str of
                ERROR e => ERROR e
              | OK tokens => document tokens
    end

    structure Serialise :> sig
                  val serialise : document -> string
              end = struct

        fun attributes nodes =
            String.concatWith
                " "
                (map node (List.filter
                               (fn ATTRIBUTE _ => true | _ => false)
                               nodes))

        and nonAttributes nodes =
            String.concat
                (map node (List.filter
                               (fn ATTRIBUTE _ => false | _ => true)
                               nodes))
                
        and node n =
            case n of
                TEXT string =>
                string
              | CDATA string =>
                "<![CDATA[" ^ string ^ "]]>"
              | COMMENT string =>
                "<!-- " ^ string ^ "-->"
              | ATTRIBUTE { name, value } =>
                name ^ "=" ^ "\"" ^ value ^ "\"" (*!!!*)
              | ELEMENT { name, children } =>
                "<" ^ name ^
                (case (attributes children) of
                     "" => ""
                   | s => " " ^ s) ^
                (case (nonAttributes children) of
                     "" => "/>"
                   | s => ">" ^ s ^ "</" ^ name ^ ">")
                              
        fun serialise (DOCUMENT { name, children }) =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ^
            node (ELEMENT { name = name, children = children })
    end

    val parse = Parse.parse
    val serialise = Serialise.serialise
                        
end

