
structure Provider :> sig
    val remote_url : vcs -> source -> libname -> string
end = struct

    type url_spec = string
    type remote_spec = { anon : url_spec option, logged : url_spec option }
    type known_provider = string * vcs list * remote_spec
                           
    val known_providers : known_provider list = [
        ("bitbucket", [HG, GIT], {
             anon = SOME "https://bitbucket.org/{owner}/{repo}",
             logged = SOME "ssh://{vcs}@bitbucket.org/{owner}/{repo}"
         }),
        ("github", [GIT], {
             anon = SOME "https://github.com/{owner}/{repo}",
             logged = SOME "ssh://{vcs}@github.com/{owner}/{repo}"
         }),
        ("soundsoftware", [HG, GIT], {
             anon = SOME "https://code.soundsoftware.ac.uk/{vcs}/{repo}",
             logged = SOME "https://{account}@code.soundsoftware.ac.uk/{vcs}/{repo}"
        })
    ]

    fun vcs_name vcs = case vcs of GIT => "git" 
                                 | HG => "hg"

    fun expand_spec spec { vcs, service, owner, repo } =
        (* ugly *)
        let fun make_replacement tok = 
                case tok of
                    "{vcs" => vcs_name vcs
                  | "{service" => service
                  | "{owner" =>
                    (case owner of
                         SOME ostr => ostr
                       | NONE => raise Fail ("Owner not specified for service " ^
                                             service))
                  | "{repo" => repo
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
                                         make_replacement (Substring.string tok)
                                 in
                                     expand' (Substring.full replacement ::
                                              pfx :: acc)
                                             (* remainder begins with "}": *)
                                             (Substring.triml 1 remainder)
                                 end
        in
            Substring.concat (expand' [] (Substring.full spec))
        end
        
    fun provider_url { vcs, service, owner, repo } [] =
        raise Fail ("Unsupported service \"" ^ service ^
                    "\" for vcs \"" ^ (vcs_name vcs) ^ "\"")
      | provider_url (req as { vcs, service, owner, repo })
                     ((service_name, vcses, specs) :: rest) = 
        if service_name <> service orelse
           not (List.exists (fn v => v = vcs) vcses)
        then provider_url req rest
        else case (#anon specs) of
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
