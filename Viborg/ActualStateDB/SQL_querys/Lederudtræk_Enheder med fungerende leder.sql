/*
Enheder med fungerende leder
Forudsætter custom (ikke standard) view:
- Brugere_Primær_AD_Email

Udtrækket medtager ALLE enheder i den administrative organisation, og viser oplysninger om den aktuelle fungerende leder på enheden (nedarvning)
Udtrækket frasorterer pt. IKKE evt. ledere som ikke har en aktiv ansættelse
*/

SELECT
    enheder.uuid AS 'Enhed UUID',
    enheder.navn AS 'Enhedsnavn',
    enheder.enhedsniveau_titel,
    enheder.organisatorisk_sti,
    CONCAT (brugere.fornavn, ' ', brugere.efternavn) AS 'Fungerende Leder navn',
    pm.Primær_EMail AS 'Fungerende leder e-mail',
    brugere.uuid AS 'Fungerende leder bruger uuid'

FROM [DBname].[DBuser].[enheder]

LEFT JOIN [DBname].[DBuser].ledere 
ON enheder.fungerende_leder_uuid = ledere.uuid

LEFT JOIN [DBname].[DBuser].brugere
ON ledere.bruger_uuid = brugere.uuid

LEFT JOIN [DBname].[DBuser].Brugere_Primær_AD_Email pm 
ON brugere.uuid = pm.Bruger_UUID

WHERE
NOT enhedsniveau_titel = 'Afdelings-niveau' AND NOT enhedsniveau_titel = 'NY1-niveau' AND ((organisatorisk_sti LIKE 'Viborg Kommune%'))

ORDER BY enheder.organisatorisk_sti