/*
Denne query fremsøger:

1. Lederregistreringer af typen: "Personale: MUS-kompetence og omsorgs-/sygesamtaler", hvor:
- den tilknyttede person har ikke et aktivt engagement
- det primære engagementet er ikke af typen: "Medarbejder (månedsløn)"
- personens primære engagement stopper inden for de næste 21 dage
- rollen gælder for en udgået enhed
- samme person også er leder af den tilknyttede enheds forældreenhed (Kommunaldirektøren er undtaget, da han skal stå på "Kommunaldirektørens område" af hensyn til musskema)
- attributten "ledertype" er tom eller forkert udfyldt
- attributten "lederniveau" er ikke udfyldt
- flere registreringer gælder for samme enhed (der må kun være én leder pr. enhed)

2. Engagementer hvor:
- stillingskoden er 1030,1035,1040 UDEN personen samtidig har en lederrolle i OS2mo

Resultatet giver en række pr. "problematiske" lederrolle/Engagement (ikke nedarvet)
*/

/* VARIABLER */
DECLARE @DaysAhead INT, @responsibility_class VARCHAR(36), @OS2moServerDomain VARCHAR(50), @rootunit VARCHAR(36), @manager_type VARCHAR(250), @Engagementstype_titel VARCHAR(250)
SET @DaysAhead = 21; /* Hvor mange dage kikker vi frem i StopDato for Engagementet? - bruges til advarsel når en leders ansættelse er på vej til at udløbe */
SET @responsibility_class = '2681e6f4-0fd3-7903-c176-1dde9505b15f'; /* UUID på den 'responsibility' klasse (lederansvar) som vi kigger efter */
SET @OS2moServerDomain = 'os2mo.viborg.dk'; /* Domænenavn på OS2mo server */
SET @rootunit = '4f79e266-4080-4300-a800-000006180002'; /* uuid på rod enheden i den adm. organisation */
SET @manager_type = 'ebe615de-8e5a-6fe5-5cac-04daaf153a1b'; /* uuid på den 'manager_type' klasse (ledertype) som skal anvendes på lederregistreringer */
SET @Engagementstype_titel = 'Medarbejder (månedsløn)'; /* Titel på den Engagementstype, som ledere i organisationen skal have på deres primære ansættelse */

/* CTE query, som finder enheder med flere ledere (der bør kun være én pr. enhed). Anvendes til 3. UNION ALL */
WITH cte_flere_ledere AS (
SELECT 
l.enhed_uuid
,COUNT(*) occurrences

FROM [DBname].[DBuser].ledere l /* Alle ledere i OS2mo */

RIGHT JOIN [DBname].[DBuser].leder_ansvar la /* Lederansvarsroller */
ON l.uuid = la.leder_uuid AND la.lederansvar_uuid = @responsibility_class /* Frafiltrerer lederroller som IKKE er "Personale: MUS-kompetence og omsorgs-/sygesamtaler" */

GROUP BY
    l.enhed_uuid
HAVING
    COUNT(*) > 1
)
/* SLUT CTE query*/

/* MAIN QUERY */
SELECT 
    '<!--' + Concat(b.fornavn,' ',b.efternavn) + '--><a href=https://' + @OS2moServerDomain + '/medarbejder/' + b.uuid + '>' +  Concat(b.fornavn,' ',b.efternavn) + '</a>' AS 'Navn'
    ,'<a href=https://' + @OS2moServerDomain + '/organisation/' + u.uuid +'#ledere>\..\' + pu.navn + '\' + u.navn  + '</a>' AS 'Leder for enheden'
    ,e.bvn AS 'Tj.nr'
    ,e.slutdato AS 'Slutdato'
    ,CASE 
        WHEN (e.bvn IS NULL OR e.bvn = '') THEN 'Personen har ikke et aktivt Engagement'
        WHEN (e.engagementstype_titel <> @Engagementstype_titel) THEN 'Det primære Engagement er ikke af typen' + @Engagementstype_titel
        WHEN CONVERT(datetime,LEFT(e.slutdato,4)+SUBSTRING(e.slutdato,6,2)+RIGHT(e.slutdato,2)) < GETDATE() + @DaysAhead THEN 'Ansættelse ændres om ' + CONVERT(varchar(3),DATEDIFF(day,CONVERT(datetime,LEFT(e.slutdato,4)+SUBSTRING(e.slutdato,6,2)+RIGHT(e.slutdato,2)), GETDATE())*-1) + ' dage. Skal vi registrere en anden leder på enheden?'
        WHEN u.organisatorisk_sti like 'Udgåed%' THEN 'Udgået enhed. Lederregistrering bør fjernes!'
        WHEN (lp.uuid IS NOT NULL AND lp.enhed_uuid <> @rootunit) THEN 'Personen også leder af forældreenheden. Lederrolle bør fjernes fra denne enhed.'
        WHEN (l.ledertype_uuid IS NULL OR l.ledertype_uuid <> @manager_type) THEN 'Ledertype er tom eller har forkert værdi'
        WHEN (l.niveautype_uuid IS NULL OR l.niveautype_uuid = '') THEN 'Lederniveau er ikke udfyldt'
        ELSE 'Fejl - denne er utilsigtet med på denne liste'
    END AS 'Problem/årsag'

    FROM [DBname].[DBuser].ledere l /* Alle ledere i OS2mo */

    RIGHT JOIN [DBname].[DBuser].leder_ansvar la /* Lederansvarsroller */
    ON l.uuid = la.leder_uuid AND la.lederansvar_uuid = @responsibility_class /* Frafiltrerer lederroller som IKKE er "Personale: MUS-kompetence og omsorgs-/sygesamtaler" */

    LEFT JOIN [DBname].[DBuser].brugere b 
    ON l.bruger_uuid = b.uuid

    LEFT JOIN [DBname].[DBuser].enheder u 
    ON l.enhed_uuid = u.uuid

    LEFT JOIN [DBname].[DBuser].enheder pu /* Forældreenheden */
    ON u.forældreenhed_uuid = pu.uuid

    LEFT JOIN [DBname].[DBuser].ledere lp /* Forældreenhedens leder */
    ON u.forældreenhed_uuid = lp.enhed_uuid AND lp.bruger_uuid = l.bruger_uuid

    LEFT JOIN [DBname].[DBuser].engagementer e 
    ON l.bruger_uuid = e.bruger_uuid AND e.primær_boolean = 1

    WHERE 
    /* Lederen har IKKE længere et aktivt Engagement ELLER det aktive Engagement er ikke af typen "Medarbejder (månedsløn)" */
    (e.bvn IS NULL OR e.bvn = '' OR e.engagementstype_titel <> @Engagementstype_titel)
    
    /* Hvis det primære Engagement stopper inden for de næste x dage */
    OR CONVERT(datetime,LEFT(e.slutdato,4)+SUBSTRING(e.slutdato,6,2)+RIGHT(e.slutdato,2)) < GETDATE() + @DaysAhead 
    
    /* Lederrolen gælder for en udgået enhed */
    OR u.organisatorisk_sti like 'Udgåed%'
    
    /* Lederen er også leder af "forældreenheden, og bør derfor fjernes fra denne enhed" - undtagen Kommunaldirektør da han skal stå på "Kommunaldirektørens område" afhensyn til LUS i musskema */
    OR (lp.uuid IS NOT NULL AND lp.enhed_uuid <> @rootunit)

    /* Lederregistrringen er IKKE korrekt udfyldt med attributten "Ledertype"*/
    OR (l.ledertype_uuid IS NULL OR l.ledertype_uuid <> @manager_type)

    /* Lederregistrringen er IKKE korrekt udfyldt - mangler en værdi i attributten "Niveautype" (Lederniveau) */
    OR (l.niveautype_uuid IS NULL OR l.niveautype_uuid = '')

