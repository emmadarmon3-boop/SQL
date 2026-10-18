DELIMITER $$

CREATE PROCEDURE p_emprunter(
    IN p_code_barre VARCHAR(20),
    IN p_adherent_id INT UNSIGNED,
    OUT p_emprunt_id INT UNSIGNED
)
BEGIN
    DECLARE v_exemplaire_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_disponible TINYINT(1) DEFAULT NULL;
    DECLARE v_etat ENUM('neuf','bon','use','hors_service') DEFAULT NULL;

    DECLARE v_adherent_id_verif INT UNSIGNED DEFAULT NULL;
    DECLARE v_adherent_actif TINYINT(1) DEFAULT NULL;

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

    IF v_adherent_actif = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'L''inscription de cet adhérent n''est pas active.';
    END IF;

    SELECT id, disponible, etat 
      INTO v_exemplaire_id, v_disponible, v_etat
      FROM exemplaire
     WHERE code_barre = p_code_barre;

    IF v_exemplaire_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ce code-barres d''exemplaire est inconnu.';
    END IF;

    IF v_disponible = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cet exemplaire n''est pas disponible.';
    END IF;

    IF v_etat = 'hors_service' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cet exemplaire est hors service.';
    END IF;

=    IF f_nb_emprunts_en_cours(p_adherent_id) >= 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'L''adhérent a atteint le maximum de 5 emprunts en cours.';
    END IF;

    IF f_penalites_dues(p_adherent_id) > 10.00 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'L''adhérent dépasse la limite de 10 € de pénalités impayées.';
    END IF;

    INSERT INTO emprunt (adherent_id, exemplaire_id, date_emprunt, date_retour_prevue)
    VALUES (p_adherent_id, v_exemplaire_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 14 DAY));

    SET p_emprunt_id = LAST_INSERT_ID();

    COMMIT;
END $$



CREATE PROCEDURE p_rendre(
    IN p_code_barre VARCHAR(20)
)
BEGIN
    DECLARE v_emprunt_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_adherent_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_jours_retard INT DEFAULT 0;
    DECLARE v_montant_facture DECIMAL(6,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT e.id, e.adherent_id 
      INTO v_emprunt_id, v_adherent_id
      FROM emprunt e
      JOIN exemplaire ex ON e.exemplaire_id = ex.id
     WHERE ex.code_barre = p_code_barre
       AND e.date_retour_reelle IS NULL
     LIMIT 1;

    IF v_emprunt_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Aucun emprunt en cours trouvé pour ce code-barres.';
    END IF;

    UPDATE emprunt
       SET date_retour_reelle = CURDATE()
     WHERE id = v_emprunt_id;

    SET v_jours_retard = f_jours_de_retard(v_emprunt_id);

    IF v_jours_retard > 0 THEN
        SET v_montant_facture = v_jours_retard * 0.20;
        
        INSERT INTO penalite (adherent_id, emprunt_id, montant, motif, date_creation, payee)
        VALUES (v_adherent_id, v_emprunt_id, v_montant_facture, 'Retard de restitution', CURDATE(), 0);
    END IF;

    COMMIT;

    SELECT 
        v_emprunt_id AS emprunt_id,
        v_jours_retard AS jours_de_retard,
        v_montant_facture AS montant_facture;
END $$



CREATE PROCEDURE p_bilan_adherent(
    IN p_adherent_id INT UNSIGNED
)
BEGIN
    DECLARE v_adherent_existe INT UNSIGNED DEFAULT NULL;

    SELECT id INTO v_adherent_existe
      FROM adherent
     WHERE id = p_adherent_id;

    IF v_adherent_existe IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Cet adhérent n''existe pas.';
    END IF;

    SELECT 
        a.id,
        a.nom,
        a.prenom,
        a.email,
        a.telephone,
        a.ville,
        a.actif,
        f_nb_emprunts_en_cours(a.id) AS nb_emprunts_en_cours,
        f_penalites_dues(a.id) AS penalites_dues
      FROM adherent a
     WHERE a.id = p_adherent_id;

    SELECT 
        e.id AS emprunt_id,
        ex.code_barre,
        o.titre,
        e.date_emprunt,
        e.date_retour_prevue,
        f_jours_de_retard(e.id) AS jours_retard
      FROM emprunt e
      JOIN exemplaire ex ON e.exemplaire_id = ex.id
      JOIN ouvrage o ON ex.ouvrage_id = o.id
     WHERE e.adherent_id = p_adherent_id
       AND e.date_retour_reelle IS NULL;

    SELECT 
        COUNT(*) AS total_historique_emprunts
      FROM emprunt
     WHERE adherent_id = p_adherent_id;

END $$

DELIMITER ;