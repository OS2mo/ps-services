Using module "..\InvokeSQL.psm1"
Using module "..\GetAndExportSQLData.psm1"

#region - VARIABLER
#Bemærk, at hvis $PSScriptRoot (mappen som dette script er placeret i) anvendes til at angive den relative sti, så skal scriptet eksekveres fra en .ps1 fil.

#SQL server hostnavn og database
$SQLserver = "[DBserver]"
$SQLDatabase = "[DBname]"

#Sti til tekstfil der indeholder SQL query (filen skal være UTF-8 encoded) - filen må IKKE indeholde "--" comments. Brug i stedet /* */ til kommentarer i filen
$SQLQueryFile = "$PSScriptRoot\BrugereMedEngagementerOgAdresser.sql"

$OutputCSV = $True
$OutputCSVFileName = "$PSScriptRoot\output\output.csv"
$OutputCSVEncodeAsUTF8BOM = $False # $False = UTF8, $True = UTF8-BOM

<#Multilevel JSON forudsætninger:
- Første sql kolonne skal hedde "uuid", og indeholde uuid på "main" elementet.
- Sublevel kolonner navngives med <sublevelpræfix>@<attributnavn> (eksempel: "Engagementer@tjnr", "Engagementer@Enhed", "Adresser@Telefon" osv.)
#>
$OutputJSON = $True
$OutputJsonMultilevel = $True
$OutputJSONFileName = "$PSScriptRoot\output\output.json"
$OutputJSONEncodeAsUTF8BOM = $False # $False = UTF8, $True = UTF8-BOM

$OutputXML = $True
$OutputXMLFileName = "$PSScriptRoot\output\output.xml"
$OutputXMLEncodeAsUTF8BOM = $True # $False = UTF8, $True = UTF8-BOM
$OutputXMLStartElementName = "Data" #Navn på 'hoved' XML elementet, som omkredser alle dataposter
$OutputXMLMainElementName = "Element" #Navn på XML elementet, som omkredser de enkelte dataposter (rækker)
$OutputXMLWriteFirstColAsAttribute = $False # Sæt til true, hvis første element i hver datapost skal skrives inde i MainElementet - eks: <Person UUID=xxxx>

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

try {
    If ($OutputJSON) {
        If ($True -eq $OutputJsonMultilevel) {
            $MySQLDataML = New-Object System.Collections.Generic.List[System.Object]
            $MySQLDataML = ConvertToMultilevel($SQLData)
            $MySQLDataML | ConvertTo-Json -Depth 3 | Set-variable tmp

        }
        else {
            $SQLData | ConvertTo-Json | Set-variable tmp    
        }
        
        If ($OutputJSONEncodeAsUTF8BOM) {
            $tmp | Out-File -FilePath $OutputJSONFileName -Encoding utf8
        }
        else {
            $UTF8woBomEncoding = New-Object System.Text.UTF8Encoding $False
            [System.IO.File]::WriteAllLines($OutputJSONFileName, [String[]]$tmp, $UTF8woBomEncoding)      
        }
    }
}
catch {errhandling("JSON eksport")}

try {
    If ($OutputXML) {
        OutputAsXML -Myquery $MySQLQuery -Outfilename "$OutputXMLFileName" -StartElementName $OutputXMLStartElementName -MainElementName $OutputXMLMainElementName -WriteFirstColAsAttribute $OutputXMLWriteFirstColAsAttribute -UseUTF8BOM $OutputXMLEncodeAsUTF8BOM
    }
	
}
catch {errhandling("XML eksport")}
