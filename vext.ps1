#echo 'use "vext.sml"; check ();' | ..\..\PolyML-5.7-x64-windows-console\PolyML.exe -q --error-exit
#exit

$lines = @(Get-Content vext.sml)
$lines = $lines -notmatch "val _ = main ()"

$intro = @"
val smlrun__cp = 
    let val x = !Control.Print.out in
        Control.Print.out := { say = fn _ => (), flush = fn () => () };
        x
    end;
val smlrun__prev = ref "";
Control.Print.out := { 
    say = fn s => 
        (if String.isSubstring "Error" s orelse String.isSubstring "Fail" s
         then (Control.Print.out := smlrun__cp;
               (#say smlrun__cp) (!smlrun__prev);
               (#say smlrun__cp) s)
         else (smlrun__prev := s; ())),
    flush = fn s => ()
};
"@ -split "[\r\n]+"

$outro = @"
val _ = check ();
val _ = OS.Process.exit (OS.Process.success);
"@ -split "[\r\n]+"

$script = @()
$script += $intro
$script += $lines
$script += $outro

$tmpfile = ([System.IO.Path]::GetTempFileName()) -replace "[.]tmp",".sml"

$script | Out-File -Encoding "ASCII" $tmpfile

$env:CM_VERBOSE="false"

sml $tmpfile $args[1,$args.Length]

del $tmpfile

#echo 'use "vext.sml"; check ();' | sml @SMLcmdname=vext.sml -Ccm.verbose=false 

