
DELIMITER $$


CREATE TABLE IF NOT EXISTS journal_action (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    table_cible VARCHAR(40)     NOT NULL,
    operation   VARCHAR(10)     NOT NULL,
    cle         VARCHAR(40)     NOT NULL,
    auteur      VARCHAR(100)    NOT NULL,
    horodatage  DATETIME        NOT NULL,
    details     VARCHAR(255)            NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB $$



CREATE TRIGGER trg_emprunt_before_insert
BEFORE INSERT ON emprunt
FOR EACH ROW
BEGIN
    IF NEW.date_emprunt IS NULL THEN
        SET NEW.date_emprunt = CURDATE();
    END IF;

    IF NEW.date_retour_prevue IS NULL THEN
        SET NEW.date_retour_prevue = DATE_ADD(NEW.date_emprunt, INTERVAL 14 DAY);
    END IF;

    IF NEW.date_retour_prevue < NEW.date_emprunt THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'La date de retour prévue ne peut pas être antérieure à la date d''emprunt.';
    END IF;
END $$



CREATE TRIGGER trg_emprunt_after_insert
AFTER INSERT ON emprunt
FOR EACH ROW
BEGIN
    UPDATE exemplaire 
       SET disponible = 0 
     WHERE id = NEW.exemplaire_id;

    INSERT INTO journal_action (table_cible, operation, cle, auteur, horodatage, details)
    VALUES (
        'emprunt', 
        'INSERT', 
        CAST(NEW.id AS CHAR), 
        USER(), 
        NOW(), 
        CONCAT('Création de l''emprunt ID ', NEW.id, ' pour l''exemplaire ID ', NEW.exemplaire_id)
    );
END $$



CREATE TRIGGER trg_emprunt_after_update
AFTER UPDATE ON emprunt
FOR EACH ROW
BEGIN
    IF OLD.date_retour_reelle IS NULL AND NEW.date_retour_reelle IS NOT NULL THEN
        
        UPDATE exemplaire 
           SET disponible = 1 
         WHERE id = NEW.exemplaire_id;

        INSERT INTO journal_action (table_cible, operation, cle, auteur, horodatage, details)
        VALUES (
            'emprunt', 
            'UPDATE', 
            CAST(NEW.id AS CHAR), 
            USER(), 
            NOW(), 
            CONCAT('Restitution de l''exemplaire ID ', NEW.exemplaire_id)
        );
        
    END IF;
END $$

DELIMITER ;