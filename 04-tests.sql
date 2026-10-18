-- =====================================================================
-- TP3 — 04-tests.sql : scénario de test (T1 à T9)
-- Les cas qui DOIVENT ÉCHOUER sont en commentaire, avec l'erreur
-- obtenue juste en dessous, pour que le script se rejoue en entier.
--
-- Prérequis : base fraîchement rechargée (01, 02, 03) le jour même,
-- car les dates du jeu de données sont relatives à CURDATE().
-- Les valeurs "attendu" ci-dessous correspondent à 02-donnees.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Sélection des cas de test (la base choisit les identifiants)
-- ---------------------------------------------------------------------

-- un exemplaire disponible                          -> attendu : MED-00001
SET @code = (SELECT code_barre FROM exemplaire
              WHERE disponible = 1 AND etat <> 'hors_service'
              ORDER BY id LIMIT 1);

-- un adhérent actif, sans emprunt et sans pénalité  -> attendu : 9
SET @adherent = (SELECT a.id FROM adherent a
                  WHERE a.actif = 1
                    AND f_nb_emprunts_en_cours(a.id) = 0
                    AND f_penalites_dues(a.id) = 0
                  ORDER BY a.id LIMIT 1);

-- un 2e adhérent "propre" (pour T2)                 -> attendu : 14
-- => T2 ne doit pouvoir échouer QUE parce que l'exemplaire est pris
SET @autre_adherent = (SELECT a.id FROM adherent a
                        WHERE a.actif = 1
                          AND a.id <> @adherent
                          AND f_nb_emprunts_en_cours(a.id) = 0
                          AND f_penalites_dues(a.id) = 0
                        ORDER BY a.id LIMIT 1);

-- un adhérent inactif (pour T3)                     -> attendu : 7
SET @inactif = (SELECT id FROM adherent WHERE actif = 0 ORDER BY id LIMIT 1);

-- un adhérent qui doit plus de 10 € (pour T6)       -> attendu : 5 (12 €)
SET @mauvais_payeur = (SELECT adherent_id FROM penalite
                        WHERE payee = 0
                        GROUP BY adherent_id
                       HAVING SUM(montant) > 10
                        ORDER BY adherent_id LIMIT 1);

-- un emprunt en retard (pour T8 et T9)              -> attendu : MED-00107
SET @code_retard = (SELECT ex.code_barre
                      FROM emprunt em
                      JOIN exemplaire ex ON ex.id = em.exemplaire_id
                     WHERE em.date_retour_reelle IS NULL
                       AND em.date_retour_prevue < CURDATE()
                     ORDER BY em.date_retour_prevue LIMIT 1);

-- contrôle : aucune variable ne doit être NULL
SELECT @code, @adherent, @autre_adherent, @inactif, @mauvais_payeur, @code_retard;


