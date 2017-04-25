
structure Provider :> sig
    val remote_url : vcs -> source -> libname -> string
end = struct

    type url_spec = string
    type remote_spec = { anon : url_spec option, logged : url_spec option }
    type known_provider = string * vcs list * remote_spec
                           
    val known : known_provider list = [
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


(*!!! todo: validate owner & repo strings *)

    fun github_like_url domain (SOME owner, repo) =
        "https://" ^ domain ^ "/" ^ owner ^ "/" ^ repo
      | github_like_url domain (NONE, _) =
        raise Fail ("Owner required for repo at " ^ domain)

    val github_url = github_like_url "github.com"
    val bitbucket_url = github_like_url "bitbucket.org"
               
    fun remote_url vcs source libname =
        case source of
            URL u => u
          | PROVIDER { service, owner, repo } =>
            let val r = case repo of
                            SOME r => r
                          | NONE => libname
                val vcs_name = case vcs of GIT => "git" 
                                         | HG => "hg"
            in
                case service of
                    "github" => github_url (owner, r)
                  | "bitbucket" => bitbucket_url (owner, r)
                  | other => raise Fail ("Unsupported service \"" ^ service ^
                                         "\" for vcs \"" ^ vcs_name ^ "\"")
            end

end
