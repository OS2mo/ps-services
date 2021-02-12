/*
Dette view anvendes i forbindelse med udtræk, hvor det ønskes at koble en medarbejder med nærmeste leder. 
I dette view findes nærmeste leder pr. Engagement. En person kan ikke være leder for sig selv (Kommunaldirektøren/øverste leder undtaget)
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
        -- Engagementer, hvor nærmeste leder hentes fra parent enhed (lederes leder)
        SELECT
        e.uuid AS 'Engagement UUID'
        ,e.bvn AS 'Tj.nr'
        ,e.primær_boolean AS 'Primær'
        ,e.bruger_uuid AS 'Bruger UUID'
        ,l2.bruger_uuid AS 'Nærmeste leder UUID'

        FROM DBname.[DBuser].engagementer e

        JOIN DBname.[DBuser].enheder u ON u.uuid = e.enhed_uuid
        JOIN DBname.[DBuser].ledere l ON u.leder_uuid = l.uuid
        JOIN DBname.[DBuser].enheder u2 ON u2.uuid = u.forældreenhed_uuid
        JOIN DBname.[DBuser].ledere l2 ON u2.fungerende_leder_uuid = l2.uuid

        WHERE e.bruger_uuid = l.bruger_uuid

    UNION
        -- Engagementer, hvor nærmeste leder hentes fra enhed (medarbejderes leder)
        SELECT
        e.uuid AS 'Engagement UUID'
        ,e.bvn AS 'Tj.nr'
        ,e.primær_boolean AS 'Primær'
        ,e.bruger_uuid AS 'Bruger UUID'
        ,l.bruger_uuid AS 'Nærmeste leder UUID'

        FROM DBname.[DBuser].engagementer e

        JOIN DBname.[DBuser].enheder u ON u.uuid = e.enhed_uuid
        JOIN DBname.[DBuser].ledere l ON u.fungerende_leder_uuid = l.uuid

        WHERE e.bruger_uuid != l.bruger_uuid

    UNION
        -- Kommunaldirektøren's engagement (leder for sig selv)
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

) total -- alias for output af parantesen

LEFT JOIN DBname.[DBuser].brugere b ON b.uuid=total.[Bruger UUID]
LEFT JOIN DBname.[DBuser].brugere l ON l.uuid=total.[Nærmeste leder UUID]

ORDER BY total.[Nærmeste leder UUID]

