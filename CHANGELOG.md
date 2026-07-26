# Changelog

## 0.2.0 — 2026-07-26

### Nouveautés

- Nouveau moteur d’associations locales : Pearson, Spearman, intervalle de confiance à 95 %, correction de Benjamini-Hochberg et sélection d’un seul décalage par paire.
- Nouvelle présentation des associations avec niveau de preuve, sens temporel et avertissement explicite sur la causalité.
- Graphiques multi-séries plus lisibles : agrégation quotidienne, formes et styles distinctifs, info-bulles contraintes à l’écran, filtres réellement appliqués et résumé VoiceOver.
- Tests unitaires et test de fumée reproductible pour le moteur statistique.

### Qualité et conformité

- Version et build synchronisés entre l’app et le widget : `0.2.0 (2)`.
- Protection iOS appliquée au fichier local et maintien de l’exclusion des sauvegardes iCloud.
- Déclaration HealthKit alignée sur l’accès réel en lecture uniquement.
- Déclaration du chiffrement exempt utilisant CryptoKit et les fonctions du système.
- Garde-fous “bien-être, non médical” ajoutés aux conditions, aux associations et à la bibliothèque de suppléments.
- Icônes App Store régénérées sans canal alpha.
- Pages de confidentialité et de support préparées pour GitHub Pages.

### Corrections

- Les filtres de protocoles et suppléments de l’écran Statistiques agissent désormais sur les séries affichées.
- La période “Tout” s’appuie sur la première donnée disponible au lieu d’une date distante invalide.
- Les séries utilisent des identifiants stables et les moyennes vides n’affichent plus `0`.
- Suppression des courbes lissées susceptibles de suggérer des valeurs non mesurées.
- Ajout de la couleur `Surface` manquante et correction de la couleur de l’écran de lancement.
