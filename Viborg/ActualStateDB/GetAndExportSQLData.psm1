<#	
	.NOTES
	===========================================================================
	 Created by:   	Kim Andersen
	 Organization: 	Viborg Kommune
     Version: 1.1
	===========================================================================
	.DESCRIPTION
		Dette modul tilbyder funktioner til at læse data fra SQL, og på baggrund af disse data generere
		et XML, JSON og/eller CSV output med de pågældende data.
		Scriptet er udviklet til at blive anvendt sammen med OS2mo-Actual-state databaser:
        https://github.com/OS2mo/os2mo-data-import-and-export/tree/development/exporters/sql_export
        
        SQL adgang autoriseres med rettighederne for den Windows bruger, som eksekverer scriptet (via kerberos).

# Forudsætter: https://github.com/Tervis-Tumbler/InvokeSQL/blob/master/InvokeSQL.psm1
InvokeSQL.psm1 modulet skal være importeret i scripts, som anvender dette modul. Eksempel:

Using module ".\InvokeSQL.psm1"
Using module ".\GetAndExportSQLData.psm1"
#>

#region - SQL helper class
class SQLqueryHelper {
    [string]$SQLServer
    [String]$SQLdatabase
    [string]$SQLCommand
    [Int]$Rowlength #Antal returnerede rækker i SQL query
    [System.Management.Automation.PSObject]$DataRows
    [System.Management.Automation.PSObject]$DataHeaders
	
    SQLqueryHelper(
        [string]$server,
        [String]$database,
        [string]$Command
    ) {
        $this.SQLServer = $server
        $this.SQLdatabase = $database
        $this.SQLCommand = $Command
        $this.DataRows = Invoke-MSSQL -Server $server -database $database -SQLCommand $Command -ConvertFromDataRow:$false

        if (!$this.DataRows) {
            $this.Rowlength = 0
        }
        elseif ($this.DataRows[0].GetType().Name -eq 'DataRow') {
            # Hvis datatypen på det første element er DataRow, så er elementet et array, og så består DataRows variabelen af et array af arrays. Dvs. der er mere end 1 række i resultatet
            $this.Rowlength = $this.DataRows.length 
            $this.DataHeaders = $this.DataRows[0].psobject.Properties.name | Where-Object { ($_ -notin "RowError", "RowState", "Table", "ItemArray", "HasErrors")}
        }
        else {
            $this.Rowlength = 1
            $this.DataHeaders = $this.DataRows.psobject.Properties.name | Where-Object { ($_ -notin "RowError", "RowState", "Table", "ItemArray", "HasErrors")}
        }
    }
	
    [Array]DataArray() {
        $OutArray = @()
        foreach ($row in $this.DataRows) {
            $RowData = [ordered]@{ }
            foreach ($header in $this.DataHeaders) {
                $RowData[$($header)] = $row.$($header)
            }
            $OutArray += New-Object System.Management.Automation.PSObject -Property $RowData
            Remove-Variable "RowData"
        }
        return $OutArray
    }
	
}
#endregion - SQL helper class

