DELIMITER $$

CREATE FUNCTION f_nb_emprunts_en_cours(
    p_adherent_id INT UNSIGNED)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_nb INT;

    SELECT COUNT(*) INTO v_nb
      FROM emprunt
     WHERE adherent_id = p_adherent_id
       AND date_retour_reelle IS NULL;

    RETURN v_nb;
END $$

CREATE FUNCTION f_jours_de_retard(
    p_emprunt_id INT UNSIGNED)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_date_emprunt DATE;
    DECLARE v_date_retour_reelle DATE;
    DECLARE v_date_limite DATE;
    DECLARE v_date_reference DATE;
    DECLARE v_jours INT;

    SELECT date_emprunt, date_retour_reelle
      INTO v_date_emprunt, v_date_retour_reelle
      FROM emprunt
     WHERE id = p_emprunt_id;

    SET v_date_limite = DATE_ADD(v_date_emprunt, INTERVAL 14 DAY);
    
    SET v_date_reference = COALESCE(v_date_retour_reelle, CURDATE());
    
    SET v_jours = DATEDIFF(v_date_reference, v_date_limite);

    IF v_jours < 0 THEN
        RETURN 0;
    ELSE
        RETURN v_jours;
    END IF;
END $$

CREATE FUNCTION f_penalites_dues(
    p_adherent_id INT UNSIGNED)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10,2);

    SELECT COALESCE(SUM(f_jours_de_retard(id) * 0.20), 0.00)
      INTO v_total
      FROM emprunt
     WHERE adherent_id = p_adherent_id;

    RETURN v_total;
END $$

DELIMITER ;


SELECT 
    a.id,
    a.nom,
    a.prenom,
    f_nb_emprunts_en_cours(a.id) AS nb_emprunts_en_cours,
    f_penalites_dues(a.id) AS penalites_dues
FROM adherent a
WHERE f_nb_emprunts_en_cours(a.id) > 0;