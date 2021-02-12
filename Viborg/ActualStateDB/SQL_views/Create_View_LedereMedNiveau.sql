/*
View med alle ledere, som inkluderer en beregnet kolonne 'Lederniveau', som er en rangering af vores niveautyper
Eksempelvis er Direktør=1 og Chef=2
View'et bruges som fundament for view med navnet: "LedereMedNiveau_UnikTilHøjesteRangering"
*/

CREATE VIEW LedereMedNiveau AS
    SELECT 

        l1.uuid AS 'Leder UUID'
        ,b1.uuid AS 'Bruger UUID'
        ,b1.fornavn AS 'Fornavn'
        ,b1.efternavn AS 'Efternavn'
        ,l1.niveautype_titel AS 'Niveautype'
        ,CASE
            WHEN l1.niveautype_titel ='Direktør' THEN '1'
            WHEN l1.niveautype_titel ='Chef' THEN '2'
            WHEN l1.niveautype_titel ='Leder' THEN '3'
        END AS 'Lederniveau'
    FROM [DBname].[DBuser].[brugere] b1

    RIGHT JOIN [DBname].[DBuser].[ledere] l1
    ON b1.uuid = l1.bruger_uuid