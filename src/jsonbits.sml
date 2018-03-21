
structure JsonBits :> sig
    exception Config of string
    val load_json_from : string -> Json.json (* filename -> json *)
    val save_json_to : string -> Json.json -> unit
    val lookup_optional : Json.json -> string list -> Json.json option
    val lookup_optional_string : Json.json -> string list -> string option
    val lookup_mandatory : Json.json -> string list -> Json.json
    val lookup_mandatory_string : Json.json -> string list -> string
end = struct

    exception Config of string

    fun load_json_from filename =
        case Json.parse (FileBits.file_contents filename) of
            Json.OK json => json
          | Json.ERROR e => raise Config ("Failed to parse file: " ^ e)

    fun save_json_to filename json =
        (* using binary I/O to avoid ever writing CR/LF line endings *)
        let val jstr = Json.serialiseIndented json
            val stream = BinIO.openOut filename
        in
            BinIO.output (stream, Byte.stringToBytes jstr);
            BinIO.closeOut stream
        end
                                  
    fun lookup_optional json kk =
        let fun lookup key =
                case json of
                    Json.OBJECT kvs =>
                    (case List.filter (fn (k, v) => k = key) kvs of
                         [] => NONE
                       | [(_,v)] => SOME v
                       | _ => raise Config ("Duplicate key: " ^ 
                                            (String.concatWith " -> " kk)))
                  | _ => raise Config "Object expected"
        in
            case kk of
                [] => NONE
              | key::[] => lookup key
              | key::kk => case lookup key of
                               NONE => NONE
                             | SOME j => lookup_optional j kk
        end
                       
    fun lookup_optional_string json kk =
        case lookup_optional json kk of
            SOME (Json.STRING s) => SOME s
          | SOME _ => raise Config ("Value (if present) must be string: " ^
                                    (String.concatWith " -> " kk))
          | NONE => NONE

    fun lookup_mandatory json kk =
        case lookup_optional json kk of
            SOME v => v
          | NONE => raise Config ("Value is mandatory: " ^
                                  (String.concatWith " -> " kk))
                          
    fun lookup_mandatory_string json kk =
        case lookup_optional json kk of
            SOME (Json.STRING s) => s
          | _ => raise Config ("Value must be string: " ^
                               (String.concatWith " -> " kk))
end
