/*
Ledere i Viborg Kommune
Forudsætter custom (ikke standard) view:
- Brugere_Primær_AD_Email

Udtrækket medtager ALLE ledere i Viborg Kommune inkl.  De enheder som de er leder af.
Ledere, som er leder for flere enheder (f.eks. Sidestillede enheder) vil optræde med en række pr. enhed de er leder for
Nedarvning af ledelse vises IKKE i dette udtræk. Der for er alle enheder i organisationen IKKE med i udtrækket
KUN ledere, som har en aktiv ansættelse er med i udtrækket
Vi medtager kun ledere, som er leder for en enhed i den Administrative organisation
*/

SELECT DISTINCT 
    b1.uuid AS 'Bruger UUID'
    ,b1.fornavn AS 'Fornavn'
    ,b1.efternavn AS 'Efternavn'
    ,l1.niveautype_titel AS 'Lederniveau'
    ,pm.Primær_EMail AS 'E-mail'
    ,e1.organisatorisk_sti AS 'Leder på enhed'
    
FROM [DBname].[DBuser].[brugere] b1

RIGHT JOIN [DBname].[DBuser].[ledere] l1
ON b1.uuid = l1.bruger_uuid

INNER JOIN [DBname].[DBuser].[engagementer]
ON b1.uuid = engagementer.bruger_uuid

LEFT JOIN [DBname].[DBuser].Brugere_Primær_AD_Email pm
ON b1.uuid = pm.Bruger_UUID

LEFT JOIN DBname.[DBuser].enheder e1
ON l1.enhed_uuid = e1.uuid

WHERE

engagementer.primær_boolean = '1'
AND
 ((engagementer.engagementstype_titel='Medarbejder (månedsløn)') OR (engagementer.engagementstype_titel='Medarbejder (timeløn)'))
AND
e1.organisatorisk_sti LIKE 'Viborg Kommune%' /* Medtager KUN adm. organisation */