-- ---------------------------------------------------------------------
-- T1 — Emprunt nominal (MED-00001 par l'adhérent 9)
-- Attendu : emprunt créé (id 131), exemplaire indisponible,
--           une ligne dans journal_action
-- ---------------------------------------------------------------------
CALL p_emprunter(@code, @adherent, @id);

SELECT @id AS id_emprunt_cree;                                              -- attendu : 131
SELECT code_barre, disponible FROM exemplaire WHERE code_barre = @code;     -- attendu : 0
SELECT operation, cle, auteur, details FROM journal_action ORDER BY id DESC LIMIT 3;


-- ---------------------------------------------------------------------
-- T2 — Même exemplaire (MED-00001), adhérent 14 — DOIT ÉCHOUER
-- Attendu : exemplaire déjà emprunté
-- ---------------------------------------------------------------------
-- CALL p_emprunter(@code, @autre_adherent, @id);
-- Erreur obtenue : ERROR 1644 (45000): Cet exemplaire n'est pas disponible.


-- ---------------------------------------------------------------------
-- T3 — Adhérent inactif (7) sur MED-00003 — DOIT ÉCHOUER
-- Attendu : inscription inactive
-- ---------------------------------------------------------------------
SET @code_libre = (SELECT code_barre FROM exemplaire
                    WHERE disponible = 1 AND etat <> 'hors_service'
                    ORDER BY id LIMIT 1);
-- CALL p_emprunter(@code_libre, @inactif, @id);
-- Erreur obtenue : ERROR 1644 (45000): <coller le message exact>


-- ---------------------------------------------------------------------
-- T4 — Code-barres inconnu — DOIT ÉCHOUER
-- Attendu : code-barres inconnu
-- ---------------------------------------------------------------------
-- CALL p_emprunter('MED-99999', 1, @id);
-- Erreur obtenue : ERROR 1644 (45000): <coller le message exact>


-- ---------------------------------------------------------------------
-- T5 — Quota de 5 emprunts (adhérent 9, qui a déjà 1 emprunt depuis T1)
-- On ajoute 4 emprunts (MED-00003, 00005, 00007, 00008),
-- puis le 6e (MED-00010) doit échouer.
-- ---------------------------------------------------------------------
SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
CALL p_emprunter(@c, @adherent, @id);   -- 2e

SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
CALL p_emprunter(@c, @adherent, @id);   -- 3e

SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
CALL p_emprunter(@c, @adherent, @id);   -- 4e

SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
CALL p_emprunter(@c, @adherent, @id);   -- 5e

SELECT f_nb_emprunts_en_cours(@adherent) AS nb_emprunts;   -- attendu : 5

SET @c = (SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
-- CALL p_emprunter(@c, @adherent, @id);   -- 6e — DOIT ÉCHOUER
-- Erreur obtenue : ERROR 1644 (45000): L'adhérent a atteint le maximum de 5 emprunts en cours.


-- ---------------------------------------------------------------------
-- T6 — Adhérent 5 (12 € impayés) sur MED-00010 — DOIT ÉCHOUER
-- Attendu : pénalités impayées
-- ---------------------------------------------------------------------
SELECT f_penalites_dues(@mauvais_payeur) AS du;   -- attendu : 12.00
-- CALL p_emprunter(@c, @mauvais_payeur, @id);
-- Erreur obtenue : ERROR 1644 (45000): L'adhérent dépasse la limite de 10 € de pénalités impayées.


-- ---------------------------------------------------------------------
-- T7 — INSERT direct, SANS la procédure (MED-00010, adhérent 2)
-- Attendu : la ligne existe, date_emprunt = aujourd'hui,
--           retour prévu à +14 jours, exemplaire indisponible
-- => c'est le trigger qui fait le travail, pas la procédure.
-- Remarque : l'adhérent 2 a déjà un emprunt en retard (emprunt 123) ;
-- l'INSERT passe quand même, aucun contrôle de la procédure ne joue.
-- ---------------------------------------------------------------------
SET @ex_libre = (SELECT id FROM exemplaire
                  WHERE disponible = 1 AND etat <> 'hors_service'
                  ORDER BY id LIMIT 1);

INSERT INTO emprunt (exemplaire_id, adherent_id, date_emprunt, date_retour_prevue)
VALUES (@ex_libre, 2, NULL, NULL);

SELECT id, exemplaire_id, adherent_id, date_emprunt, date_retour_prevue,
       DATEDIFF(date_retour_prevue, date_emprunt) AS duree   -- attendu : 14
  FROM emprunt
 WHERE exemplaire_id = @ex_libre AND date_retour_reelle IS NULL;

SELECT id, code_barre, disponible FROM exemplaire WHERE id = @ex_libre;   -- attendu : 0

-- trace ? (si aucune ligne nouvelle : la journalisation est dans la procédure)
SELECT operation, cle, auteur, details FROM journal_action ORDER BY id DESC LIMIT 3;

-- Ce que T7 démontre :
--   • GARANTI par le trigger, quel que soit le chemin d'écriture :
--     date_emprunt = aujourd'hui, retour prévu à +14 jours,
--     exemplaire passé indisponible.
--   • PERDU sans la procédure : aucun contrôle métier (adhérent actif,
--     quota, pénalités, disponibilité). L'adhérent 2, déjà en retard,
--     a pu emprunter. La procédure seule n'aurait rien protégé ici :
--     seul le trigger s'exécute sur un INSERT direct.


-- ---------------------------------------------------------------------
-- T8 — Retour d'un emprunt en retard (MED-00107, adhérent 30, emprunt 130)
-- Attendu : emprunt clos, exemplaire disponible,
--           pénalité = 72 jours x 0,20 € = 14,40 €
-- ---------------------------------------------------------------------
SELECT ex.code_barre, em.id AS emprunt_id, em.adherent_id, em.date_retour_prevue,
       DATEDIFF(CURDATE(), em.date_retour_prevue) AS jours_retard   -- attendu : 72
  FROM emprunt em JOIN exemplaire ex ON ex.id = em.exemplaire_id
 WHERE ex.code_barre = @code_retard AND em.date_retour_reelle IS NULL;

CALL p_rendre(@code_retard);

SELECT code_barre, disponible FROM exemplaire WHERE code_barre = @code_retard;   -- attendu : 1
SELECT adherent_id, montant, motif FROM penalite ORDER BY id DESC LIMIT 1;       -- attendu : 30 | 14.40
SELECT operation, cle, auteur, details FROM journal_action ORDER BY id DESC LIMIT 3;


-- ---------------------------------------------------------------------
-- T9 — Rendre une deuxième fois MED-00107 — DOIT ÉCHOUER
-- Attendu : aucun emprunt en cours
-- ---------------------------------------------------------------------
-- CALL p_rendre(@code_retard);
-- Erreur obtenue : ERROR 1644 (45000): <coller le message exact>
