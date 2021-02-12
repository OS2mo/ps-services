/*
View "Enheder_Relateret_MED_Enhed_Nedarvning"
Forudsætter view: "Enheder_Relateret_MED_Enhed"
Bruges til Vicki/intranet udtræk. Dette view viser relationen til MED-organisationen set fra den Adm. Organisastion (med nedarvning).
Dvs. for hver enhed i den administrative organisation returneres ALTID en uuid på en relateret enhed i MED-organisationen (Relateret_MED_enhed), så hvis der ikke 
er en relation til en MED-enhed på den pågældende administrative enhed søges op af i den adm. organisation indtil der findes en MED-enhedsrelation.
Dette view giver mulighed for at vi altid kan relatere en persons ansættelse med et relevant MED-udvalg.

CREATE VIEW [Enheder_Relateret_MED_Enhed_Nedarvning] AS
*/

WITH tree AS 
(
        SELECT UUID, Enhedsnavn, Forældreenhed_uuid, Relateret_MED_enhed
        FROM DBname.[DBuser].[Enheder_Relateret_MED_Enhed]
        WHERE Forældreenhed_uuid is NULL
    UNION ALL
        SELECT c.UUID, c.Enhedsnavn, c.Forældreenhed_uuid, coalesce(c.[Relateret_MED_enhed], p.[Relateret_MED_enhed])
        FROM DBname.[DBuser].[Enheder_Relateret_MED_Enhed] c 
        INNER JOIN tree p on p.UUID = c.Forældreenhed_uuid
)

SELECT DISTINCT * 
FROM tree