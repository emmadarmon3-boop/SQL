USE mediatheque;

-- 1. Vue Catalogue
CREATE OR REPLACE VIEW mediatheque.v_catalogue AS 
SELECT ou.id                                    AS ouvrage_id,
       ou.titre,
       ou.auteur,
       ou.annee_publication,
       ct.libelle                               AS categorie,
       COUNT(ex.id)                             AS nb_exemplaires,
       COALESCE(SUM(ex.disponible = 1), 0)       AS nb_disponibles
FROM ouvrage ou 
JOIN categorie ct ON ct.id = ou.categorie_id
LEFT JOIN exemplaire ex ON ex.ouvrage_id = ou.id 
GROUP BY ou.id, ou.titre, ou.auteur, ou.annee_publication, ct.libelle;

-- 2. Vue Adhérent Public
CREATE OR REPLACE VIEW mediatheque.v_adherent_public AS 
SELECT id,
       nom,
       prenom,
       ville,
       date_inscription,
       actif
FROM adherent;

-- 3. Vue Emprunt en Cours
CREATE OR REPLACE VIEW mediatheque.v_emprunt_en_cours AS 
SELECT em.id                                      AS emprunt_id,
       em.date_emprunt,
       em.date_retour_prevu,
       DATEDIFF(CURDATE(), em.date_retour_prevu)  AS jours_retard,   
       CONCAT(a.nom, ' ', a.prenom)               AS adherent,
       ou.titre,
       ex.code_barre
FROM emprunt em
JOIN adherent a ON a.id = em.adherent_id
JOIN exemplaire ex ON ex.id = em.exemplaire_id
JOIN ouvrage ou ON ou.id = ex.ouvrage_id
WHERE em.date_retour_reelle IS NULL;

-- 4. Vue Retard
CREATE OR REPLACE VIEW mediatheque.v_retard AS 
SELECT *
FROM v_emprunt_en_cours
WHERE jours_retard > 0;

-- 5. Tests
SELECT * FROM v_catalogue;
SELECT * FROM v_catalogue WHERE nb_exemplaires = 0;
SELECT * FROM v_adherent_public LIMIT 5;
SELECT * FROM v_emprunt_en_cours ORDER BY jours_retard DESC;
SELECT * FROM v_retard;

-- 6. Privilèges du Stagiaire
REVOKE SELECT ON mediatheque.adherent FROM 'stagiaire'@'localhost';
GRANT SELECT ON mediatheque.v_adherent_public  TO 'stagiaire'@'localhost';
GRANT SELECT ON mediatheque.v_catalogue        TO 'stagiaire'@'localhost';
GRANT SELECT ON mediatheque.v_emprunt_en_cours TO 'stagiaire'@'localhost';