/* VIEW = Brugere_Primær_AD_Email
Dette view har til formål at indeholde forretningsreglen for hvilken AD konto og E-mail der er den primære for brugere, som har flere AD konti (i forskellige AD'er)
Resultatet findes i kolonnerne "Primær_AD_Brugernavn" og "Primær_Email"
Hvis en bruger KUN har en værdi for en attribut fra ét AD returneres værdien fra det pågældende AD. Hvis en bruger har en konto begge steder returneres værdien fra Adm. AD

CREATE VIEW Brugere_Primær_AD_Email AS
*/

SELECT
    b.[uuid] AS 'Bruger_UUID'
    ,CONCAT(b.fornavn,' ',b.efternavn) AS Bruger
    ,AdmAD.brugernavn AS 'Adm_AD_Brugernavn'
    ,SkoleAD.brugernavn AS 'Skole_AD_Brugernavn'
    ,SCAD.brugernavn AS 'SC_AD_Brugernavn'
    ,CASE 
        WHEN AdmAD.brugernavn IS NOT NULL THEN admad.brugernavn
        WHEN SkoleAD.brugernavn IS NOT NULL THEN SkoleAD.brugernavn
        WHEN SCAD.brugernavn IS NOT NULL THEN SCAD.brugernavn
        ELSE NULL
    END AS 'Primær_AD_Brugernavn'
    ,AdmADEmail.værdi AS 'Adm_AD_Email'
    ,SCViborgEmail.værdi AS 'SC_AD_Email'
    ,SkoleEmail.værdi AS 'Skole_AD_Email'
    ,CASE 
        WHEN AdmADEmail.værdi IS NOT NULL then AdmADEmail.værdi
        WHEN SkoleEmail.værdi IS NOT NULL then SkoleEmail.værdi
        WHEN SCViborgEmail.værdi IS NOT NULL then SCViborgEmail.værdi
        ELSE NULL
    END AS 'Primær_EMail'

  FROM [DBname].[DBuser].[brugere] b

  LEFT JOIN DBname.[DBuser].it_forbindelser AdmAD /* Administrativ AD it-konto */
  ON b.uuid = AdmAD.bruger_uuid AND AdmAD.it_system_uuid='b3ba9dfa-bb96-421a-8474-5ccd5ad84ce1'

  LEFT JOIN DBname.[DBuser].it_forbindelser SkoleAD /* Skole AD it-konto */
  ON b.uuid = SkoleAD.bruger_uuid AND SkoleAD.it_system_uuid='b0c27020-9a7a-11ea-8b83-0bb60cd4e329'

  LEFT JOIN DBname.[DBuser].it_forbindelser SCAD /* Sprogcenter AD it-konto */
  ON b.uuid = SCAD.bruger_uuid AND SCAD.it_system_uuid='28d7c076-d6df-4053-875c-048a5766e4d3'

  LEFT JOIN DBname.[DBuser].adresser AdmADEmail /* Administrativ AD E-mail */
  ON b.uuid = AdmADEmail.bruger_uuid AND AdmADEmail.adressetype_uuid='fa865555-58b5-327d-e7dc-2990b0d28ff9'

  LEFT JOIN DBname.[DBuser].adresser SkoleEmail /* Skole AD E-mail */
  ON b.uuid = SkoleEmail.bruger_uuid AND SkoleEmail.adressetype_uuid='9e01e5f2-9a7e-11ea-adc6-87cbe08a5ca1'

  LEFT JOIN DBname.[DBuser].adresser SCViborgEmail /* Sprogcenter AD E-mail */
  ON b.uuid = SCViborgEmail.bruger_uuid AND SCViborgEmail.adressetype_uuid='773e4f8b-ed9f-403d-ba67-219cff7d937e'

