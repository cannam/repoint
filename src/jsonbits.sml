
structure JsonBits :> sig
    val load_json_from : string -> Json.json (* filename -> json *)
    val lookup_optional : Json.json -> string list -> Json.json option
    val lookup_optional_string : Json.json -> string list -> string option
    val lookup_mandatory : Json.json -> string list -> Json.json
    val lookup_mandatory_string : Json.json -> string list -> string
end = struct

    fun load_json_from filename =
        case Json.parse (FileBits.file_contents filename) of
            Json.OK json => json
          | Json.ERROR e => raise Fail ("Failed to parse file: " ^ e)
                                  
    fun lookup_optional json kk =
        let fun lookup key =
                case json of
                    Json.OBJECT kvs =>
                    (case List.find (fn (k, v) => k = key) kvs of
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
                       
    fun lookup_optional_string json kk =
        case lookup_optional json kk of
            SOME (Json.STRING s) => SOME s
          | SOME _ => raise Fail ("Value (if present) must be string: " ^
                                  (String.concatWith " -> " kk))
          | NONE => NONE

    fun lookup_mandatory json kk =
        case lookup_optional json kk of
            SOME v => v
          | NONE => raise Fail ("Value is mandatory: " ^
                                (String.concatWith " -> " kk))
                          
    fun lookup_mandatory_string json kk =
        case lookup_optional json kk of
            SOME (Json.STRING s) => s
          | _ => raise Fail ("Value must be string: " ^
                             (String.concatWith " -> " kk))
end