#region - functions
function OutputAsXML {
    param ($Myquery,
        [Parameter(Mandatory = $true)]
        [string]$Outfilename,
        #Filnavn og sti til XML fil

        [Parameter(Mandatory = $true)]
        [string]$StartElementName,
        #Navn på hoved XML elementet, som omkredser alle dataposter

        [Parameter(Mandatory = $true)]
        [string]$MainElementName,
        #Navn på XML elementet, som omkredser de enkelte dataposter (rækker)

        [Parameter(Mandatory = $false)]
        [bool]$WriteFirstColAsAttribute = $false, # Sæt til true, hvis første element i hver datapost skal skrives internt i MainElementet - eks: <Person UUID=xxxx>

        [Parameter(Mandatory = $false)]
        [bool]$UseUTF8BOM = $false # Sæt til true, hvis UTF8-BOM skal anvendes
    )
	
    # this is where the document will be saved:
    Remove-Item $Outfilename -ErrorAction Ignore
        
    # get an XMLTextWriter to create the XML
    $encoding = [System.Text.Encoding]::UTF8
    $XmlWriter = New-Object System.XMl.XmlTextWriter($Outfilename, $encoding)
        
    # choose a pretty formatting:
    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 1
    $XmlWriter.IndentChar = "`t"
        
    # write the header
    $xmlWriter.WriteStartDocument()
        
    # create root elements
    $xmlWriter.WriteStartElement($StartElementName)
        
    foreach ($row in $Myquery.DataArray()) {
            
        #$XmlWriter.WriteElementString($ElementKey, $row.$($ElementKey))
        $firstheader = $true
            
        foreach ($header in $Myquery.DataHeaders) {
            if ($firstheader) {
                $XmlWriter.WriteStartElement($MainElementName)
                if ($WriteFirstColAsAttribute) {
                    $XmlWriter.WriteAttributeString($header, $row.$($header))
                }
                else {
                    $XmlWriter.WriteElementString($header, $row.$($header))
                }
                    
                $firstheader = $false
            }
            else {
                $XmlWriter.WriteElementString($header, $row.$($header))
            }
                
        }
        $xmlWriter.WriteEndElement()
    }
        
    $xmlWriter.WriteEndElement()
    
    # finalize the document:
    $xmlWriter.WriteEndDocument()
    $xmlWriter.Flush()
    $xmlWriter.Close()

    If (!$UseUTF8BOM) {
        [XML] $XmlDocument = ( Select-Xml -Path $Outfilename  -XPath / ).Node

        [System.Xml.XmlWriterSettings] $XmlSettings = New-Object System.Xml.XmlWriterSettings
        
        #Preserve Windows formating
        $XmlSettings.Indent = $true
        
        #Keeping UTF-8 without BOM
        $XmlSettings.Encoding = New-Object System.Text.UTF8Encoding($false)
        
        [System.Xml.XmlWriter] $XmlWriter = [System.Xml.XmlWriter]::Create($Outfilename, $XmlSettings)
        $XmlDocument.Save($XmlWriter)
        
        #Close Handle and flush
        $XmlWriter.Dispose()
    }
}

#Funktion til at udtrække sublevelnavn eller attributnavn på en header (eksempel: "Engagementer@tjnr" - sublevelname=Engagementer, Attributename=tjnr )
function ExtractSublevel {
    param (
        [Parameter(Mandatory=$true)]    
        #[String[]]
        $inputstring, 
        
        [Parameter(Mandatory=$true)]
        [Validateset("Sublevelname","Attributename")]
        [String[]]
        $ValueToExtract
    )

    if (-not ([string]::IsNullOrEmpty($inputstring))) {
        if ($ValueToExtract -eq 'Sublevelname') {
            return $inputstring.Substring(0, $inputstring.IndexOf("@"))
        }
        if ($ValueToExtract -eq 'Attributename') {
            return $inputstring.substring($inputstring.IndexOf("@") + 1)
        }

    }
}



