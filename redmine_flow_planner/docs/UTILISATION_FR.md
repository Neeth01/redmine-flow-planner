# Guide d'utilisation - Redmine Flow Planner

## Objectif

Le plugin sert a piloter un projet Redmine de maniere plus visuelle:

- suivi de flux sur le board agile
- planification temporelle sur le gantt interactif

Tout repose sur les tickets Redmine existants.

## Prerequis

- le module `Flow Planner` doit etre active dans le projet
- ton role doit avoir les permissions adequates
- les tickets doivent deja exister

## Tableau agile

### Ce que tu vois

- une colonne par statut
- des cartes de tickets
- des compteurs par colonne
- des filtres rapides locaux
- des alertes WIP eventuelles

### Deplacer un ticket

1. glisse une carte vers une autre colonne
2. relache la carte

Si Redmine accepte la transition:

- la carte change de colonne
- le statut est mis a jour
- un journal est cree

### Edition rapide

Sur une carte, tu peux modifier rapidement:

- le sujet
- l'echeance
- l'avancement

Les actions rapides `M'assigner` et `Marquer 100%` restent disponibles quand le ticket est editable.

### Filtres rapides

Ils ne changent pas la requete Redmine. Ils filtrent seulement ce qui est deja charge:

- recherche texte
- tracker
- assigne
- tickets en retard
- tickets non assignes
- masquer les colonnes vides

## Planning Gantt

### Ce que tu vois

- une timeline journaliere
- une ligne par ticket planifie
- des barres de tickets
- des reperes de versions
- des dependances visibles
- une liste de tickets sans dates

### Deplacer un ticket

1. clique et glisse une barre
2. relache a la nouvelle position

La duree reste identique, seules les dates se decalant ensemble.

### Redimensionner un ticket

1. saisis une poignee gauche ou droite
2. tire vers la gauche ou la droite
3. relache

Cela modifie la date de debut ou de fin.

### Outils utiles

- `Aujourd'hui` recentre la vue
- `Zoom -` et `Zoom +` changent l'echelle
- `Annuler le dernier deplacement` revient sur la derniere replanification

### Editeur rapide

Le panneau lateral permet de modifier rapidement un ticket visible:

- assigne
- version
- date de debut
- date de fin
- avancement

### Filtres rapides

Comme sur le board, ils agissent seulement sur les tickets deja charges:

- recherche texte
- tracker
- assigne
- en retard
- non assignes
- dependances visibles ou masquees

## Conseils pratiques

- utilise les requetes Redmine pour cadrer le perimetre
- utilise les filtres locaux pour affiner sans recharger la page
- garde le board pour le flux quotidien
- garde le gantt pour les ajustements de dates
