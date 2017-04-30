
structure Provider :> sig
    val load_providers : Json.json -> provider list
    val load_more_providers : provider list -> Json.json -> provider list
    val remote_url : provider list -> vcs -> source -> libname -> string
end = struct

    val known_providers : provider list =
        [ {
            service = "bitbucket",
            supports = [HG, GIT],
            remote_spec = {
                anon = SOME "https://bitbucket.org/{owner}/{repo}",
                auth = SOME "ssh://{vcs}@bitbucket.org/{owner}/{repo}"
            }
          },
          {
            service = "github",
            supports = [GIT],
            remote_spec = {
                anon = SOME "https://github.com/{owner}/{repo}",
                auth = SOME "ssh://{vcs}@github.com/{owner}/{repo}"
            }
          }
        ]

    fun vcs_name vcs =
        case vcs of GIT => "git" |
                    HG => "hg"
                                             
    fun vcs_from_name name =
        case name of "git" => GIT 
                   | "hg" => HG
                   | other => raise Fail ("Unknown vcs name \"" ^ name ^ "\"")

    fun load_more_providers previously_loaded json =
        let open JsonBits
            fun load pjson pname : provider =
                {
                  service = pname,
                  supports =
                  case lookup_mandatory pjson ["vcs"] of
                      Json.ARRAY vv =>
                      map (fn (Json.STRING v) => vcs_from_name v
                          | _ => raise Fail "Strings expected in vcs array")
                          vv
                    | _ => raise Fail "Array expected for vcs",
                  remote_spec = {
                      anon = lookup_optional_string pjson ["anon"],
                      auth = lookup_optional_string pjson ["auth"]
                  }
                }
            val loaded = 
                case lookup_optional json ["providers"] of
                    NONE => []
                  | SOME (Json.OBJECT pl) => map (fn (k, v) => load v k) pl
                  | _ => raise Fail "Object expected for providers in config"
            val newly_loaded =
                List.filter (fn p => not (List.exists (fn pp => #service p =
                                                                #service pp)
                                                      previously_loaded))
                            loaded
        in
            previously_loaded @ newly_loaded
        end

    fun load_providers json =
        load_more_providers known_providers json
            
    (*!!! -> load_providers is written (above), now use it to read further providers from project spec, + allow override from user config *)

    (*!!! -> pick up account names from user config *)
                                                    
    fun expand_spec spec { vcs, service, owner, repo } =
        (* ugly *)
        let fun replace str = 
                case str of
                    "vcs" => vcs_name vcs
                  | "service" => service
                  | "owner" =>
                    (case owner of
                         SOME ostr => ostr
                       | NONE => raise Fail ("Owner not specified for service " ^
                                             service))
                  | "repo" => repo
                  | "account" => raise Fail "not implemented yet" (*!!!*)
                  | other => raise Fail ("Unknown variable " ^ other ^
                                         "} for service " ^ service)
            fun expand' acc sstr =
                case Substring.splitl (fn c => c <> #"{") sstr of
                    (pfx, sfx) =>
                    if Substring.isEmpty sfx
                    then rev (pfx :: acc)
                    else 
                        case Substring.splitl (fn c => c <> #"}") sfx of
                            (tok, remainder) =>
                            if Substring.isEmpty remainder
                            then rev (tok :: pfx :: acc)
                            else let val replacement =
                                         replace
                                             (* tok begins with "{": *)
                                             (Substring.string
                                                  (Substring.triml 1 tok))
                                 in
                                     expand' (Substring.full replacement ::
                                              pfx :: acc)
                                             (* remainder begins with "}": *)
                                             (Substring.triml 1 remainder)
                                 end
        in
            Substring.concat (expand' [] (Substring.full spec))
        end
        
    fun provider_url req [] =
        raise Fail ("Unknown service \"" ^ (#service req) ^
                    "\" for vcs \"" ^ (vcs_name (#vcs req)) ^ "\"")
      | provider_url req (({ service, supports, remote_spec } : provider) ::
                          rest) = 
        if service <> (#service req) orelse
           not (List.exists (fn v => v = (#vcs req)) supports)
        then provider_url req rest
        else case (#anon remote_spec) of
                 NONE => provider_url req rest
               | SOME spec => expand_spec spec req
                                        
    fun remote_url providers vcs source libname =
        case source of
            URL u => u
          | PROVIDER { service, owner, repo } =>
            provider_url { vcs = vcs,
                           service = service,
                           owner = owner,
                           repo = case repo of
                                      SOME r => r
                                    | NONE => libname }
                         providers
end
