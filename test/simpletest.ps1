
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
            "repository": "vext"
        },
        "v2": {
            "vcs": "git",
            "service": "github",
            "owner": "cannam",
            "repository": "vext"
        }
    }
}
"@ | Out-File -Encoding ASCII vext-project.json

$smlOptions = @("default", "poly", "smlnj")

foreach ($sml in $smlOptions) {

    echo ""
    echo "Testing with implementation: $sml"
    echo ""

    $env:VEXT_SML=""
    if ($sml -ne "default") {
        $env:VEXT_SML=$sml
    }

    Remove-Item ext -Recurse -Force -ErrorAction SilentlyContinue
    
    ..\vext review
    ..\vext update
    ..\vext review

    echo ""
}
    

    
