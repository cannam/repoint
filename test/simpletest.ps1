
$mydir = Split-Path $MyInvocation.MyCommand.Path -Parent

cd $mydir

echo @"
{
    "config": {
        "extdir": "ext"
    },
    "libraries": {
        "v1": {
            "vcs": "hg",
            "service": "bitbucket",
            "owner": "cannam",
            "repository": "repoint"
        },
        "v2": {
            "vcs": "git",
            "service": "github",
            "owner": "cannam",
            "repository": "repoint"
        }
    }
}
"@ | Out-File -Encoding ASCII repoint-project.json

$smlOptions = @("default", "poly", "smlnj")

foreach ($sml in $smlOptions) {

    echo ""
    echo "Testing with implementation: $sml"
    echo ""

    $env:REPOINT_SML=""
    if ($sml -ne "default") {
        $env:REPOINT_SML=$sml
    }

    Remove-Item ext -Recurse -Force -ErrorAction SilentlyContinue
    
    ..\repoint review
    ..\repoint update
    ..\repoint review

    echo ""
}
    

    
