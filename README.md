# Redmine Flow Planner

Depot source du plugin `redmine_flow_planner` et du theme `flow_horizon` pour Redmine `6.1.2`.

L'objectif du projet est d'ajouter a Redmine une experience de pilotage plus visuelle et plus pratique, sans sortir du modele natif de Redmine:

- un tableau agile par statuts avec drag-and-drop
- un gantt interactif pour replanifier les tickets
- un theme global pour aligner l'interface Redmine avec ces ecrans

Le plugin repose sur les objets natifs Redmine (`Issue`, `IssueQuery`, permissions, workflows, journals) et n'ajoute pas de modele metier parallele.

## Contenu du depot

Le depot contient deux livrables principaux:

- `redmine_flow_planner/`
  Plugin Redmine a installer dans `plugins/redmine_flow_planner`
- `themes/flow_horizon/`
  Theme Redmine a installer dans `themes/flow_horizon`

Structure:

```text
.
|-- redmine_flow_planner/
|   |-- app/
|   |-- assets/
|   |-- config/
|   |-- docs/
|   |-- lib/
|   |-- test/
|   `-- init.rb
|-- themes/
|   `-- flow_horizon/
|       |-- favicon/
|       |-- javascripts/
|       `-- stylesheets/
`-- .gitignore
```

## Fonctionnalites

### Plugin `redmine_flow_planner`

Deux vues projet sont ajoutees:

1. `Tableau agile`
2. `Gantt interactif`

Principales capacites:

- visualisation des tickets par statut dans un board Kanban
- drag-and-drop entre colonnes avec respect du workflow Redmine
- creation rapide de ticket depuis le board
- edition rapide de certaines infos ticket
- replanification par glisser-deposer dans le gantt
- ajustement des dates de debut et de fin directement sur la barre
- navigation temporelle, zoom, retour a aujourd'hui
- prise en compte des permissions et de l'historique Redmine

### Theme `flow_horizon`

Le theme harmonise l'interface globale avec le plugin:

- header et navigation compacts
- formulaires, boutons et tableaux plus lisibles
- meilleure coherence visuelle entre Redmine et les vues du plugin
- adaptations specifiques pour les pages agile et gantt

## Compatibilite

- Redmine cible: `6.1.2`
- plugin: `redmine_flow_planner`
- theme: `flow_horizon`

Le `init.rb` du plugin a ete conserve dans le code source.

## Installation

### 1. Installer le plugin

Copier le dossier `redmine_flow_planner` dans:

```text
<redmine>/plugins/redmine_flow_planner
```

Puis redemarrer Redmine.

### 2. Installer le theme

Copier le dossier `themes/flow_horizon` dans:

```text
<redmine>/themes/flow_horizon
```

Puis dans Redmine:

1. aller dans `Administration -> Settings -> Display`
2. choisir `flow_horizon`
3. enregistrer

### 3. Activer le module dans les projets

Dans chaque projet:

1. ouvrir `Configuration -> Modules`
2. activer `Flow Planner`

### 4. Donner les permissions

Dans `Administration -> Roles and permissions`, attribuer selon les besoins:

- `view_agile_board`
- `manage_agile_board`
- `view_planning_gantt`
- `manage_planning_gantt`

## Utilisation

### Tableau agile

- ouvrir un projet
- aller sur `Tableau agile`
- utiliser la requete Redmine du projet comme perimetre
- glisser une carte d'une colonne a une autre pour changer le statut

### Gantt interactif

- ouvrir un projet
- aller sur `Gantt interactif`
- deplacer une barre pour replanifier un ticket
- redimensionner une barre pour ajuster sa plage de dates

## Documentation incluse

La documentation detaillee du plugin est disponible dans:

- `redmine_flow_planner/docs/UTILISATION_FR.md`
- `redmine_flow_planner/docs/ADMINISTRATION_FR.md`
- `redmine_flow_planner/docs/FONCTIONNALITES_FR.md`
- `redmine_flow_planner/docs/INSTALLATION_REDMINE_6_1_2_FR.md`

Documentation locale du theme:

- `themes/flow_horizon/README.md`

## Developpement

Fichiers principaux du plugin:

- `redmine_flow_planner/init.rb`
- `redmine_flow_planner/config/routes.rb`
- `redmine_flow_planner/app/controllers/agile_boards_controller.rb`
- `redmine_flow_planner/app/controllers/planning_gantts_controller.rb`
- `redmine_flow_planner/assets/javascripts/redmine_flow_planner.js`
- `redmine_flow_planner/assets/stylesheets/redmine_flow_planner.css`

Fichiers principaux du theme:

- `themes/flow_horizon/stylesheets/application.css`
- `themes/flow_horizon/javascripts/theme.js`

Tests inclus:

- `redmine_flow_planner/test/functional/agile_boards_controller_test.rb`
- `redmine_flow_planner/test/functional/planning_gantts_controller_test.rb`

Exemple d'execution:

```bash
RAILS_ENV=test bundle exec rake test TEST=plugins/redmine_flow_planner/test/functional/agile_boards_controller_test.rb
RAILS_ENV=test bundle exec rake test TEST=plugins/redmine_flow_planner/test/functional/planning_gantts_controller_test.rb
```

## Notes de depot

Le depot versionne uniquement le code source utile:

- le plugin
- le theme
- la documentation

Les archives ZIP generees localement et les dossiers de reference ne sont pas suivis par Git.
