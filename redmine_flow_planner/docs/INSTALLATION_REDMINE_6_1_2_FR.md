# Installation pas a pas - Redmine 6.1.2

## Objectif

Installer `redmine_flow_planner` dans une instance Redmine `6.1.2` avec le minimum d'operations.

## Arborescence attendue

Le plugin doit finir exactement ici:

```text
<redmine>/plugins/redmine_flow_planner/
```

Tu dois donc avoir un fichier:

```text
<redmine>/plugins/redmine_flow_planner/init.rb
```

## Methode 1 - copie directe du dossier

1. Arreter Redmine
2. Copier le dossier `redmine_flow_planner` dans `<redmine>/plugins/`
3. Verifier que le nom du dossier n'a pas ete renomme
4. Redemarrer Redmine

## Methode 2 - extraction de l'archive

1. Arreter Redmine
2. Extraire `redmine_flow_planner-redmine-6.1.2.zip` dans `<redmine>/plugins/`
3. Verifier que le dossier racine obtenu est bien `redmine_flow_planner`
4. Redemarrer Redmine

## Verification apres redemarrage

1. Ouvrir `Administration -> Plugins`
2. Verifier la presence de `Redmine Flow Planner`
3. Ouvrir `Configure`
4. Regler au minimum:
   - la limite du board
   - la limite du planning
   - le nombre de mois du planning
   - la largeur journaliere

## Activation dans un projet

1. Ouvrir le projet
2. Aller dans `Project settings -> Modules`
3. Activer `Flow Planner`
4. Aller dans `Administration -> Roles and permissions`
5. Donner les permissions voulues

## Test fonctionnel minimal

Pour valider l'installation sans test automatise:

1. Aller sur `Agile Board`
2. Verifier l'affichage des colonnes
3. Tester la recherche rapide
4. Deplacer une carte si ton role le permet
5. Aller sur `Planning Gantt`
6. Tester le scroll, le filtre et le bouton `Aujourd'hui`
7. Deplacer une barre si ton role le permet

## Diagnostic rapide

Si le plugin n'apparait pas:

- verifier le nom du dossier
- verifier la version Redmine
- verifier les logs Redmine au demarrage

Si l'interface apparait mais pas les styles ou le JavaScript:

- verifier que le plugin est bien charge sous le nom `redmine_flow_planner`
- vider le cache applicatif si besoin
- redemarrer Redmine proprement
