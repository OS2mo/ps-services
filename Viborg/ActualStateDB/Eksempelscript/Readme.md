# Powershell Actualstate sql eksport

Powershell scriptet: [Eksempelscript.ps1](Eksempelscript.ps1) viser hvordan de 2 PS moduler (GetAndExportSQLData.psm1 og InvokeSQL.psm1) kan bruges til at trække data ud fra OS2mo ActualState databasen med Powershell.

Powershell scriptet anvender en .sql fil (som skal indeholde en sql query) som input. Filen: [BrugereMedEngagementerOgAdresser.sql](BrugereMedEngagementerOgAdresser.sql) anvendes i dette eksempel.

Den bruger der eksekverer scriptet skal have rettighed til at tilgå SQL databasen.

Scriptet understøtter eksport til CSV, XML og JSON.

JSON kan dannes i "multilevel", forudsat at kolonnerne i SQL udtrækket er navngivet på en bestemt måde. Se [output.json](output/output.json) som netop anvender "mulilevel" eksport, hvor brugeres engagementer er inkluderet "nestede" under brugerens element.

Eksempelscriptet understøtter encoding i henholdsvis UTF-8 og UTF-8 BOM.

Scriptet forudsætter en række variabler som sættes øverst. Dokumentation af disse er indlejret i scriptet.

Se eksempel output i de forskellige formater i Output mappen.
