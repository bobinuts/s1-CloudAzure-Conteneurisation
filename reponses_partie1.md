# Séance 1 — Réponses partie 1
Théo Pellicano · M2 YNOV Montpellier · 2026-10-06

## Tableau de décisions

| Décision | Valeur |
|---|---|
| Suffixe personnel | `tp42` |
| Région Azure | `germanywestcentral` (Francfort) — la policy « Allowed resource deployment regions » de l'abonnement limite le déploiement à 5 régions : germanywestcentral, austriaeast, italynorth, denmarkeast, belgiumcentral. Choix : région UE la plus mature, tous services disponibles (ACR, ACI, Azure ML). |
| Groupe de ressources | `rg-dermascan-registre-tp42` |
| Registre ACR | `acrdermascantp42` |
| Nom de l'image | `dermascan-health` |
| Tag initial | `0.1.0` |
| Image de base | `python:3.12.15-slim` (version de correctif figée, relevée par `python --version`) |
| WORKDIR | `/app` |
| Port | `8000` |
| uid d'exécution | `10001` |

**Question 0.1** — Le nom du registre devient un sous-domaine DNS public (`<nom>.azurecr.io`) : un nom DNS est unique au niveau mondial, d'où l'unicité sur tout Azure et la restriction aux minuscules et chiffres.

## 1.1 — Modèles de service

| Modèle | Géré par le fournisseur | À ma charge | Exemple Azure |
|---|---|---|---|
| IaaS | Matériel, réseau physique, virtualisation | OS, mises à jour, runtime, application, données | Azure Virtual Machines |
| PaaS | Matériel, réseau, virtualisation, OS et correctifs, runtime | Code, configuration, données | Azure App Service |
| SaaS | Toute la pile, application comprise | Données, utilisateurs et droits d'accès | Microsoft 365 |

## 1.2 — Où s'arrête ma responsabilité

| Couche | Dernier modèle où c'est à moi |
|---|---|
| Correctifs de sécurité de l'OS | IaaS |
| Version du runtime Python | IaaS |
| Code de l'application | PaaS |
| Dimensionnement du nombre d'instances | PaaS |
| Données métier | SaaS |

**Question 1.1** — Les données métier restent à ma charge dans les trois modèles. DermaScan demeure responsable de traitement de données de santé (données sensibles, art. 9 RGPD) quel que soit le modèle : le fournisseur n'est que sous-traitant (art. 28), et la localisation UE, le chiffrement, la minimisation et la base légale restent de notre responsabilité.

## 1.3 — Caractéristiques NIST

| Caractéristique | Traduction opérationnelle |
|---|---|
| Libre-service à la demande | Je crée une ressource sans ouvrir de ticket ni attendre l'accord d'un humain. |
| Accès réseau large | J'administre et j'utilise le service depuis n'importe quel poste connecté, via portail, CLI ou API. |
| Mise en commun des ressources | Mon registre tourne sur une infrastructure partagée avec d'autres clients ; je choisis une région, pas une machine. |
| Élasticité rapide | J'augmente ou je réduis la capacité en quelques minutes, sans acheter de matériel. |
| Service mesuré | Chaque ressource est comptée et facturée tant qu'elle existe, et visible dans Cost Management. |

**Question 1.2** — Le service mesuré : tout ce qui existe est compté et facturé, même sans être utilisé. Une ressource oubliée continue de consommer le crédit, d'où le nettoyage obligatoire.

## Relevé initial (guide de création du compte)

| Élément | Valeur |
|---|---|
| Abonnement utilisé | Azure for Students — Actif |
| Crédit restant au 2026-10-06, avant toute création | 88,00 € (≈ 100 $), 0 % utilisé |
| Page « Groupes de ressources » | vide |

Point de départ de la série de relevés de crédit : c'est l'écart entre deux relevés qui révèle une ressource oubliée.

## 1.4 — Mesure 1 : exploration du portail

| # | Observation | Réponse |
|---|---|---|
| 1 | Champs obligatoires à la création d'un ACR | **6** (onglet Informations de base) : Abonnement, Groupe de ressources, Nom du registre (suffixe `.azurecr.io`), Emplacement, Étendue d'étiquette du nom de domaine, Plan de tarification. Rien n'a été créé. |
| 2 | Identifiant et état de l'abonnement | `fa6f278b-c975-4514-a7d5-ae2c3eb4310b` — état : **Actif** |
| 3 | Nombre de groupes de ressources | **0** (« Aucun groupe de ressources à afficher ») |
| 4 | Crédit restant au 2026-10-06 | **88,00 €** (≈ 100 $), 0,00 % du crédit utilisé, montant dû 0,00 € |
| 5 | Quota limitant pour 10 VM | **Total Regional vCPUs** (nombre total de vCPU utilisables simultanément dans une région, toutes VM confondues ; complété par le quota par famille de VM). Valeur non affichée : le fournisseur de ressources `Microsoft.Compute` est à l'état *NotRegistered* sur cet abonnement neuf, et Azure n'expose pas les quotas de calcul tant qu'il n'est pas enregistré. Aucun enregistrement manuel effectué : le TP ne crée aucune VM. |
| 6 | Rôle de l'onglet Étiquettes | Associer des paires clé/valeur à une ressource pour l'imputer à un projet, un propriétaire ou une date de fin, et la retrouver ou filtrer les coûts. |

### Classement

| Service Azure | Modèle |
|---|---|
| Azure Virtual Machines | IaaS |
| Azure App Service | PaaS |
| Azure Container Registry | PaaS |
| Azure Machine Learning (espace managé) | PaaS |
| Microsoft 365 | SaaS |

**Question 1.3**
- Une ressource ne peut appartenir qu'à un seul groupe à la fois (elle peut être déplacée, pas partagée).
- Supprimer un groupe supprime toutes les ressources qu'il contient, de façon irréversible.
- Non : la région du groupe ne contraint pas celle de ses ressources. Elle fixe seulement où sont stockées les métadonnées du groupe (et donc où s'exécutent les opérations de gestion sur ce groupe).
