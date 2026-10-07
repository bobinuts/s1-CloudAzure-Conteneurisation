# Séance 1 — Mesures et réponses (parties 2 à 6)
Théo Pellicano · M2 YNOV Montpellier · TP réalisé les 06 et 07/10/2026

Captures (`captures/`) : `curlHealth.png` (sonde `/health` du conteneur local, port 8080, HTTP 200), `curlHealth_LocalHost.png` (conteneur `dermascan-health-bis`, port 8081, `version` surchargée en `0.1.0-staging`, Q3.6), `CapturePortailAzure.png` (dépôt `dermascan-health` et tag `0.1.0` dans le portail ACR).

## Mesure 2 — Identité du compte Azure
| Élément | Valeur |
|---|---|
| Identifiant de l'abonnement | `fa6f278b-c975-4514-a7d5-ae2c3eb4310b` (Azure for Students, Actif) |
| Nom du locataire (tenant) | **Ynov** (`38e72bba-3c22-4382-9323-ac1612931297`) |

**Question 2.1** — `az account list-locations` liste **109 entrées**. Ce chiffre est trompeur :
- il mélange des **régions physiques** (`germanywestcentral`, `francecentral`…), des **zones géographiques logiques** sans datacenter propre (`europe`, `france`, `germany`, `global`…) et des **régions internes Microsoft** (`*stage`, `*euap`, `*stg`) inutilisables ;
- surtout, une **policy Azure for Students** (« Allowed resource deployment regions ») n'autorise le déploiement que dans **5 régions** : `germanywestcentral`, `austriaeast`, `italynorth`, `denmarkeast`, `belgiumcentral`. `francecentral`, pourtant listée, serait refusée.

Région retenue : `germanywestcentral`.

Deux critères qui imposent une région en entreprise pour des données européennes :
1. **Souveraineté et conformité** : données personnelles (ici de santé) hébergées dans l'UE (RGPD, éventuellement certification HDS en France) ; le contrat client ou une policy d'organisation peut imposer un pays précis.
2. **Disponibilité des services et latence** : tous les services (ACR, ACI, Azure ML, GPU) ne sont pas proposés partout ; on choisit une région proche des utilisateurs et des sources de données, qui offre les services et les zones de disponibilité nécessaires (le prix varie aussi selon la région).

## Mesure 3 — Groupe de ressources
| Élément | Valeur |
|---|---|
| Groupe | `rg-dermascan-registre-tp42` |
| Région | `germanywestcentral` |
| ProvisioningState | **Succeeded** |
| Étiquettes | `projet=dermascan`, `role=registre`, `proprietaire=theo.pellicano`, `a_detruire=2027-07-31` (postérieure à la soutenance : ce groupe porte le registre consommé par les séances 2, 3, 4 et le projet fil rouge) |

**Question 2.2** — Non : crédit relevé après création = 88,00 €, inchangé. Un groupe de ressources est un conteneur logique (métadonnées ARM) sans capacité réservée ; seules les ressources qu'il contient sont facturées.

## Mesure 4 — Environnement Docker du poste
| Élément | Commande | Valeur |
|---|---|---|
| Version du client Docker | `docker version` | 29.8.2 |
| Version du démon (server) | `docker version` | 29.8.2 |
| Architecture | `docker info` | x86_64 (amd64) |
| Images déjà présentes | `docker info` | 0 |
| Mémoire allouée au démon | `docker info` | 7.437 GiB |

Test de bout en bout `docker run --rm hello-world` : OK (« Hello from Docker! », image tirée en amd64 depuis Docker Hub).

Contexte : Docker Desktop sur Windows, moteur Linux dans WSL2 (noyau 6.6.87.2-microsoft-standard-WSL2), 12 CPU.

## Partie 3
**Question 3.1** — En conteneur, `127.0.0.1` désigne l'interface loopback du conteneur lui-même : le trafic redirigé par `-p` arrive sur l'interface réseau du conteneur, donc seule une écoute sur `0.0.0.0` (toutes les interfaces) le reçoit.

