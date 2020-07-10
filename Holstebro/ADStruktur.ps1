#$ScriptVersion = 2.2

# ----- Settings ---------- #
$SettingOURoot = "OU=HK,DC=holstebro,DC=dk" # Roden skal være oprettet. Angiver roden for hvor scriptet skal arbejde fra.
$SettingAutoritativOrg = "hKAutoriativOrg" # Angiv navnet på den attribut som indeholder den autoritative organisation
$SettingLogPath = "C:\PSScript\" # Angiv stien til hvor log filer skal placeres (Format: "C:\PSScript\")
$SettingLogsToKeep = 10 # Angiv hvor mange log filer der skal gemmes (der laves en ny log fil med dato og tid, for hver kørsel af scriptet)

# ----- Faste variabler --- #
$global:movedcount = 0 
$global:EmptyOUsRemoved = 0

# ----- Funktioner -------- #
# Renser organisationsnavnet for uønskede tegn
function Get-SanitizedUTF8Input{
    Param(
        [String]$inputString
    )
    $replaceTable = @{"ß"="ss";"à"="a";"á"="a";"â"="a";"ã"="a";"ä"="a";"ç"="c";"è"="e";"é"="e";"ê"="e";"ë"="e";"ì"="i";"í"="i";"î"="i";"ï"="i";"ð"="d";"ñ"="n";"ò"="o";"ó"="o";"ô"="o";"õ"="o";"ö"="o";"ù"="u";"ú"="u";"û"="u";"ü"="u";"ý"="y";"þ"="p";"ÿ"="y";","=""}
    foreach($key in $replaceTable.Keys){$inputString = $inputString -Replace($key,$replaceTable.$key)}
    return $inputString
}

# Placer bruger i OU struktur ud fra den autoritive organisation. Opretter stuktur hvis den ikke findes.
function Set-AutoritativOrg {
    Param (
        [Parameter(Mandatory=$true)][string]$Username,
        [string]$OURoot = $SettingOURoot, # Default value, kan overskrives under kørsel af funktion
        [string]$AutoritativOrg = $SettingAutoritativOrg # Default value, kan overskrives under kørsel af funktion
    )

    # Henter AD information omkring den aktuelle bruger
    $User = Get-ADUser -Identity $Username -Properties $AutoritativOrg

    If ($user.$AutoritativOrg -eq $null) {
    Write-host "Attributten $AutoritativOrg er tom" -ForegroundColor Red
    Return
    }

    # Renser organisationnavnet for uønskede tegn
    $AutoritativOrg = get-sanitizedUTF8Input -inputString $User.$AutoritativOrg

    # Omskriv til OU path
    $AutoritativOrgOU = $AutoritativOrg.Split("\") | foreach {$_ = "OU="+$_;$_}
    [array]::Reverse($AutoritativOrgOU)
    $AutoritativOrgOU = $AutoritativOrgOU -join ","

    # Sammensæt den fulde OU sti
    $path = $AutoritativOrgOU+","+$OURoot

    # Hvis mappen findes, så placer brugeren her
    If ([adsi]::Exists("LDAP://$path") -eq $true) {
        Write-host "OU findes: $path" -ForegroundColor Green
        
        If ((($user.DistinguishedName.Split(",")[1..100]) -join ",") -eq $path){
            Write-host "Brugeren er allerede placeret det rigtige sted: $path" -ForegroundColor Green
        }
        Else{
            Write-host "Brugeren flyttes til: $path" -ForegroundColor Green
            Move-ADObject -Identity $User.objectguid -TargetPath $path -Verbose
            $global:movedcount++
        }
    }

    # Hvis mappen ikke findes, så test hver del af stien og opret det der mangler.
    Else {
        $niveauer = $AutoritativOrgOU -split(",")
        $count = -2

        #Tjek om første led findes, ellers opret den
        $currentpath = ($niveauer[-1] -join ",")+","+$OURoot
        If ([adsi]::Exists("LDAP://$currentpath")){
            Write-host "Første led findes" $currentpath -ForegroundColor Green
        }
        Else {
            write-host "Opretter første led" -ForegroundColor Yellow
            $Name = (($niveauer[-1]).replace("OU=",""))
            New-ADOrganizationalUnit -name $name -Path $OURoot -ProtectedFromAccidentalDeletion $false -Verbose
        }

        # Tjek om alle underliggende led findes, ellers opret dem
        Do {
            $currentpath = ($niveauer[$count..-1] -join ",")+","+$OURoot
    
            If ([adsi]::Exists("LDAP://$currentpath")){
                Write-host "Findes" $currentpath -ForegroundColor Green
            }
            Else {
                write-host "Opretter underliggende sti" -ForegroundColor Yellow
                $newpath = (($niveauer[($count+1)..-1] -join ",")+","+$OURoot)
                $Name = (($niveauer[$count]).replace("OU=",""))
                New-ADOrganizationalUnit -name $name -Path $newpath -ProtectedFromAccidentalDeletion $false -Verbose
            }
        $count--
        } Until ($count -eq ((-$niveauer.count)-1))

        # Placer brugeren i brugerens OU
        Write-host "Brugeren places her: $currentpath" -ForegroundColor Green
        Move-ADObject -Identity $User.objectguid -TargetPath $path -Verbose    
    }
}

# Ryder op i OU strukturen, ved at fjerne tomme OU'er
function CleanUpEmptyOU {
Do{
    $EmptyOU = Get-ADOrganizationalUnit -Filter * -SearchBase $SettingOURoot | ForEach-Object { If (!(Get-ADObject -Filter * -SearchBase $_ -SearchScope OneLevel)) {$_}}

    ForEach ($OU in $EmptyOU) {
    Set-ADOrganizationalUnit -Identity $OU.DistinguishedName -ProtectedFromAccidentalDeletion $false
    Remove-ADOrganizationalUnit -Identity $OU.DistinguishedName -Confirm:$false
    Write-host "Følgende OU er tom og dermed fjernet: "$OU.DistinguishedName -ForegroundColor Green
    $global:EmptyOUsRemoved++
    }
} While ($EmptyOU -ne $null)

}

# Funktion til logning
function Start-Log {
$Timestamp = Get-Date -Format "D.dd.mm.yyyy.T.HH.mm"

# Angiver unikt navn til log filen
$LogFilePath = $SettingLogPath + "Log." + $Timestamp + ".txt"

# Slet gamle log filer
Get-ChildItem -Path $SettingLogPath | Sort-Object CreationTime -Descending | Select -Skip $SettingLogsToKeep | Remove-Item -Force

Start-Transcript -Path $LogFilePath
}

# ----- Run -------------- #

# Starter transcript logning
Start-Log

# Kør for én bestemt bruger
#$Users = Get-ADUser -Identity "itattest"

# Kør for alle brugere, i forhold til $SettingOURoot
#$Users = Get-ADUser -Filter * -SearchBase $SettingOURoot

$time = Measure-Command {

    # Foretag flytning af brugere og oprettelse af OU'er
    Foreach ($User in $Users) {
    $username = $User.SamAccountName
    Write-host "Starter process for $username" -ForegroundColor Yellow
    Set-AutoritativOrg -Username $username
    Write-host "Færdig" -ForegroundColor Yellow
    }

    # Foretag oprydning i tomme OU'er
    CleanUpEmptyOU

} | Select-Object TotalSeconds

Write-host "Total users: "$users.count
Write-host "Moved users: "$global:movedcount
Write-host "Empty OUs removed:" $global:EmptyOUsRemoved
Write-host "Total time (sec):" $time.TotalSeconds
Write-host ""

# Stopper logning
Stop-Transcript