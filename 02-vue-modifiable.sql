USE mediatheque;
CREATE OR REPLACE VIEW mediatheque.v_adherent_lyon AS 
SELECT * FROM mediatheque.adherent
WHERE ville = 'Lyon'
WITH CHECK OPTION;


INSERT INTO mediatheque.v_adherent_lyon (nom, prenom, email, ville, date_inscription)
VALUES ('Duport', 'Mia', 'mia.duport@email.com', 'Lyon', CURRENT_DATE());

/*ERROR 1369 (HY000): CHECK OPTION failed 'mediatheque.v_adherent_lyon'
MySQL a bloqué l'insertion parce qu'on a tenté d'ajouter un adhérent dont la ville est 'Bron'
et non Lyon dans la vue v_adherent_lyon configurée avec WITH CHECk OPTION. Alors que toutes les lignes insérée via la vue doivent 
obligatoirement respecter le filtre WHERE ville = 'Lyon'
*/
INSERT INTO mediatheque.v_adherent_lyon (nom, prenom, email, ville, date_inscription)
VALUES('Marchand', 'Maya', 'maya.marchand@email.com', 'Bron', CURRENT_DATE()); 

/*ERROR 1288 (HY000): The target table v_catalogue of the UPDATE is not updatable
Une vue en SQL n'est pas toujours modifiable. Si la vue repose sur des jointures complexes, 
des fonctions d'agrégation ou des regroupements (ce qui est généralement le cas pour un catalogue de médiathèque qui lie des livres, des auteurs, des genres, etc.), 
MySQL la considère comme "non actualisable" (not updatable) pour protéger l'intégrité des données.
*/
UPDATE v_catalogue
SET titre ='Made in China'
WHERE id = 1;

/*
+--------------------+--------------+
| TABLE_NAME         | IS_UPDATABLE |
+--------------------+--------------+
| v_catalogue        | NO           |
| v_adherent_public  | YES          |
| v_adherent_lyon    | YES          |
| v_emprunt_en_cours | YES          |
| v_retard           | YES          |
+--------------------+--------------+

**v_catalogue est not updatable pour ces 3 raisons:

La présence de fonctions d'agrégation (COUNT et SUM) : MySQL ne peut pas savoir comment répartir ou modifier les données d'une table d'origine lorsqu'on essaie de modifier une valeur calculée ou totale.

L'utilisation de la clause GROUP BY : Une ligne de la vue v_catalogue regroupe plusieurs enregistrements (via les exemplaires et les catégories). Modifier une telle vue créerait une ambiguïté insurmontable sur la ligne exacte à modifier dans la table de base.

Les jointures multiples (JOIN / LEFT JOIN) : Combinées aux regroupements et aux fonctions de comptage, elles empêchent le SGBD d'assurer une correspondance univoque et sécurisée pour un UPDATE ou un INSERT.
*/

