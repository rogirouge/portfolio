# Portfolio — Igor Belyaev

[Версия на русском](README.ru.md)

Site personnel d'un étudiant en troisième année d'informatique (Université de Lille × USTH, Hanoï)
qui se prépare à un master orienté cloud et DevOps.

Le site sert aussi de terrain d'entraînement : il est écrit à la main (HTML, CSS et JavaScript, sans framework
ni étape de build), empaqueté dans une image Docker et publié automatiquement à chaque `git push`.

**En ligne :** https://rogirouge.github.io/portfolio/

## Pipeline

```
git push ─→ GitHub Actions
             ├─ build de l'image Docker (nginx sans les droits root), amd64 et arm64
             ├─ test de fumée du conteneur : /healthz, pages, en-têtes de sécurité, page 404
             ├─ publication de l'image sur ghcr.io (tags : hash du commit et latest)
             ├─ publication du site sur GitHub Pages (la page affiche le commit et la date de la version)
             └─ déploiement sur un VPS par SSH (prévu, pas encore configuré)
```

Dependabot propose chaque semaine les nouvelles versions des actions utilisées par le pipeline.

## Organisation du dépôt

- `site/` : le site (`index.html`, `404.html`, `css/`, `js/`, `img/`).
- `nginx/default.conf` : cache, gzip, en-têtes de sécurité (dont la CSP), `/healthz`, page 404.
- `Dockerfile` : image basée sur `nginxinc/nginx-unprivileged`, nginx ne tourne pas en root.
- `deploy/` : `docker-compose.yml` et `Caddyfile` pour le serveur ; Caddy gère le HTTPS.
- `.github/workflows/ci-cd.yml` : le pipeline ; `.github/stamp-version.sh` inscrit le commit dans la page ;
  `.github/dependabot.yml` : mises à jour des actions.

## Lancer en local

Sans Docker :

```bash
cd site && python3 -m http.server 8000
```

Avec Docker, avec les mêmes restrictions que dans le test de la CI :

```bash
docker build -t portfolio .
docker run --rm -p 8080:8080 --read-only --tmpfs /tmp --cap-drop ALL portfolio
```

Le site est alors sur http://localhost:8080.

## Déploiement sur un serveur (optionnel)

Le job `deploy` ne tourne que si la variable `VPS_HOST` est définie dans le dépôt. Il copie `deploy/` sur le serveur,
récupère l'image du commit et redémarre les conteneurs avec Docker Compose ; Caddy obtient et renouvelle le certificat HTTPS.

Paramètres (Settings → Secrets and variables → Actions) : le secret `VPS_SSH_KEY`, les variables `VPS_HOST` et `VPS_USER`,
et, si un domaine est utilisé, `SITE_ADDRESS` et `SITE_URL`. Le guide pas à pas pour un serveur Oracle Cloud Always Free
est dans la [version russe](README.ru.md#2-сервер-oracle-cloud-always-free).

## Revenir à une version précédente

Chaque image porte le hash de son commit. Sur le serveur :

```bash
cd ~/portfolio
sed -i 's|^IMAGE=.*|IMAGE=ghcr.io/rogirouge/portfolio:<ancien hash>|' .env
docker compose up -d
```

## Crédits

Photos : Wikimedia Commons ; les auteurs et les licences sont indiqués en bas de la page.
