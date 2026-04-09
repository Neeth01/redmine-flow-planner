# Guide d'administration - Redmine Flow Planner

## Installation

Placer `redmine_flow_planner` dans:

```text
<redmine>/plugins/
```

Puis:

1. redemarrer Redmine
2. verifier la presence du plugin dans `Administration -> Plugins`

## Activation par projet

Pour chaque projet:

1. ouvrir `Project settings`
2. aller dans `Modules`
3. activer `Flow Planner`

## Permissions

Permissions disponibles:

- `view_agile_board`
- `manage_agile_board`
- `view_planning_gantt`
- `manage_planning_gantt`

### Repartition conseillee

#### Membres d'equipe

- `view_agile_board`
- `view_planning_gantt`

#### Lead / chef de projet

- `manage_agile_board`
- `manage_planning_gantt`

## Configuration plugin

### Board limit

Controle le nombre maximum de tickets charges sur le board.

### Board sorting

Definit le tri par defaut dans chaque colonne:

- priorite
- date d'echeance
- derniere mise a jour
- progression
- sujet
- id

### WIP limits

Format supporte:

```text
Nom du statut=8
Nom du statut:8
3=5
```

Le plugin tente d'abord l'id du statut, puis son nom.

### Due soon threshold

Seuil utilise pour les tickets proches de l'echeance.

### Planner limit

Nombre max de tickets charges pour le gantt.

### Planner months

Nombre de mois ouverts par defaut.

### Planner day width

Largeur initiale d'un jour. Plus elle est grande, plus le scroll horizontal augmente.

## Comportement technique

### Agile Board

Le board met a jour principalement:

- `status_id`
- `assigned_to_id`
- `done_ratio`
- `subject`
- `due_date`

### Planning Gantt

Le planning met a jour:

- `start_date`
- `due_date`
- `assigned_to_id`
- `fixed_version_id`
- `done_ratio`

### Validation

Les validations finales restent celles de Redmine:

- droits utilisateur
- workflow
- champs editables
- statut du tracker

## Conseils de production

- privilegier des requetes sauvegardees par equipe
- limiter le volume de tickets affiches par ecran
- configurer les roles proprement
- utiliser les limites WIP comme signal de pilotage
