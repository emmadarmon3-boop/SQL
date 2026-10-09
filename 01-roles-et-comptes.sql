DROP USER IF EXISTS 
'app_media'@'localhost',
'biblio_marie'@'localhost',
'stagiaire'@'localhost',
'analyste'@'localhost';

DROP ROLE IF EXISTS role_catalogue, role_prets, role_adherents;



CREATE ROLE 'role_catalogue', 'role_prets', 'role_adherents';

GRANT SELECT ON mediatheque.ouvrage TO role_catalogue;
GRANT SELECT ON mediatheque.exemplaire TO role_catalogue;
GRANT SELECT ON mediatheque.categorie TO role_catalogue;

GRANT SELECT, INSERT, UPDATE ON mediatheque.emprunt TO role_prets;
GRANT SELECT, INSERT, UPDATE ON mediatheque.reservation TO role_prets;
GRANT SELECT, INSERT, UPDATE ON mediatheque.penalite TO role_prets;
GRANT UPDATE (disponible) ON mediatheque.exemplaire TO role_prets;


GRANT SELECT, INSERT, UPDATE ON mediatheque.adherent TO role_adherents;



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

# Bonus 

CREATE USER 'analyste'@'192.168.1.%' IDENTIFIED BY 'ANalyste$35';

GRANT role_catalogue TO 'analyste'@'192.168.1.%';
GRANT SELECT ON mediatheque.emprunt TO 'analyste'@'192.168.1.%';

/*
 Explication : Que se passerait-il si 'analyste'@'%' existait aussi ?
 
 1. Ordre de priorité et sélection de l'hôte (Current User) :
    - Si 'analyste'@'%' existe simultanément avec 'analyste'@'192.168.1.%' :
      Lorsqu'un utilisateur se connecte depuis l'adresse IP 192.168.1.50, MySQL compare 
      les deux comptes et choisit TOUJOURS le compte dont l'hôte d'origine est le PLUS SPÉCIFIQUE.
    - Ainsi, la connexion retenue sera 'analyste'@'192.168.1.%' car la plage d'IP partielle 
      est plus précise que le joker global '%'.
    - Le compte 'analyste'@'%' ne serait utilisé que si l'analyste se connecte depuis une adresse 
      IP située en dehors de la plage 192.168.1.% (ex. depuis un autre sous-réseau).

 2. Du point de vue sécurité :
    - 'analyste'@'%' représente un RISQUE DE SÉCURITÉ MAJEUR en production. Le joker '%' autorise 
      les tentatives de connexion depuis n'importe quelle IP dans le monde. Si le port MySQL (3306) 
      est exposé, le compte devient vulnérable aux attaques par force brute.
    - Pour respecter le PRINCIPE DU MOINDRE PRIVILÈGE, l'utilisation du joker '%' doit être bannie 
      pour les comptes nominatifs. On privilégiera toujours une plage réseau restreinte ('192.168.1.%'), 
      une IP fixe ('192.168.1.45'), ou un accès via VPN/tunnel SSH restreint au 'localhost'.
*/


-- 2. FIN DE STAGE — VERROUILLAGE ou SUPPRESSION

# Option 1 : Verrouiller le compte 
ALTER USER 'stagiaire'@'localhost' ACCOUNT LOCK;

# Option 2 : Supprimer le compte
DROP USER IF EXISTS 'stagiaire'@'localhost';

/*
 Justification du choix (Option1 : VERROUILLAGE) :
 
 1. Traçabilité & Traçabilité d'audit : En verrouillant le compte au lieu de le supprimer, 
    on conserve l'historique de l'utilisateur dans les logs d'audit et le dictionnaire de données. 
    En cas d'investigation de sécurité sur des actions passées, le compte reste clairement identifié.
 
 2. Réversibilité : Si un futur stagiaire reprend le poste ou si un besoin ponctuel survient, 
    il suffit de déverrouiller le compte (ACCOUNT UNLOCK) et de réinitialiser le mot de passe, 
    sans réécrire toute la politique d'attribution des privilèges.
*/