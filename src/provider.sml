
structure Provider :> sig
    val remote_url : vcs -> source -> libname -> string
end = struct

    datatype account_status = WITH_ACCOUNT | WITHOUT_ACCOUNT
    datatype url_arg = LIT of string | OWNER | REPO | ACCOUNT | VCS | DIV

    type url_spec = url_arg list
                                                                              
    type remote_spec = { anon : url_spec option, logged : url_spec option }

    type known_provider = string * vcs list * remote_spec
                           
    val known : known_provider list = [
        ("bitbucket", [HG, GIT],
         { anon   = SOME [ LIT "https://bitbucket.org/",
                           OWNER, DIV, REPO ],
           logged = SOME [ LIT "ssh://", VCS, LIT "@bitbucket.org/",
                           OWNER, DIV, REPO ] }),
        ("github", [GIT],
         { anon   = SOME [ LIT "https://github.com/",
                           OWNER, DIV, REPO ],
           logged = SOME [ LIT "ssh://", VCS, LIT "@github.com/",
                           OWNER, DIV, REPO ] }),
        ("soundsoftware", [HG, GIT],
         { anon   = SOME [ LIT "https://code.soundsoftware.ac.uk/",
                           VCS, DIV, REPO ],
           logged = SOME [ LIT "https://", OWNER, LIT "@code.soundsoftware.ac.uk/",
                           VCS, DIV, REPO ] })
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
