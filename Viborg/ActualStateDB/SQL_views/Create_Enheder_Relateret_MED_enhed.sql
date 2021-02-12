/*
View "Enheder_Relateret_MED_Enhed"
Dette view anvendes som fundament for view: "Enheder_Relateret_MED_Enhed_Nedarvning"


CREATE VIEW [Enheder_Relateret_MED_Enhed] AS 
*/
SELECT
    enheder.uuid AS 'UUID'
    ,enheder.forældreenhed_uuid
    ,enheder.navn AS 'Enhedsnavn'
    ,enheder.organisatorisk_sti

    /* Relateret MED-enhed 
    Der er ikke system i hvilken UUID der er står først (enhed1_uuid eller enhed2_uuid). Nogle gange står den adm. enhed i enhed1_uuid og andre gange i enhed2_uuid. */
    ,IIF(organisatorisk_sti LIKE 'Viborg Kommune%',
        CASE 
            WHEN enheder.uuid=es1.enhed1_uuid THEN es1.enhed2_uuid
            WHEN enheder.uuid=es2.enhed2_uuid THEN es2.enhed1_uuid
        ELSE 
            null 
        END
    ,NULL) AS 'Relateret_MED_enhed'
   

FROM [DBname].[DBuser].[enheder]

LEFT JOIN [DBname].[DBuser].enhedssammenkobling es1
ON enheder.uuid = es1.enhed1_uuid

LEFT JOIN [DBname].[DBuser].enhedssammenkobling es2
ON enheder.uuid = es2.enhed2_uuid

WHERE
NOT enhedsniveau_titel = 'Afdelings-niveau' 
AND 
NOT enhedsniveau_titel = 'NY1-niveau' 
AND organisatorisk_sti LIKE 'Viborg Kommune%'
