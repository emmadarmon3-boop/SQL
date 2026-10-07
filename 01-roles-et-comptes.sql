DROP USER IF EXISTS 
'app_media'@'localhost',
'biblio_marie'@'localhost',
'stagiaire'@'localhost',
'analyste'@'localhost';

DROP ROLE IF EXISTS role_catalogue, role_prets, role_adherents;

# Création rôles

CREATE ROLE 'role_catalogue', 'role_prets', 'role_adherents';

GRANT SELECT ON mediatheque.ouvrage TO role_catalogue;
GRANT SELECT ON mediatheque.exemplaire TO role_catalogue;
GRANT SELECT ON mediatheque.categorie TO role_catalogue;

GRANT SELECT, INSERT, UPDATE ON mediatheque.emprunt TO role_prets;
GRANT SELECT, INSERT, UPDATE ON mediatheque.reservation TO role_prets;
GRANT SELECT, INSERT, UPDATE ON mediatheque.penalite TO role_prets;
GRANT UPDATE (disponible) ON mediatheque.exemplaire TO role_prets;


GRANT SELECT, INSERT, UPDATE ON mediatheque.adherent TO role_adherents;

# Création comptes

CREATE USER 'app_media'@'localhost' IDENTIFIED BY 'AppMedia!2026';
CREATE USER 'biblio_marie'@'localhost' IDENTIFIED BY 'BiblioMarie!2026';
CREATE USER 'stagiaire'@'localhost' IDENTIFIED BY 'Stagiaire!2026';
CREATE USER 'analyste'@'localhost' IDENTIFIED BY 'Analyste!2026';

GRANT role_catalogue, role_prets TO 'app_media'@'localhost';
GRANT role_catalogue, role_prets, role_adherents TO 'biblio_marie'@'localhost';
GRANT role_catalogue TO 'stagiaire'@'localhost','analyste'@'localhost';

GRANT SELECT (id, nom, prenom, actif) ON mediatheque.adherent TO 'app_media'@'localhost';
GRANT SELECT (id, nom, prenom, ville, actif) ON mediatheque.adherent TO 'stagiaire'@'localhost';
GRANT SELECT ON mediatheque.emprunt TO 'analyste'@'localhost';


SET DEFAULT ROLE ALL TO 'app_media'@'localhost', 'biblio_marie'@'localhost', 'stagiaire'@'localhost', 'analyste'@'localhost'; 

SHOW GRANTS FOR 'app_media'@'localhost';
SHOW GRANTS FOR 'biblio_marie'@'localhost';
SHOW GRANTS FOR 'stagiaire'@'localhost';
SHOW GRANTS FOR 'analyste'@'localhost';

SELECT GRANTEE, TABLE_NAME, COLUMN_NAME, PRIVILEGE_TYPE
FROM information_schema.column_privileges
WHERE TABLE_SCHEMA = 'mediatheque'
ORDER BY GRANTEE, TABLE_NAME, COLUMN_NAME;

GRANT SELECT ON mediatheque.reservation TO 'analyste'@'localhost';
SHOW GRANTS FOR 'analyste'@'localhost';

REVOKE SELECT ON mediatheque.reservation FROM 'analyste'@'localhost';
SHOW GRANTS FOR 'analyste'@'localhost';





