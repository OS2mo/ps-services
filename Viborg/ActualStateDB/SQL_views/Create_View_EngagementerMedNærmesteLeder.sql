/*
Dette view anvendes i forbindelse med udtræk, hvor det ønskes at koble en medarbejder med nærmeste leder. 
I dette view findes nærmeste leder pr. Engagement. En person kan ikke være leder for sig selv (Kommunaldirektøren/øverste leder undtaget)
Engagementer, hvor der ikke er en fungerende leder på hverken den tilknyttede enhed, forældreenheden eller bedsteforældreenheden er IKKE med i dette view.
*/

CREATE VIEW Engagementer_Nærmesteleder AS

SELECT
total.[Engagement UUID]
,total.[Tj.nr]
,total.Primær
,total.[Bruger UUID]
,CONCAT (b.fornavn, ' ', b.efternavn) AS 'Bruger'
,total.[Nærmeste leder UUID]
,CONCAT (l.fornavn, ' ', l.efternavn) AS 'Nærmeste leder'

FROM (
       /* Engagementer, hvor nærmeste leder hentes direkte fra tilknyttet enhed (personen er ikke selv leder for enheden) */
        SELECT
        e.uuid AS 'Engagement UUID'
        ,e.bvn AS 'Tj.nr'
        ,e.primær_boolean AS 'Primær'
        ,e.bruger_uuid AS 'Bruger UUID'
        ,l.bruger_uuid AS 'Nærmeste leder UUID'

        FROM DBname.[DBuser].engagementer e

        LEFT JOIN DBname.[DBuser].enheder u ON u.uuid = e.enhed_uuid
        LEFT JOIN DBname.[DBuser].ledere l ON u.fungerende_leder_uuid = l.uuid

        WHERE e.bruger_uuid != l.bruger_uuid

    UNION
        /* Engagementer, hvor nærmeste leder hentes fra parent enhed (lederes leder) */
        SELECT
        e.uuid AS 'Engagement UUID'
        ,e.bvn AS 'Tj.nr'
        ,e.primær_boolean AS 'Primær'
        ,e.bruger_uuid AS 'Bruger UUID'
        ,l2.bruger_uuid AS 'Nærmeste leder UUID'

        FROM DBname.[DBuser].engagementer e

        JOIN DBname.[DBuser].enheder u ON e.enhed_uuid = u.uuid /* Engagementets tilknyttede Enhed */
        JOIN DBname.[DBuser].ledere l ON u.fungerende_leder_uuid = l.uuid /* Engagementets tilknyttede Enheds lederobjekt */
        JOIN DBname.[DBuser].enheder u2 ON u.forældreenhed_uuid = u2.uuid /* Engagementets tilknyttede Enheds forældreenhed */
        JOIN DBname.[DBuser].ledere l2 ON u2.fungerende_leder_uuid = l2.uuid /* Engagementets tilknyttede Enheds forældreenheds lederobjekt */

        WHERE e.bruger_uuid = l.bruger_uuid /* Brugeren er selv leder på Enheden */
        AND 
        e.bruger_uuid != l2.bruger_uuid /* Brugeren er IKKE leder på forældreenheden */

    UNION 
        /* Engagementer, hvor nærmeste leder hentes fra bedsteforældreenhed (personen er selv leder for forældreenhed, så vi skal et niveau højere op) */
        SELECT
        e.uuid AS 'Engagement UUID'
        ,e.bvn AS 'Tj.nr'
        ,e.primær_boolean AS 'Primær'
        ,e.bruger_uuid AS 'Bruger UUID'
        ,l3.bruger_uuid AS 'Nærmeste leder UUID'

        FROM DBname.[DBuser].engagementer e

        JOIN DBname.[DBuser].enheder u ON e.enhed_uuid = u.uuid /* Engagementets tilknyttede Enhed */
        JOIN DBname.[DBuser].ledere l ON u.fungerende_leder_uuid = l.uuid /* Engagementets tilknyttede Enheds lederobjekt */
        JOIN DBname.[DBuser].enheder u2 ON u.forældreenhed_uuid = u2.uuid /* Engagementets tilknyttede Enheds forældreenhed */
        JOIN DBname.[DBuser].ledere l2 ON u2.fungerende_leder_uuid = l2.uuid /* Engagementets tilknyttede Enheds forældreenheds lederobjekt */
        JOIN DBname.[DBuser].enheder u3 ON u2.forældreenhed_uuid = u3.uuid /* Engagementets tilknyttede Enheds bedsteforælderenhed */
        JOIN DBname.[DBuser].ledere l3 ON u3.fungerende_leder_uuid = l3.uuid /* Engagementets tilknyttede Enheds bedsteforælderenhed lederobjekt */
       
        WHERE e.bruger_uuid = l2.bruger_uuid /* Brugeren er leder på forældreenheden */

    UNION    
        /* Kommunaldirektøren's engagement (leder for sig selv) */
        SELECT
        e.uuid AS 'Engagement UUID'
        ,e.bvn AS 'Tj.nr'
        ,e.primær_boolean AS 'Primær'
        ,e.bruger_uuid AS 'Bruger UUID'
        ,l.bruger_uuid AS 'Nærmeste leder UUID'

        FROM DBname.[DBuser].engagementer e

        JOIN DBname.[DBuser].enheder u ON u.uuid = e.enhed_uuid
        JOIN DBname.[DBuser].ledere l ON u.fungerende_leder_uuid = l.uuid

        WHERE e.bruger_uuid = l.bruger_uuid AND u.forældreenhed_uuid is NULL

) total /* alias for output af parantesen */

LEFT JOIN DBname.[DBuser].brugere b ON b.uuid=total.[Bruger UUID]
LEFT JOIN DBname.[DBuser].brugere l ON l.uuid=total.[Nærmeste leder UUID]