function ConvertToMultilevel {
    param ($Myquery)

    [System.Collections.ArrayList]$baselevelheaders = @{} <#Array med navne på attributter (headers), som IKKE er nestede værdier/multilevel (f.eks. "Fornavn","Efternavn") #>
    [System.Collections.ArrayList]$sublevelheaders = @{} <#Array med navne på attributter (headers), som ER nestede værdier/multilevel (f.eks. "Engagementer@uuid","Engagementer@tjnr") #>
    [System.Collections.ArrayList]$sublevelnames = @{} <#Array med unikke navne på nestede niveauer (f.eks: "Engagementer","MED-roller") #>
    
    #Populerer baselevelheaders, sublevelheaders og sublevelnames variablerne med værdier
    $headers = $SQLData[0].PSObject.Properties | ForEach-Object { $_.Name } 
    foreach ($header in $headers) {
        If ($header.IndexOf("@") -eq -1) {
            $baselevelheaders.Add($header) | out-null
        }
        else {
            $tmpsublevelname = ExtractSublevel -inputstring $header -ValueToExtract "Sublevelname"
            If (-not $sublevelnames.Contains($tmpsublevelname)) {
                $sublevelnames.Add($tmpsublevelname) | out-null
            }
            $sublevelheaders.Add($header) | out-null
        }
    }

    #Variabel der holder det samlede datasæt (med nestede værdier), som returneres af denne funktion
    $SQLdataNested = New-Object System.Collections.Generic.List[System.Object]
    $ProgressCount= 0
    Foreach ($row in $SQLData) {

        #Behandeler kun rækker med dette UUID - bruges ved debugging
        #if ('4abe1bc6-339e-4de7-a065-c7d168269339' -ne $row.uuid) {continue}

        #Hver datapost kan være repræsenteret i flere rækker i datafilen. Hvis den pågældende række allerede er medtaget springer vi den derfor over
        If ($null -eq ($SQLDataNested | where-object uuid -eq $row.uuid)) { 
            
            #Variabel til den nye beregnede datapost for denne række (inkl. multilevelværdier fra supplerende rækker med samme UUID)
            $NewThisRow = New-Object PSObject

            #Tilføjer alle attributter, som IKKE er nestede/multilevel værdier, til $NewThisRow
            foreach ($header in $baselevelheaders) {
                $NewThisRow | Add-Member -type NoteProperty -Name $header -Value $row.($header)
            }

            #Finder alle rækker for det pågældende UUID i datasættet for at bygge multilevel attributterne for det pågældende uuid
            $allRowsThisUUID = $SQLData | Where-Object uuid -eq $row.uuid

            #Loop igennem alle nestede/multilevel sektioner i datasættet (f.eks. Engagementer@)
            foreach ($sublevelname in $sublevelnames) {
                $NewThisRowThissublevel = New-Object System.Collections.Generic.List[System.Object]

                #Loop igennem alle rækker med samme uuid som den aktuelle $row.uuid
                foreach ($thisrow in $allRowsThisUUID) {
                    #Variabel hvor vi tilføjer attributterne for det aktuelle $sublevelname
                    $NewThissublevelThisName = New-Object PSObject
                    $IncludeThisSublevelThisRow = $False

                    # Loop igennem alle attributter med præfix det aktuelle sublevelnavn (f.eks. Engagementer@* )
                    foreach ($sublevelheader in ($sublevelheaders -match $($sublevelname + "@"))) {
                        $tmpattributename = ExtractSublevel -inputstring $sublevelheader -ValueToExtract "Attributename"
                        
                        If (-not ([string]::IsNullOrEmpty($thisrow.($sublevelheader)))) {
                            $NewThissublevelThisName | Add-Member -type NoteProperty -Name $tmpattributename -Value $thisrow.($sublevelheader)
                            $IncludeThisSublevelThisRow = $True
                        }
                            
                    }
                    
                    #Vi medtager kun rækken elementet med dette sublevelname fra denne række, hvis den ikke er tom og den samme datapost ikke allerede er tilføjet
                    $CompareElements = $newThisRowThissublevel | foreach-object {if (compare-object -ReferenceObject $_.psobject.properties -differenceObject $newthissublevelthisname.psobject.properties) {$true} else {$false}}
                    If ($IncludeThisSublevelThisRow) {
                        If ([string]::isnullorempty($CompareElements)) {
                            $NewThisRowThissublevel.Add($NewThissublevelThisName)
                        }
                        else {
                            if ($CompareElements -is [array]) {
                                if (-not $CompareElements.contains($false)) {
                                    $NewThisRowThissublevel.Add($NewThissublevelThisName)
                                }

                            }
                            elseif ($compareelements -eq $true) {
                                $NewThisRowThissublevel.Add($NewThissublevelThisName)
                            }
                        }
    
                    } 
            
                }

                $NewThisRow | Add-Member -Type NoteProperty -Name $sublevelname -Value $NewThisRowThissublevel
            }    

            $SQLdataNested.Add($NewThisRow) 
        }
        $ProgressCount++
        Write-Progress -Activity 'Converting to multilevel' -Status "$ProgressCount of $($SQLData.count) completed"
    }
#write-host 'End multilevelfunction'
return $SQLdataNested
}
#endregion - functions

