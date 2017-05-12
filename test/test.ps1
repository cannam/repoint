
"Hello"

$mydir = "$PSScriptRoot"

cd $mydir

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
    
    ..\vext check
    ..\vext update
    ..\vext check

    dir ext

    echo ""
}
    

    
