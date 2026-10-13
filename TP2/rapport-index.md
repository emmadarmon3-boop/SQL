# TP2 — Rapport d'optimisation

> Les chiffres attendus sont des **ordres de grandeur** : l'archive est générée
> aléatoirement, les vôtres seront proches sans être identiques.

## Avant / après

Pour chaque requête : le plan avant tout index, puis le plan après l'index que vous avez posé.

### R1 — les emprunts d'une journée

```sql
SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';
```

| | `type` | `key` | `rows` | `Extra` |
|---|---|---|---|---|
| avant |ALL |NULL | 199875 | Using where|
| après |`ref`  | `idx_emprunt_date` |140 | `NULL`|
-
- Index créé : `CREATE INDEX idx_emprunt_date ON emprunt (date_emprunt);`                                                  `
- Lignes réellement renvoyées : 104;       `
- Une phrase de conclusion: Sans index, MySQL parcourt toute la table (~200 000 lignes) pour n'en renvoyer que 104 ; avec l'index sur `date_emprunt`, il accède directement aux lignes de la date demandée (`ref`, `rows` ≈ 140), soit plus de 1 000 fois moins de lignes lues.

### R2 — les emprunts en cours

```sql
SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;
```

| | `type` | `key` | `rows` | `Extra` |
|---|---|---|---|---|
| avant |ALL |NULL | 199 875|Using where |
| après | ref | idx_emprunt_retour | 30 | Using index condition |

- Index créé : `CREATE INDEX idx_emprunt_retour ON emprunt (date_retour_reelle);`                                                 
- Lignes réellement renvoyées :  `30`    
- Une phrase de conclusion : Sans index, MySQL parcourt toute la table (199 875 lignes) pour n'en renvoyer que 30 ; avec l'index sur `date_retour_reelle`, il accède directement aux lignes `NULL` (`ref`) et ne lit plus que 30 lignes, exactement le nombre renvoyé.

### R3 — l'historique récent d'un adhérent

```sql
SELECT id, date_emprunt FROM emprunt
 WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';
```

| | `type` | `key` | `rows` | `Extra` |
|---|---|---|---|---|
| avant |ref |fk_emprunt_adherent|55070  |Using where |
| après | range|`idx_emprunt_adh_date` | 741 |`Using where; Using index` |

- Index créé :  `CREATE INDEX idx_emprunt_adh_date ON emprunt (adherent_id, date_emprunt);                                                       `
- Pourquoi les colonnes sont-elles dans cet ordre, et pas dans l'autre ?
 On place d'abord la colonne testée par égalité (`adherent_id = 12`), puis celle testée par plage (`date_emprunt >= '2025-01-01'`). L'index est trié par adhérent, puis par date à l'intérieur de chaque adhérent : MySQL saute directement au bloc de l'adhérent 12 et n'y lit que les dates à partir de 2025, soit environ 741 lignes au lieu des 5 070 emprunts de l'adhérent. Dans l'ordre inverse `(date_emprunt, adherent_id)`, la plage sur la date arrive en premier : MySQL devrait parcourir tous les emprunts depuis 2025, tous adhérents confondus, puis filtrer sur l'adhérent. Après une condition de plage, les colonnes suivantes de l'index ne servent plus à la recherche.

## Le préfixe gauche (consigne 7)

| Requête | L'index composite sert-il ? | Pourquoi |
|---|---|---|
| `WHERE adherent_id = 12` | Oui : `ref` sur `idx_emprunt_adh_date`, `key_len = 4`, 5070 lignes | `adherent_id` est la première colonne de l'index (préfixe gauche) : l'index est trié d'abord sur elle, MySQL va directement aux lignes de l'adhérent 12. `key_len = 4` montre qu'il n'utilise que cette première colonne. |
| `WHERE date_emprunt >= '2025-01-01'` | | Non : `ALL`, `possible_keys = NULL`, 199875 lignes | `date_emprunt` n'est que la deuxième colonne : les dates ne sont triées qu'à l'intérieur de chaque adhérent, pas sur toute la table. Sans condition sur `adherent_id`, MySQL ne peut pas entrer dans l'index et parcourt toute la table. |

## L'index couvrant (consigne 8)

- Mention présente dans le premier `Extra` : ` `Extra` : `Using index` (Extra complet : `Using where; Using index`)                   `
- Elle disparaît dans le second parce que : la première requête ne demande que `id` et `date_emprunt`, deux colonnes déjà présentes dans l'index `idx_emprunt_adh_date` (`id`, clé primaire, est stocké automatiquement dans tout index secondaire InnoDB). MySQL répond donc uniquement en lisant l'index, sans jamais lire la table : l'index est **couvrant**. Avec `SELECT *`, la requête demande toutes les colonnes, dont la plupart ne sont pas dans l'index. MySQL utilise toujours l'index pour trouver les 741 lignes (`range`, même `rows`), mais doit ensuite aller lire chaque ligne complète dans la table : l'index n'est plus couvrant (`Extra` devient `Using index condition`).

## La requête réécrite (consigne 9)

```sql
-- version d'origine
SELECT COUNT(*) FROM emprunt WHERE YEAR(date_emprunt) = 2024;
-- type : ___index   ___   rows : ____199875__

-- version réécrite


-- type : ___range   ___   rows : __22203____
```

Les deux renvoient bien le même nombre :   `43015`    
Explication : `YEAR(date_emprunt)` oblige MySQL à calculer l'année pour chaque ligne. Aucun index n'est utilisable pour chercher (`possible_keys = NULL`), donc il parcourt l'index en entier (`type = index`, 199 875 lignes). En écrivant la condition directement sur la colonne, sous forme de plage, la requête devient utilisable par un index (`possible_keys` liste deux index) et MySQL fait une recherche par plage (`range`).    

## Le prix des index (consigne 10)

| | `donnees_mo` | `index_mo` |
|---|---|---|
| avant | 8.52 | 10.03|
| après |8.52 | 18.06| 

Conclusion: les données ne changent pas (8,52 Mo), mais les index passent de 10,03 à 18,06 Mo, soit +8 Mo (+80 %) pour seulement 3 index. Après optimisation, les index pèsent plus de deux fois le poids des données. Un index accélère les lectures (R1 : de 199 875 à 140 lignes lues), mais il a un coût : de l'espace disque, et des écritures plus lentes, car chaque `INSERT`, `UPDATE` ou `DELETE` doit mettre à jour tous les index concernés. On n'indexe donc que les colonnes utilisées par des requêtes fréquentes et sélectives, pas toutes les colonnes « au cas où ».

## Bonus

- Consigne 11 — l'index qu'on ne peut pas supprimer : numéro d'erreur et explication.
- Consigne 12 — `EXPLAIN` sur `v_retard` : tables visitées, index utilisés.
