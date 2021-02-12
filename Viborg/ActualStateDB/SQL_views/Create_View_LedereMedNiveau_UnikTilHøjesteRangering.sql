/* 
Dette view forudsætter et andet view: "LedereMedNiveau"
View, som indeholder ALLE ledere i organisationen, men som KUN medtager hver enkelt leder én gang. Hvis en leder har flere lederroller
f.eks. Chef og Leder på forskellige enheder, så vil personen således kun optræde én gang i dette view med Lederniveau="Chef", da denne rangerer højere end "Leder"
*/

CREATE VIEW LedereMedNiveau_UnikTilHøjesteRangering AS 
WITH LederePartitionRanked AS ( /* definerer midlertidig tabel til brug i denne query */
    SELECT DISTINCT
        [Bruger UUID]
        ,Fornavn
        ,Efternavn
        ,Niveautype
        ,Lederniveau        
        ,RANK() OVER (
                PARTITION BY ([Bruger UUID]) /* Vi partitionerer listen pr. bruger UUID, så vi kan operere pr. person som evt. har flere lederroller */
                ORDER BY Lederniveau) bruger_ranks /* Vi rangerer personens lederroller efter Lederniveau (hvis man har en Lederrolle med niveautypen 'Leder' bliver det til 1. Hvis man både er Chef og Leder, bliver chef rækken til 1 og leder rækken til 2 ) */

    FROM [DBname].[DBuser].LedereMedNiveau
)

SELECT *
FROM LederePartitionRanked 
WHERE bruger_ranks =1 /* Vi filtrerer, så kun rækken med den højst rangerede lederrolle pr. leder bliver medtaget */