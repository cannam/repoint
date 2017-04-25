
structure Provider :> sig
    val remote_url : vcs -> source -> libname -> string
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

    (*!!! -> read further providers from project spec, + allow override from user config *)

    (*!!! -> pick up account names from user config *)
                                                    
    fun vcs_name vcs = case vcs of GIT => "git" | HG => "hg"

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
      | provider_url req ({ service, supports, remote_spec } :: rest) = 
        if service <> (#service req) orelse
           not (List.exists (fn v => v = (#vcs req)) supports)
        then provider_url req rest
        else case (#anon remote_spec) of
                 NONE => provider_url req rest
               | SOME spec => expand_spec spec req
                                        
    fun remote_url vcs source libname =
        case source of
            URL u => u
          | PROVIDER { service, owner, repo } =>
            provider_url { vcs = vcs,
                           service = service,
                           owner = owner,
                           repo = case repo of
                                      SOME r => r
                                    | NONE => libname }
                         known_providers
end
