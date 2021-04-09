/* Denne query henter alle brugere som har mindst ét aktivt Engagement.
Der returneres diverse stamdata, og kolonnerne vedr. Engagementsrelaterede data formatteret således at json eksport kan anvende "multilevel"
*/
SELECT TOP (3)
    b.uuid AS 'uuid'
    , IIF(b.kaldenavn_fornavn IS NULL OR b.kaldenavn_fornavn='', b.fornavn, b.kaldenavn_fornavn) AS 'Fornavn'
    , IIF(b.kaldenavn_efternavn IS NULL OR b.kaldenavn_efternavn='', b.efternavn, b.kaldenavn_efternavn) AS 'Efternavn'
    , IIF(l.Niveautype IS NULL, 0, 1) AS 'Er_leder'
    , e.uuid AS 'Engagementer@Engagement_uuid'
    , e.primær_boolean AS 'Engagementer@Primær'
    , u.uuid AS 'Engagementer@OrgEnhed_uuid'
    , u.navn AS 'Engagementer@OrgEnhed_navn'
    , u.organisatorisk_sti AS 'Engagementer@OrgEnhed_parentsti'
    , e2.[Nærmeste leder UUID] AS 'Engagementer@Leder_person_UUID'
    , a1.Primær_Email AS 'Email'
    , a3.værdi AS 'Telefon'  
    , a4.værdi AS 'Mobiltelefon'

FROM [DBName].[DBuser].[brugere] b
LEFT JOIN OS2mo_ActualState.[DBuser].LedereMedNiveau_UnikTilHøjesteRangering l /* Lederrolle */
ON b.uuid = l.[Bruger UUID]
INNER JOIN OS2mo_ActualState.[DBuser].engagementer e /* Brugerens Engagementer */
ON b.uuid = e.bruger_uuid
INNER JOIN [DBName].[DBuser].[enheder] u /* Engagementets tilknyttede enhed */
ON e.enhed_uuid = u.uuid
LEFT JOIN [DBName].[DBuser].Brugere_Primær_AD_Email a1 /* Brugerens e-mail adresse */
ON b.uuid = a1.Bruger_UUID
LEFT JOIN [DBName].[DBuser].[adresser] a3 /* Brugerens tlf. */
ON b.uuid = a3.bruger_uuid AND a3.adressetype_uuid='3dda78a5-f953-5498-04d6-5a23aeed0792' AND a3.synlighed_uuid='12fd2a30-2bb6-4d81-4a8e-af2e2e2a0bdc'
LEFT JOIN [DBName].[DBuser].[adresser] a5 /* Brugerens offentlige tlf. */
ON b.uuid = a5.bruger_uuid AND a5.adressetype_uuid='3dda78a5-f953-5498-04d6-5a23aeed0792' AND a5.synlighed_uuid='aad0b1a0-e658-0aac-0a52-368bc5ec5b80'
LEFT JOIN [DBName].[DBuser].[adresser] a4
ON b.uuid = a4.bruger_uuid AND a4.adressetype_titel='Mobiltelefon'
LEFT JOIN [DBName].[DBuser].Engagementer_Nærmesteleder e2 /* Engagementets nærmeste leder */
ON e.uuid = e2.[Engagement UUID]

WHERE
(
     (e.engagementstype_titel='Medarbejder (månedsløn)')
    OR
    (e.engagementstype_titel='Medarbejder (timeløn)')
)
    AND
    u.organisatorisk_sti LIKE 'Viborg Kommune%' /* Inkluderer ansatte */

ORDER BY uuid, e.primær_boolean DESC

