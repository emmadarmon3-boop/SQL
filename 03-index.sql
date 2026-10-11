-- R1 : les emprunts d'une journée
EXPLAIN SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';

-- R2 : les emprunts en cours (c'est la requête derrière v_emprunt_en_cours)
EXPLAIN SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;

-- R3 : l'historique récent d'un adhérent
EXPLAIN SELECT id, date_emprunt FROM emprunt
 WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';