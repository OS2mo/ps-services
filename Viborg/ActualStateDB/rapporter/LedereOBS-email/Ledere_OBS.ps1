$CSVinputFile = "$PSScriptRoot\output\LedereOBS.csv"
$CSVyesterdayFile = "$PSScriptRoot\output\LedereOBS_yesterday.csv"
$EmailTo = "hrafdeling@viborg.dk"
$SMTPserver = "smtprelay.local"
$SMTPFrom = "OS2mo <grunddata@viborg.dk>"
$SMTPSubject = "OS2mo rapport med lederregistreringer"

Add-Type -AssemblyName System.Web

If (-not [System.IO.File]::Exists($CSVinputFile)) {
    Write-host "Igen LedereOBS.csv fil - exit script." -ForegroundColor Red
    Exit
}

If (-not [System.IO.File]::Exists($CSVyesterdayFile)) {
    #Opretter en tom 'LedereOBS_yesterday.csv' fil, hvis filen ikke eksisterer - "first run scenarie"
    '"Navn"' > $CSVyesterdayFile
}

$CSVFileRaw = Get-Content $CSVinputFile -Encoding UTF8
$CSVFile = $CSVFileRaw | ConvertFrom-Csv -Delimiter ";" 
$CSVFileyesterdayRaw = Get-Content $CSVyesterdayFile -Encoding UTF8
$CSVFileyesterday = $CSVFileyesterdayRaw | ConvertFrom-Csv -Delimiter ";"
$FoundNew=$false

ForEach ($item in $CSVFile) {
    if (-not ($CSVFileyesterday -match $item.navn)) {
        $item.navn = "<span style='background-color: #FFFF00'>" + $item.navn + "</span>"
        $FoundNew=$true
    }
}

$csvHTMLraw = $CSVFile | ConvertTo-Html -Fragment
$csvHTML =  [System.Web.HttpUtility]::HtmlDecode($csvHTMLraw)

$body = @"
<style>
table, td, th {border: 1px solid black;}
table {border-collapse: collapse;}
td, th {padding: 5px;}
a {color:black;}
a:link {text-decoration: none;}
a:visited {text-decoration: none;}
a:hover {text-decoration: underline;}
a:active {text-decoration: underline;}
#footer div {font-size: small;}
#systeminfo p {font-size: xx-small;color:lightgrey;}
</style>
<h3>Tabellen indeholder registreringer vedrørende ledere, som bør undersøges nærmere</h3>
"@ + $csvHTML + @"
<br>
<div id="footer">
<span style='background-color: #FFFF00'>Nye siden sidste rapport er markeret med gult</span>
<h4>Registreringer som kommer med i dette udtræk</h4>
<p>1. Lederregistreringer af typen: "Personale: MUS-kompetence og omsorgs-/sygesamtaler", hvor:</p>
<ul>
<li>den tilknyttede person har ikke et aktivt engagement</li>
<li>det primære engagementet er ikke af typen: "Medarbejder (månedsløn)"</li>
<li>personens primære engagement ændres inden for de næste 21 dage</li>
<li>rollen gælder for en udgået enhed</li>
<li>samme person også er leder af den tilknyttede enheds forældreenhed (Kommunaldirektøren er undtaget, da han skal stå på "Kommunaldirektørens område" af hensyn til musskema)</li>
<li>attributten "ledertype" er tom eller forkert udfyldt</li>
<li>attributten "lederniveau" er ikke udfyldt</li>
<li>flere registreringer gælder for samme enhed (der må kun være én leder pr. enhed)</li>
</ul>
<p>2. Engagementer hvor:</p>
<ul>
<li>stillingskoden er 1030,1035,1040 UDEN personen samtidig har en lederrolle i OS2mo</li>
</ul>
</div>
<div id="systeminfo">
<p><b>Sent fra:</b> $env:computername 
<br>
<b>Script location:</b> $PSScriptRoot 
</p>
</div>
"@

If ($FoundNew) {
    Write-host "Sender Email til: $EmailTo"
    Send-MailMessage -To $EmailTo -Subject $SMTPSubject -Body $body -BodyAsHtml -Encoding "UTF8" -From $SMTPFrom -SmtpServer $SMTPserver -UseSsl
}
else {
    Write-Host 'INGEN E-mail sendt - ikke noget nyt at rapportere.'
 }
Copy-Item -Path $CSVinputFile -Destination $CSVyesterdayFile

