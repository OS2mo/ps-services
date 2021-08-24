Using module "..\..\InvokeSQL.psm1"
Using module "..\..\GetAndExportSQLData.psm1"

#region - VARIABLER
#Bemærk, at hvis $PSScriptRoot (mappen som dette script er placeret i) anvendes til at angive den relative sti, så skal scriptet eksekveres fra en .ps1 fil.

#SQL server hostnavn og database
$SQLserver = "[DBserver]"
$SQLDatabase = "[DBname]"

#Sti til tekstfil der indeholder SQL query (filen skal være UTF-8 encoded) - filen må IKKE indeholde "--" comments. Brug i stedet "/* til kommentarer i filen
$SQLQueryFile = "$PSScriptRoot\Ledere_OBS_GetSQLdata.sql"

$OutputCSV = $True
$OutputCSVFileName = "$PSScriptRoot\output\LedereOBS.csv"
$OutputCSVEncodeAsUTF8BOM = $False # $False = UTF8, $True = UTF8-BOM

#endregion - VARIABLER

function errhandling {
    param ($message)
    $e = $_.Exception
    $line = $_.InvocationInfo.ScriptLineNumber
    $msg = $e.Message 
	
    Write-Host -ForegroundColor Red "$message exception at line: $line"
    Write-Host -ForegroundColor Red "$e"
    Write-Host -ForegroundColor Red $msg
    Write-Host -ForegroundColor Yellow "Terminating script!"
    Exit
}

# ------- SCRIPT START ------
$SQLqueryStatement = Get-Content $SQLQueryFile -Encoding UTF8
try {
    [SQLqueryHelper]$MySQLQuery = [SQLqueryHelper]::new($SQLserver, $SQLDatabase, $SQLqueryStatement)
    $SQLData = $MySQLQuery.DataArray()
}
catch {errhandling("Initializing SQLqueryHelper")
}

try {
    If ($OutputCSV) {
        $SQLData | ConvertTo-Csv -NoTypeInformation -Delimiter ";"  | Set-variable tmp
        If ($OutputCSVEncodeAsUTF8BOM) {
            $tmp | Out-File -FilePath $OutputCSVFileName -Encoding utf8
        }
        else {
            $UTF8woBomEncoding = New-Object System.Text.UTF8Encoding $False
            [System.IO.File]::WriteAllLines($OutputCSVFileName, [String[]]$tmp, $UTF8woBomEncoding)      
        }
    }
	
}
catch {errhandling("CSV eksport")}
