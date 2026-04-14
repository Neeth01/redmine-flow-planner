# Redmine Flow Planner

`redmine_flow_planner` est un plugin Redmine `6.1.2` centre sur trois usages:

- suivre le travail au quotidien avec un tableau agile manipulable
- replanifier les tickets avec un Gantt interactif en drag-and-drop
- executer et securiser le travail avec une checklist native sur les tickets

Le plugin s'installe directement dans `plugins/redmine_flow_planner` et reutilise la logique native de Redmine:

- `IssueQuery`
- permissions et roles
- workflows de statuts
- `safe_attributes`
- journaux (`journals`)

La seule couche metier ajoutee concerne les points de checklist associes aux tickets.

## Ecrans ajoutes

Le plugin ajoute deux ecrans au niveau projet:

1. `Agile Board`
2. `Planning Gantt`

Ces vues se basent sur la requete d'issues courante. Les filtres Redmine restent donc la base du perimetre affiche.

## Fonctionnalites principales

### Tableau agile

- une colonne par statut Redmine
- drag-and-drop entre colonnes
- verification du workflow Redmine avant changement de statut
- tri configurable
- filtres locaux rapides par recherche, tracker, assigne, retard et non assigne
- memorisation locale des filtres dans le navigateur
- masquage des colonnes vides
- limites WIP configurables
- edition rapide du sujet, de l'echeance et de l'avancement
- creation rapide d'un ticket depuis une colonne
- actions rapides `M'assigner` et `Marquer 100%`

### Planning Gantt

- barre draggable pour deplacer un ticket
- poignees de resize pour modifier debut et fin
- navigation par fenetre de temps
- zoom rapide
- bouton `Aujourd'hui`
- annulation du dernier deplacement
- dependances visuelles
- hierarchie parent / enfant
- reperes de versions sur la timeline
- tickets sans dates listes a part
- editeur rapide du ticket selectionne
- filtres locaux rapides par recherche, tracker, assigne, retard et non assigne

### Checklists de tickets

- checklist native sur la fiche ticket
- ajout, edition, suppression et reorganisation des points
- points obligatoires pour representer les bloqueurs de livraison
- resume checklist visible sur les cartes Agile et les lignes Gantt
- blocage optionnel de la fermeture d'un ticket si des points obligatoires restent ouverts

## Compatibilite

- cible: `Redmine 6.1.2`
- declaration plugin: `requires_redmine version_or_higher: '6.1.2'`
- `init.rb` a ete conserve

## Installation

### Copie directe

Copier le dossier:

```text
redmine_flow_planner
```

dans:

```text
<redmine>/plugins/
```

Tu dois obtenir:

```text
<redmine>/plugins/redmine_flow_planner/init.rb
```

### Archive ZIP

Extraire:

```text
redmine_flow_planner-redmine-6.1.2.zip
```

dans:

```text
<redmine>/plugins/
```

### Ensuite

1. redemarrer Redmine
2. verifier le plugin dans `Administration -> Plugins`
3. activer le module `Flow Planner` dans les projets voulus
4. donner les permissions aux roles

## Permissions

Le plugin utilise six permissions:

- `view_agile_board`
- `manage_agile_board`
- `view_planning_gantt`
- `manage_planning_gantt`
- `view_flow_checklists`
- `manage_flow_checklists`

Usage recommande:

- equipe projet: vue du board et du gantt
- lead / chef de projet: gestion du board et du gantt

## Configuration

Dans `Administration -> Plugins -> Redmine Flow Planner -> Configure`:

- `Agile board issue limit`
- `Agile board sorting`
- `Column WIP limits`
- `Due soon threshold in days`
- `Planner issue limit`
- `Default planner months`
- `Planner day width in pixels`
- `Checklist summaries on board/gantt`
- `Prevent closing when required checklist items remain open`

### Format des limites WIP

Une ligne par regle. Nom du statut ou id:

```text
Nouveau=10
En cours:6
3=5
```

## Utilisation rapide

### Agile Board

1. ouvrir un projet
2. aller sur `Agile Board`
3. conserver ou changer la requete Redmine
4. utiliser les filtres locaux si besoin
5. glisser une carte vers une autre colonne

Quand une carte est deplacee:

- le plugin envoie une mise a jour Redmine standard
- Redmine valide les droits et le workflow
- un journal est cree si la modification est acceptee

### Planning Gantt

1. ouvrir `Planning Gantt`
2. regler la fenetre visible
3. utiliser la recherche et les filtres rapides
4. glisser une barre pour la decaler
5. tirer une poignee pour changer debut ou fin
6. utiliser `Aujourd'hui` ou `Annuler le dernier deplacement` si besoin

## Structure

Fichiers principaux:

- `init.rb`
- `config/routes.rb`
- `app/controllers/agile_boards_controller.rb`
- `app/controllers/flow_checklist_items_controller.rb`
- `app/controllers/planning_gantts_controller.rb`
- `app/models/flow_checklist_item.rb`
- `app/views/flow_checklist_items/`
- `app/views/agile_boards/`
- `app/views/planning_gantts/`
- `assets/javascripts/redmine_flow_checklists.js`
- `assets/stylesheets/redmine_flow_checklists.css`
- `assets/javascripts/redmine_flow_planner.js`
- `assets/stylesheets/redmine_flow_planner.css`
- `lib/redmine_flow_planner/issue_patch.rb`
- `lib/redmine_flow_planner/hooks.rb`
- `lib/redmine_flow_planner/settings.rb`
- `lib/redmine_flow_planner/timeline.rb`

## Documentation

- `docs/UTILISATION_FR.md`
- `docs/ADMINISTRATION_FR.md`
- `docs/FONCTIONNALITES_FR.md`
- `docs/INSTALLATION_REDMINE_6_1_2_FR.md`

## Tests

Tests inclus:

- `test/functional/agile_boards_controller_test.rb`
- `test/functional/flow_checklist_items_controller_test.rb`
- `test/functional/planning_gantts_controller_test.rb`

Exemple:

```bash
RAILS_ENV=test bundle exec rake test TEST=plugins/redmine_flow_planner/test/functional/agile_boards_controller_test.rb
RAILS_ENV=test bundle exec rake test TEST=plugins/redmine_flow_planner/test/functional/flow_checklist_items_controller_test.rb
RAILS_ENV=test bundle exec rake test TEST=plugins/redmine_flow_planner/test/functional/planning_gantts_controller_test.rb
```