**Question 3.2** — Oui. `EXPOSE` est purement déclaratif (documentation + métadonnée `ExposedPorts` lue par `docker run -P` et par les outils) : c'est `-p hôte:conteneur` qui crée réellement la redirection de port. Sans `EXPOSE`, `-p 8080:8000` fonctionne à l'identique ; on perd seulement l'information pour le lecteur et pour `-P`. _Non vérifié expérimentalement (option facultative de l'énoncé) : réponse fondée sur la documentation Docker._

**Question 3.3** — Sans `.dockerignore`, `docker build .` envoie tout le dossier au démon comme contexte de build :
1. **Durée** : les 400 Mo du `.venv/` sont transférés au démon à chaque build (étape « transferring context »), avant même la première instruction.
2. **Image** : avec `COPY . ./` (Dockerfile naïf), le `.venv/` est copié dans l'image : +400 Mo inutiles, un environnement compilé pour l'hôte (Windows) inutilisable sous Linux, et un risque de fuite de fichiers locaux. En plus, toute modification dans `.venv/` invalide le cache de la couche `COPY`.

### Mesure 5 — Premier build
| Mesure | Valeur |
|---|---|
| Durée du premier build (cache vide) | **16,8 s** (`Measure-Command`, BuildKit annonce 16,3 s) avec `--no-cache`, image de base déjà présente localement (son téléchargement n'est pas compté). Détail : `pip install` 4,1 s, `useradd` 2,0 s, export de l'image 5,5 s |
| Taille de l'image | **185 MB** sur disque (44,9 MB de contenu compressé) |
| Nombre de couches (`docker history`) | **19 lignes** : 10 héritées de l'image de base + 9 ajoutées par mon Dockerfile (une par instruction après `FROM`). Seules 5 lignes ajoutent des octets (WORKDIR, 2×COPY, 2×RUN) ; ENV, USER, EXPOSE, CMD = 0 B (métadonnées) |
| Couche la plus lourde et son instruction | Globale : **87,7 MB**, le système de fichiers Debian 13 « trixie » (`debian.sh --arch amd64 … trixie`), hérité de l'image de base. Dans mon Dockerfile : **5,64 MB**, `RUN pip install --no-cache-dir -r requirements.txt` (Flask et ses dépendances) |
| Taille de l'image de base seule | `python:3.12-slim` (= 3.12.15) : **179 MB** sur disque, 45,4 MB de contenu compressé |

**Question 3.4** — Image de base 179 MB / image finale 185 MB = **96,8 %** (≈ 6 MB seulement ajoutés par mon Dockerfile, dont 5,64 MB pour `pip install`). Recoupement par `docker history` : 134,1 MB de couches de base pour 5,7 MB ajoutés, soit 95,9 %. Conséquence : le levier principal pour réduire la taille (et la surface d'attaque) est le choix de l'image de base (slim, distroless, alpine), pas l'optimisation de mes propres couches.

### Mesure 6 — Réponse /health (local)
| Mesure | Valeur |
|---|---|
| Code HTTP | **200 OK** (`Server: Werkzeug/3.1.9 Python/3.12.15`, `Content-Type: application/json`) |
| hostname | `244d17d71fb6` (= CONTAINER ID court affiché par `docker ps`) |
| version | `0.1.0` |
| status | `ok` |

Contrôles associés : `docker ps` → `Up`, ports `0.0.0.0:8080->8000/tcp` ; `docker logs` → « Running on all addresses (0.0.0.0) » et l'avertissement « This is a development server. Do not use it in a production deployment » (repris dans la rubrique 14 de la fiche d'identité).

**Question 3.5** — `hostname` vaut l'identifiant court du conteneur, attribué par Docker à sa création : `244d17d71fb6` au premier lancement, puis **`368015522e51`** après `docker rm -f` + `docker run`, à partir de la **même image**. L'`uptime_seconds` repart lui aussi de zéro. Conclusion : un conteneur est une instance **éphémère et interchangeable** ; son identité n'est pas stable et rien ne doit en dépendre (ni état local, ni configuration codée en dur, ni adresse fixe). L'identité durable, c'est l'**image** (son tag, et surtout son digest) ; un orchestrateur détruit et recrée les conteneurs librement.

**Question 3.6** — Second conteneur `dermascan-health-bis` lancé depuis la **même image** `dermascan-health:0.1.0`, sur le port hôte 8081, avec `-e APP_VERSION="0.1.0-staging"` : `/health` renvoie `"version":"0.1.0-staging"` (hostname `0d36d10e985f`), tandis que le conteneur du port 8080 renvoie toujours `"0.1.0"`. **Oui, la réponse change sans aucune reconstruction.** L'image est l'artefact immuable, construit une seule fois ; la configuration est injectée au lancement et varie selon l'environnement (dev, staging, prod). C'est le principe « build once, run anywhere » (facteur III des 12-factor apps) : on promeut le même artefact d'un environnement à l'autre en ne changeant que sa configuration, ce qui garantit que ce qui a été testé est exactement ce qui tourne en production.

### Mesure 7 — Cache de build
| Scénario | Durée | Étapes CACHED | pip install rejoué ? |
|---|---|---|---|
| A — bon ordre, après modification d'`app.py` | **10,4 s** (BuildKit : 9,8 s) | **3 / 5** (WORKDIR, COPY requirements.txt, RUN pip install) | **Non** (`CACHED [4/6]`) — seuls `COPY app.py` (0,4 s) et `useradd` (2,2 s) rejoués |
| B — mauvais ordre, après modification d'`app.py` | **15,6 s** (BuildKit : 15,0 s) | **1 / 4** (WORKDIR seul) | **Oui** — `COPY . ./` invalidé, donc `pip install` (4,4 s) et `useradd` (2,1 s) rejoués |
| Écart A/B | **+5,2 s par build** (×1,5) | 3 → 1 étape en cache | l'écart ≈ durée de `pip install` + export d'une couche de 5,6 MB |

Témoin : Dockerfile naïf reconstruit **sans** modifier `app.py` → 4/4 étapes `CACHED`, 3,9 s. C'est donc bien la modification du code, et non le Dockerfile lui-même, qui invalide le cache.

### Mesure 8 — Utilisateur non-root
| Contrôle | Attendu | Observation |
|---|---|---|
| `id` dans le conteneur | uid non nul | `uid=10001(appuser) gid=10001(appuser) groups=10001(appuser)` ✅ |
| `.Config.User` | non vide | `10001` ✅ |
| Écriture dans /etc | refusée | `touch: cannot touch '/etc/preuve_root': Permission denied` ✅ |


**Question 3.7** — Docker calcule pour chaque instruction une clé de cache : le texte de l'instruction, la couche parente et, pour `COPY`/`ADD`, une empreinte (checksum) du contenu des fichiers copiés. Si la clé est identique à une couche existante, celle-ci est réutilisée (`CACHED`). Dès qu'une couche est invalidée (instruction modifiée ou fichier copié différent), sa clé change, et comme chaque couche dépend de sa parente, **toutes les couches suivantes sont reconstruites**, même si leurs instructions n'ont pas changé. Avec `COPY . ./` avant `pip install`, toute modification du code invalide l'installation des dépendances ; en copiant `requirements.txt` seul d'abord, `pip install` ne rejoue que si les dépendances changent.

**Question 3.8** — Mesuré avec Flask seul : +5,2 s par build, soit ~1 min 45 sur 20 itérations, négligeable. Mais l'écart est proportionnel au temps de `pip install`. Avec `scikit-learn`, `pandas` et `numpy` (≈ 100–150 Mo de wheels compilées, dont scipy et joblib en transitif), l'installation prend typiquement 30 s à 1 min 30 selon la connexion, plus l'export d'une couche de plusieurs centaines de Mo. Estimation : **~1 min perdue par build × 20 itérations ≈ 20 à 30 minutes par jour et par développeur**, sans compter le cache pip réseau et la consommation de bande passante, et davantage en CI où chaque pipeline le subit. (Estimation à vérifier en séance 2 par une mesure réelle.)

**Question 3.9** — En root, l'attaquant peut modifier tout le système de fichiers du conteneur (binaires, `/etc`, installer des outils, persister) et, surtout, il est root (uid 0) au regard du noyau partagé avec l'hôte : la moindre faille d'isolation (évasion de conteneur, volume ou socket Docker monté, capacité mal configurée) lui donne directement le contrôle de l'hôte. En `appuser` (uid 10001), il reste cantonné aux droits de ce compte : lecture de l'application seulement, pas d'écriture système, et une évasion ne lui donne qu'un utilisateur non privilégié.

Note — reproductibilité : après restauration de l'`app.py` d'origine, `docker build -t dermascan-health:0.1.0 .` passe 5/5 étapes en `CACHED` et produit le **même manifeste** (`sha256:365acb63…`) que le build `--no-cache` initial : le cache est indexé sur le contenu des fichiers, et un même contenu donne le même artefact. L'image publiée correspond donc exactement au code rendu.

## Partie 4
### Incident rencontré à la création du registre
`az acr check-name` → `acrdermascantp42.azurecr.io`, `NameAvailable: True`. Mais `az acr create` a échoué avec `MissingSubscriptionRegistration` : *The subscription is not registered to use namespace 'Microsoft.ContainerRegistry'*. Sur un abonnement neuf, les fournisseurs de ressources sont à l'état *NotRegistered* (constat déjà fait en partie 1 pour `Microsoft.Compute`) et la CLI ne les enregistre pas automatiquement. Correction : `az provider register --namespace Microsoft.ContainerRegistry` (gratuit, ne crée aucune ressource), attente de l'état `Registered`, puis relance de `az acr create`.

### Mesure 9 — Registre ACR
| Élément | Valeur |
|---|---|
| loginServer | `acrdermascantp42.azurecr.io` |
| SKU | **Basic** (région `germanywestcentral`, créé le 2026-10-06T14:48:47Z par theo.pellicano@ynov.com ; supprimé pendant la pause, recréé à l'identique le 2026-10-07T08:09:17Z) |
| État d'approvisionnement | **Succeeded** |
| Coût mensuel annoncé | ≈ **0,167 $/jour, soit ≈ 5 $/mois** (tarif Basic, 10 Go inclus — page tarifaire Azure Container Registry, à reconfirmer pour la région) |

Paramètres de sécurité relevés à la création : `adminUserEnabled: false` (pas de compte admin à mot de passe), `anonymousPullEnabled: false`, `publicNetworkAccess: Enabled` (registre joignable depuis Internet, authentification requise), chiffrement par clé client désactivé (chiffrement par clés gérées par Microsoft).

**Question 4.1** —

| SKU | Stockage inclus | Fonctionnalités clés | Coût indicatif |
|---|---|---|---|
| Basic | 10 Go | Push/pull, authentification Entra ID, webhooks limités ; débit le plus bas | ≈ 0,17 $/jour |
| Standard | 100 Go | Idem Basic, plus de débit et de webhooks | ≈ 0,67 $/jour |
| Premium | 500 Go | + **géoréplication**, **Private Link / endpoints privés** et règles réseau, **zones de disponibilité**, **clé de chiffrement gérée par le client**, tokens à portée de dépôt, débit maximal | ≈ 1,67 $/jour |

Passage au Premium pour DermaScan : dès que le registre devra être **privé** (accès uniquement via le réseau virtuel de la plateforme, sans exposition Internet, attendu pour un système manipulant des données de santé), ou dès que DermaScan servira plusieurs régions ou pays (géoréplication pour tirer les images au plus près des centres de dépistage, et résilience si une région tombe). La volumétrie seule ne justifie pas le Premium : les images d'inférence tiennent largement dans 10 à 100 Go.

**Question 4.2** — Après `az acr login`, `~/.docker/config.json` contient une entrée `auths` pour `acrdermascantp42.azurecr.io` et la ligne `"credsStore": "desktop"`. Avec Docker Desktop, le secret lui-même (jeton d'accès ACR, valable environ 3 h, émis à partir de mon identité Entra ID) est délégué au gestionnaire d'identifiants de Windows ; sans `credsStore`, il serait écrit **en clair** (encodé en base64, donc non chiffré) dans le champ `auth` du fichier. Ce fichier est un secret à ne jamais committer : quiconque récupère le jeton peut, pendant sa durée de validité, pousser ou tirer des images dans le registre en mon nom, sans connaître mon mot de passe ni passer la MFA, et donc par exemple remplacer une image de production par une image piégée. Un dépôt Git public est scanné en continu par des robots à la recherche de ce type de secret.

**Question 4.3** — Le compte administrateur (`--admin-enabled true`) est déconseillé en entreprise :
1. **Identifiant partagé et non traçable** : un seul couple utilisateur/mot de passe pour tout le registre, partagé entre personnes et pipelines ; le journal d'activité ne permet plus de savoir *qui* a poussé une image, et révoquer l'accès d'une personne impose de changer le mot de passe pour tous.
2. **Droits maximaux et secret longue durée** : le compte admin a tous les droits (push, pull, suppression) sur tous les dépôts, sans moindre privilège possible, et son mot de passe n'expire pas : une fois fuité dans un script ou un fichier de config, il reste exploitable jusqu'à rotation manuelle. À l'inverse, Entra ID (RBAC `AcrPush`/`AcrPull`, identités managées pour les services) fournit des jetons courts, nominatifs, révocables et soumis à la MFA et à l'accès conditionnel.

### Mesure 10 — Premier push
| Mesure | Valeur |
|---|---|
| Durée du push | **4,1 s** (`Measure-Command`) |
| Couches poussées | **11 blobs `Pushed`** : les 9 couches de système de fichiers (4 de l'image de base + 5 de mon Dockerfile : WORKDIR, 2×COPY, 2×RUN) + la configuration de l'image + l'attestation de provenance ajoutée par BuildKit |
| IMAGE ID local = taggé ? | **Oui, identiques** : `d16623496590` pour `dermascan-health:0.1.0` et `acrdermascantp42.azurecr.io/dermascan-health:0.1.0` — `docker tag` ajoute un second nom au même contenu, sans copie ni reconstruction (taille 185 MB inchangée) |
| Digest | `sha256:d16623496590133dbaf7c65ae08c5425bf69d2b8594e57b045319d6e88d635db` (`size: 856` : c'est l'index d'image — manifeste de l'image + manifeste d'attestation — dont le digest est aussi l'IMAGE ID local avec le stockage containerd de Docker Desktop) |

**Expérience complémentaire — second push (07/10/2026, après recréation du registre)**

| | Premier push (06/10) | Second push identique (07/10) |
|---|---|---|
| Durée | 4,1 s | **1,7 s** |
| Message par couche | `Pushed` (11 blobs) | **`Layer already exists`** / `Already exists` (11 blobs, 0 octet de couche transféré) |
| Digest | `sha256:d1662349…` | `sha256:d1662349…` (identique) |

**Question 4.4** — Non, la durée chute (4,1 s → 1,7 s, le reste étant l'authentification et l'envoi du manifeste). Pour chaque couche, Docker affiche `Layer already exists` : avant d'envoyer un blob, le client demande au registre (requête `HEAD /v2/<dépôt>/blobs/<digest>`) s'il possède déjà ce digest, et ne transfère que les blobs absents. Le registre stocke donc les couches **par contenu (adressage par empreinte sha256)**, de façon dédupliquée : une couche identique n'est stockée qu'une fois, même si plusieurs images ou tags la partagent (ici, toutes les images bâties sur `python:3.12.15-slim` partageraient les 4 couches de base). Conséquences : push et pull incrémentaux (seules les couches modifiées transitent — d'où l'intérêt de l'ordre du Dockerfile, vu en 3.5), et stockage facturé au contenu réel, pas au nombre de tags.

Note — reprise du 07/10 : le registre, supprimé pendant la pause (voir section « Pause du 06/10 »), a été recréé le 2026-10-07 à 08:09 UTC (même nom, même SKU Basic, même région) ; l'image locale repoussée a produit **exactement le même digest** `sha256:d16623496590…` qu'en Mesure 10 : une image est identifiée par son contenu, indépendamment du registre qui l'héberge.

**4.4 — Vérification dans le registre** (`az acr repository list` / `show-tags` / `manifest list-metadata`) : 1 dépôt `dermascan-health`, 1 tag `0.1.0`, et **3 manifestes** :

| Digest | Type | Architecture / OS | Taille | Rôle |
|---|---|---|---|---|
| `sha256:d1662349…` | `oci.image.index.v1` | — | 0 | **Index** porté par le tag `0.1.0` (= digest du push) ; il pointe vers les deux manifestes ci-dessous |
| `sha256:365acb63…` | `oci.image.manifest.v1` | **amd64 / linux** | 44 869 109 o (≈ 44,9 MB compressés) | Manifeste de l'image exécutable (le même que celui produit par le build `--no-cache` en partie 3) |
| `sha256:72e9b2b1…` | `oci.image.manifest.v1` (config `oci.empty`) | — | 1 102 o | Attestation de provenance BuildKit (comment l'image a été construite) |

Aucune ligne orpheline : les deux manifestes sans tag sont référencés par l'index. L'architecture **amd64/linux** est lisible : poste amd64, aucun rebuild `--platform linux/amd64 --provenance=false` nécessaire (cas réservé aux postes arm64). Capture du dépôt dans le portail : `captures/CapturePortailAzure.png` (dépôt `dermascan-health`, 1 étiquette `0.1.0`, 3 manifestes, synthèse `sha256:d1662349…`).

### Mesure 11 — Exécution depuis ACR
| Mesure | Valeur |
|---|---|
| Durée du run avec téléchargement | **5,5 s** (`Measure-Command`) — `Unable to find image … locally` puis `Pulling from dermascan-health` : l'image vient bien d'ACR. Digest tiré : `sha256:d16623496590…` (identique au push). Nuance : 1 couche affichée `Already exists` (couche de base Debian partagée avec l'image locale `dermascan-health:naif`, conservée) — le téléchargement est lui aussi incrémental |
| JSON identique à 3.4 ? | **Oui** sur le contenu applicatif : `status: ok`, `service: dermascan-health`, `version: 0.1.0`. Seuls `hostname` et `uptime_seconds` diffèrent (propres à l'instance) — `{"hostname":"52b5c6da9e61","service":"dermascan-health","status":"ok","uptime_seconds":16.4,"version":"0.1.0"}` |
| hostname changé ? | **Oui** : `52b5c6da9e61` (contre `244d17d71fb6` puis `368015522e51` en 3.4/3.5) — nouveau conteneur, nouvelle identité ; l'image, elle, est la même au digest près |

## Partie 5 — Gouvernance

Collecte (07/10/2026) sur l'image tirée d'ACR : `cree=2026-10-06T14:25:04.681244089Z arch=amd64 os=linux user=10001` ; RepoDigest `acrdermascantp42.azurecr.io/dermascan-health@sha256:d16623496590…` ; `Python 3.12.15`. La date de création est celle du build `--no-cache` du 06/10 : les builds suivants, entièrement en cache, ont reproduit le même artefact. Fiche complète : `FICHE_IDENTITE.md`.

**Question 5.1** — `pip freeze` liste **7 paquets** : `blinker==1.9.0`, `click==8.5.0`, `Flask==3.0.3`, `itsdangerous==2.2.0`, `Jinja2==3.1.6`, `MarkupSafe==3.0.4`, `Werkzeug==3.1.9`, contre **1 ligne** dans `requirements.txt` (`Flask==3.0.3`) : **6 paquets supplémentaires**. Ce sont les dépendances **transitives** de Flask (Werkzeug pour le serveur WSGI, Jinja2 et MarkupSafe pour les gabarits, click pour la CLI, itsdangerous pour la signature des cookies, blinker pour les signaux), résolues par pip au moment du build, en prenant les dernières versions compatibles puisqu'elles ne sont pas épinglées. Un audit de licences doit porter sur le `pip freeze` parce que c'est **ce qui est réellement embarqué et redistribué** : le `requirements.txt` n'exprime qu'une intention et ignore 6 composants sur 7 et leurs versions exactes, qui peuvent changer d'un build à l'autre. (Le `pip freeze` lui-même ne couvre que Python : les paquets Debian de l'image de base exigent un inventaire système à part, par exemple un SBOM avec `docker scout sbom` ou Syft.) Au passage, avertissement observé : `/home/appuser/.cache/pip` n'est pas accessible (utilisateur créé sans répertoire personnel), sans incidence sur le service.

**Question 5.2** — Flask : **BSD-3-Clause** (permissive) ; CPython : **PSF License v2** (permissive) ; paquets système de Debian 13 dans l'image de base : majoritairement **GPL-2.0/3.0 et LGPL** (bash, coreutils, glibc…). Ce sont les **licences GPL de la distribution** qui pèsent le plus si DermaScan redistribue l'image à un centre client : donner l'image, c'est distribuer ces binaires, ce qui oblige à fournir ou rendre disponible leur code source correspondant et leurs licences. BSD et PSF exigent seulement de conserver les mentions de copyright.

## Pause du 06/10/2026 — décision tracée
Arrêt volontaire après le premier push (Mesure 10). Pour ne consommer aucun crédit pendant la pause, le groupe `rg-dermascan-registre-tp42` (et donc le registre ACR Basic, ≈ 0,17 $/jour) a été **supprimé** (`az group delete … --no-wait`, confirmé par `az group exists` = `false`). Les images Docker locales (gratuites) sont conservées : à la reprise, le groupe et le registre sont recréés à l'identique et l'image repoussée, avec le **même digest** (contenu adressé par empreinte). Écart assumé à l'énoncé, qui prévoit de conserver le registre.

## Mesure 12 — Nettoyage
| Contrôle | Observation |
|---|---|
| Espace libéré par `docker system prune` | **29,63 MB** (`Total reclaimed space`), après suppression des conteneurs et des images du TP |
| Ressources actives dans $RG | **1** : `acrdermascantp42` (`Microsoft.ContainerRegistry/registries`, `Succeeded`) |
| SKU et coût journalier | **Basic**, ≈ **0,167 $/jour** (≈ 5 $/mois) |
| Date `a_detruire` | **2027-07-31** (tags : `projet=dermascan`, `role=registre`, `proprietaire=theo.pellicano`) — postérieure à la soutenance |
| Groupes de ressources au total | **1** : `rg-dermascan-registre-tp42` |
| Décision fin de séance (07/10) | **Registre conservé** : la séance 2 a lieu le lendemain (coût ≈ 0,15 € pour la nuit, contre 10 min de remise en état et une reconstruction d'image) |
| Crédit restant | _à relever_ (série de relevés : 88,00 € le 06/10 avant création) |

**Question 6.1** — Phrase de ticket : « Le registre ACR `acrdermascantp42` (groupe `rg-dermascan-registre-tp42`, abonnement Azure for Students, SKU Basic, ≈ 0,17 $/jour) doit rester actif **parce qu'**il héberge l'image `dermascan-health` utilisée par les séances 2 à 4 et le projet fil rouge DermaScan ; il peut être détruit **sans me consulter à partir du 31/07/2027** (après la soutenance), par `az group delete --name rg-dermascan-registre-tp42 --yes`, puis vérification par `az group exists` (`false`). Propriétaire : Théo Pellicano. »

**Question 6.2** — `--no-wait` rend la main dès que la demande est acceptée, pas quand la suppression est terminée : pendant plusieurs minutes, le groupe et ses ressources existent encore (et peuvent encore facturer), et la suppression peut aussi échouer (verrou de ressource, dépendance, erreur transitoire) sans que le terminal l'affiche. Considérer la suppression comme acquise à cet instant, c'est risquer de laisser tourner une ressource coûteuse en croyant l'avoir détruite. Vérification réelle : relancer `az group exists --name <rg>` jusqu'à obtenir `false`, puis contrôler `az group list` (et le portail), et vérifier le lendemain que le crédit ne baisse plus. Procédure déjà appliquée lors de la pause du 06/10 (`az group exists` → `false`, `az group list` vide).

## Contrôle d'extinction
| Contrôle | Fait |
|---|---|
| `az group list` ne montre qu'un groupe, celui du registre | ✅ (07/10 : `rg-dermascan-registre-tp42` seul) |
| Aucun conteneur de la séance dans `docker ps -a` | _à confirmer en fin de séance_ |
| Docker Desktop quitté | _à confirmer_ |
| Machine éteinte | _à confirmer_ |
