-- R1 : les emprunts d'une journée
EXPLAIN SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';

-- R2 : les emprunts en cours
EXPLAIN SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;

-- R3 : l'historique récent d'un adhérent
EXPLAIN SELECT id, date_emprunt FROM emprunt WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';


# 2. Lignes réellement renvoyées
SELECT COUNT(*) FROM emprunt WHERE date_emprunt = '2024-03-12';
SELECT COUNT(*) FROM emprunt WHERE date_retour_reelle IS NULL;
SELECT COUNT(*) FROM emprunt WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';


# 3. Création des index 
CREATE INDEX idx_emprunt_date ON emprunt (date_emprunt);
CREATE INDEX idx_emprunt_retour ON emprunt (date_retour_reelle);
CREATE INDEX idx_emprunt_adh_date ON emprunt (adherent_id, date_emprunt);


# 4. Mesures après index
EXPLAIN SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';
EXPLAIN SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;
EXPLAIN SELECT id, date_emprunt FROM emprunt WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';


# 5. Test du préfixe gauche 
EXPLAIN SELECT * FROM emprunt WHERE adherent_id = 12;
EXPLAIN SELECT * FROM emprunt IGNORE INDEX (idx_emprunt_date) WHERE date_emprunt >= '2025-01-01';


# 6. Test de l'index couvrant 
-- Requête avec index couvrant (colonnes id et date_emprunt présentes dans l'index composite)
EXPLAIN SELECT id, date_emprunt FROM emprunt WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';
-- Requête sans index couvrant (SELECT *)
EXPLAIN SELECT * FROM emprunt WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';


# 7. Requête réécrite pour l'index sur date 
-- Version d'origine 
EXPLAIN SELECT COUNT(*) FROM emprunt WHERE YEAR(date_emprunt) = 2024;
SELECT COUNT(*) FROM emprunt WHERE YEAR(date_emprunt) = 2024;

-- Version réécrite 
EXPLAIN SELECT COUNT(*) FROM emprunt WHERE date_emprunt >= '2024-01-01' AND date_emprunt < '2025-01-01';
SELECT COUNT(*) FROM emprunt WHERE date_emprunt >= '2024-01-01' AND date_emprunt < '2025-01-01';