UNION ALL

/* Finder personer med en ansættelse i SD, som har en stillingskode som leder, uden lederen er tilknyttet en lederrolle i OS2mo */
SELECT 
    '<!--' + Concat(b.fornavn,' ',b.efternavn) + '--><a href=https://' + @OS2moServerDomain + '/medarbejder/' + b.uuid + '>' +  Concat(b.fornavn,' ',b.efternavn) + '</a>' AS 'Navn'
    ,NULL AS 'Leder for enheden'
    ,e.bvn AS 'Tj.nr'
    ,e.slutdato AS 'Slutdato'
    ,'Stillingskode: ' + k.bvn + ' ' + k.titel + ' - men ingen lederrolle i OS2mo' AS 'Problem/årsag'

    FROM [DBname].[DBuser].[engagementer] e 

    LEFT JOIN [DBname].[DBuser].ledere l 
    ON e.bruger_uuid = l.bruger_uuid

    LEFT JOIN [DBname].[DBuser].brugere b 
    ON e.bruger_uuid = b.uuid

    LEFT JOIN [DBname].[DBuser].klasser k 
    ON e.stillingsbetegnelse_uuid = k.uuid
    
    WHERE 
    (e.stillingsbetegnelse_titel ='Direktør' OR e.stillingsbetegnelse_titel = 'Chef' OR e.stillingsbetegnelse_titel = 'Leder')
    AND
    l.bruger_uuid IS NULL

UNION ALL

/* Finder enheder med flere ledere (der bør kun være én pr. enhed) */

SELECT 
    '<!--' + Concat(b.fornavn,' ',b.efternavn) + '--><a href=https://' + @OS2moServerDomain + '/medarbejder/' + b.uuid + '>' +  Concat(b.fornavn,' ',b.efternavn) + '</a>' AS 'Navn'
    ,'<a href=https://' + @OS2moServerDomain + '/organisation/' + u.uuid +'#ledere>\..\' + pu.navn + '\' + u.navn  + '</a>' AS 'Leder for enheden'
    ,e.bvn AS 'Tj.nr'
    ,e.slutdato AS 'Slutdato'
    ,'Flere ledere på samme enhed' AS 'Problem/årsag'

    FROM [DBname].[DBuser].ledere l /* Alle ledere i OS2mo */

    RIGHT JOIN [DBname].[DBuser].leder_ansvar la /* Lederansvarsroller */
    ON l.uuid = la.leder_uuid AND la.lederansvar_uuid = @responsibility_class /* Frafiltrerer lederroller som IKKE er "Personale: MUS-kompetence og omsorgs-/sygesamtaler" */

    LEFT JOIN [DBname].[DBuser].brugere b 
    ON l.bruger_uuid = b.uuid

    LEFT JOIN [DBname].[DBuser].enheder u 
    ON l.enhed_uuid = u.uuid

    LEFT JOIN [DBname].[DBuser].enheder pu /* Forældreenheden */
    ON u.forældreenhed_uuid = pu.uuid

    LEFT JOIN [DBname].[DBuser].engagementer e 
    ON l.bruger_uuid = e.bruger_uuid AND e.primær_boolean = 1
    
    INNER JOIN cte_flere_ledere ON
    cte_flere_ledere.enhed_uuid = l.enhed_uuid

ORDER BY [Problem/årsag],[navn]
  