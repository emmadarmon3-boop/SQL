DELIMITER $$

CREATE PROCEDURE p_emprunter(
    IN p_code_barre VARCHAR(50),
    IN p_adherent_id INT UNSIGNED,
    OUT p_emprunt_id INT UNSIGNED
)
BEGIN
    DECLARE v_exemplaire_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_disponible BOOLEAN DEFAULT NULL;
    DECLARE v_hors_service BOOLEAN DEFAULT NULL;

    DECLARE v_adherent_id_verif INT UNSIGNED DEFAULT NULL;
    DECLARE v_adherent_actif BOOLEAN DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    
    SELECT id, actif 
      INTO v_adherent_id_verif, v_adherent_actif
      FROM adherent
     WHERE id = p_adherent_id;

    IF v_adherent_id_verif IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cet adhérent n''existe pas.';
    END IF;

    IF v_adherent_actif = 0 OR v_adherent_actif = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'L''inscription de cet adhérent n''est pas active.';
    END IF;

   
    SELECT id, disponible, hors_service 
      INTO v_exemplaire_id, v_disponible, v_hors_service
      FROM exemplaire
     WHERE code_barre = p_code_barre;

    IF v_exemplaire_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ce code-barres d''exemplaire est inconnu.';
    END IF;

    IF v_disponible = 0 OR v_disponible = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cet exemplaire n''est pas disponible.';
    END IF;

    IF v_hors_service = 1 OR v_hors_service = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cet exemplaire est hors service.';
    END IF;

    
    IF f_nb_emprunts_en_cours(p_adherent_id) >= 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'L''adhérent a atteint le maximum de 5 emprunts en cours.';
    END IF;

   
    IF f_penalites_dues(p_adherent_id) > 10.00 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'L''adhérent dépasse la limite de 10 € de pénalités impayées.';
    END IF;

    
    INSERT INTO emprunt (adherent_id, exemplaire_id, date_emprunt)
    VALUES (p_adherent_id, v_exemplaire_id, CURDATE());

    SET p_emprunt_id = LAST_INSERT_ID();

    COMMIT;
END $$

DELIMITER ;