# Портфолио

[Version française](README.md)

Сайт-резюме: HTML, CSS и JavaScript без сборки, nginx в Docker, CI/CD через GitHub Actions.

Сайт опубликован на GitHub Pages: https://rogirouge.github.io/portfolio/ (каждый push в `main` публикует его заново). Деплой Docker-образа на свой VPS описан ниже и пока не настроен.

```
git push → GitHub Actions ─┬─ сборка образа
                           ├─ smoke-тест контейнера (healthz, страницы, заголовки, 404)
                           ├─ push в ghcr.io (теги: sha коммита и latest)
                           └─ деплой на VPS по SSH: docker compose pull && up -d
                                         │
                       VPS:  Caddy (80/443, HTTPS) → nginx (8080, без root)
```

## Структура

- `site/` — сам сайт. Текст в `site/index.html`, стили в `site/css/style.css`, скрипты в `site/js/`. Пайплайн перед сборкой вписывает в страницу хеш коммита и дату.
- `nginx/default.conf` — конфиг nginx: кэш, gzip, заголовки безопасности, `/healthz`.
- `Dockerfile` — образ на `nginx-unprivileged` (nginx работает не от root).
- `deploy/` — `docker-compose.yml` и `Caddyfile` для сервера; пайплайн копирует их на VPS.
- `.github/workflows/ci-cd.yml` — пайплайн.

## Локально

Без Docker:

```bash
cd site && python3 -m http.server 8000
```

С Docker:

```bash
docker build -t portfolio .
docker run --rm -p 8080:8080 portfolio
```

Сайт: http://localhost:8080

## Настройка деплоя (один раз)

### 1. GitHub

1. Создать аккаунт на github.com и пустой публичный репозиторий `portfolio`.
2. Отправить код:
   ```bash
   git add -A && git commit -m "Initial commit"
   git remote add origin git@github.com:<логин>/portfolio.git
   git push -u origin main
   ```
   Пайплайн запустится сам. Пока VPS не настроен, он соберёт и проверит образ, опубликует его в ghcr.io, а шаг деплоя пропустит.

### 2. Сервер: Oracle Cloud Always Free

Бесплатно навсегда. Карта нужна только для проверки: временная блокировка $1, деньги не списываются. Аккаунт не переводить на платный (Upgrade), тогда платить ничего не придётся.

**Регистрация.** На oracle.com/cloud/free выбрать **Home Region** рядом, например France Central (Paris) или Germany Central (Frankfurt). Регион потом поменять нельзя, а бесплатные серверы создаются только в нём.

**Ключ SSH.** Создать на своём компьютере до создания сервера:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/portfolio_deploy -N ""
```

**Сервер.** Compute → Instances → Create instance:

- Image: **Canonical Ubuntu 24.04**;
- Shape: **Ampere → VM.Standard.A1.Flex**, 1 OCPU и 6 GB хватит с запасом (бесплатно до 4 OCPU и 24 GB в сумме);
- SSH keys: вставить содержимое `~/.ssh/portfolio_deploy.pub`;
- после создания записать **Public IP**.

Если выпадает ошибка «Out of capacity», значит, бесплатные ARM-серверы в регионе временно закончились. Повтори попытку позже или выбери другой Availability Domain.

**Открыть порты 80 и 443 в облаке.** Instance → Subnet → Security List → Add Ingress Rules: Source `0.0.0.0/0`, TCP, порты `80` и `443`. Без этого сайт снаружи не откроется. Это первая ловушка Oracle.

**Настроить сервер.** Зайти: `ssh -i ~/.ssh/portfolio_deploy ubuntu@<IP>`, затем:

```bash
curl -fsSL https://get.docker.com | sudo sh       # Docker + compose plugin
sudo usermod -aG docker ubuntu

# Вторая ловушка Oracle: в образе Ubuntu iptables по умолчанию закрывает всё, кроме SSH
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

Выйти и зайти снова, чтобы группа `docker` применилась. Проверить: `docker run --rm hello-world`.

### 3. Настройки репозитория

GitHub → репозиторий → Settings → Secrets and variables → Actions:

| Тип | Имя | Значение |
|---|---|---|
| Secret | `VPS_SSH_KEY` | содержимое `~/.ssh/portfolio_deploy` (приватный ключ) |
| Variable | `VPS_HOST` | IP сервера |
| Variable | `VPS_USER` | `ubuntu` |
| Variable | `SITE_ADDRESS` | необязательно: домен, например `igorbelyaev.fr` |
| Variable | `SITE_URL` | необязательно: `https://igorbelyaev.fr` |

После этого любой push в `main` выкатывает сайт. Перезапустить вручную: Actions → CI/CD → Run workflow.

### 4. Домен и HTTPS (по желанию)

Купить домен, создать A-запись на IP сервера, заполнить `SITE_ADDRESS` и `SITE_URL`. Caddy сам получит и будет продлевать сертификат Let's Encrypt.

## Откат

Каждый образ помечен sha коммита. На сервере:

```bash
cd ~/portfolio
sed -i 's/^IMAGE=.*/IMAGE=ghcr.io\/<логин>\/portfolio:<старый sha>/' .env
docker compose up -d
```
