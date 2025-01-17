$ErrorActionPreference = 'Stop'

# $PrivateFunctions = @( Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "Private") )
$PublicFunctions = @( Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') )
ForEach ($function in <# $PrivateFunctions + #> $PublicFunctions)
{
    . $function.FullName
}
