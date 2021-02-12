/*
Denne query forudsætter følgende custom (ikke standard) views:
- LedereMedNiveau_UnikTilHøjesteRangering
- Engagementer_Stillingsbetegnelser
- Brugere_Primær_AD_Email
- Engagementer_Nærmesteleder

Generelt brugerudtræk med alle ansættelser
Medtager ALLE ansættelser, så en person kan fremtræde flere gange i udtrækket (filtrer evt. via 'Primær' kolonne)
Vi medtager KUN personer i organisationstræet "Viborg Kommune" (administrativ org.)
Pt. er private institutioner således med i udtrækket.
Eksterne/byrådsmedlemmer og andre 'ikke ansatte' er IKKE med i udtrækket.
*/
SELECT 
    b1.fornavn AS 'Fornavn'
    ,b1.efternavn AS 'Efternavn'
    ,a1.Primær_Email AS 'E-mail'
    ,e1.Stilling_filtered AS 'Stillingsbetegnelse'
    ,a2.værdi AS 'Mobiltelefon'
    ,a3.værdi AS 'Telefon'
    ,a5.værdi AS 'Telefon (offentlig)'
    ,b1.cpr AS 'CPR-nummer'
    ,e.bvn AS 'Tjeneste nr'
    ,e.engagementstype_titel AS 'Engagementstype'
    ,e.primær_boolean AS 'Primær'
    ,e.primærtype_titel AS 'Primærtype'
    ,e.slutdato AS 'Slut dato'
    ,l1.Niveautype AS 'Egen lederrolle'
    ,enheder1.organisatorisk_sti AS 'Enhed_parentsti'
    ,enheder1.organisatorisk_sti AS 'Enhed_parentsti1'
    ,CONCAT(lb2.fornavn,' ' , lb2.efternavn) AS 'Nærmeste leder'
    ,a4.Primær_Email AS 'Nærmeste leder e-mail'

FROM [DBname].[DBuser].[brugere] b1

LEFT JOIN [DBname].[DBuser].LedereMedNiveau_UnikTilHøjesteRangering l1 /* Brugerens evt. lederniveau */
ON b1.uuid = l1.[Bruger UUID]

INNER JOIN [DBname].[DBuser].[engagementer] e /*  Brugerens Engagementer */
ON b1.uuid = e.bruger_uuid

INNER JOIN [DBname].[DBuser].[enheder] enheder1 /*  Engagementets tilknyttede enhed */
ON enheder1.uuid = e.enhed_uuid

LEFT JOIN [DBname].[DBuser].Engagementer_Stillingsbetegnelser e1 /* Engagementets stillingsbetegnelse (beregnet) */
ON e.uuid = e1.Engagement_uuid

LEFT JOIN [DBname].[DBuser].Brugere_Primær_AD_Email a1 /*  Brugerens e-mail adresse */
ON b1.uuid = a1.Bruger_UUID 

LEFT JOIN [DBname].[DBuser].[adresser] a2 /*  Brugerens mobil tlf. */
ON b1.uuid = a2.bruger_uuid AND a2.adressetype_uuid='7db54183-1f2c-87ba-d4c3-de22a101ebc1'

LEFT JOIN [DBname].[DBuser].[adresser] a3 /*  Brugerens tlf. */
ON b1.uuid = a3.bruger_uuid AND a3.adressetype_uuid='3dda78a5-f953-5498-04d6-5a23aeed0792' AND a3.synlighed_uuid='12fd2a30-2bb6-4d81-4a8e-af2e2e2a0bdc'

LEFT JOIN [DBname].[DBuser].[adresser] a5 /*  Brugerens offentlige tlf. */
ON b1.uuid = a5.bruger_uuid AND a5.adressetype_uuid='3dda78a5-f953-5498-04d6-5a23aeed0792' AND a5.synlighed_uuid='aad0b1a0-e658-0aac-0a52-368bc5ec5b80'

LEFT JOIN [DBname].[DBuser].Engagementer_Nærmesteleder e2 /*  Engagementets nærmeste leder */
ON e.[uuid] = e2.[Engagement UUID]

INNER JOIN [DBname].[DBuser].[brugere] lb2 /*  Engagementets nærmeste leders brugerobjekt */
ON e2.[Nærmeste leder UUID] = lb2.uuid

LEFT JOIN [DBname].[DBuser].Brugere_Primær_AD_Email a4 /*  Nærmeste leders e-mail */
ON lb2.uuid = a4.Bruger_UUID

WHERE

enheder1.organisatorisk_sti LIKE 'Viborg Kommune%' /* Fjern Byråd og Eksterne */

ORDER BY enheder1.organisatorisk_sti, b1.efternavn, b1.fornavn