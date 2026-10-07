# 1. Image de base : variante slim, version fixee (jamais latest) -> build reproductible
FROM python:3.12.15-slim

# 2. Repertoire de travail absolu, cree s'il n'existe pas
WORKDIR /app

# 3. Pas de .pyc, logs non tamponnes, port d'ecoute coherent avec EXPOSE et -p
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# 4. Le fichier qui change le moins souvent : la liste des dependances
COPY requirements.txt ./

# 5. Installation des dependances (couche reutilisee tant que requirements.txt ne change pas)
RUN pip install --no-cache-dir -r requirements.txt

# 6. Le code applicatif, qui change a chaque modification : copie le plus tard possible
COPY app.py ./

# 7. Utilisateur non privilegie (uid 10001) proprietaire du repertoire de travail
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser \
    && chown -R appuser:appuser /app

# 8. Bascule : le processus final ne tourne pas en root
USER 10001

# 9. Documentation du port d'ecoute (declaratif, seul -p publie reellement)
EXPOSE 8000

# 10. Processus principal en forme exec : recoit directement SIGTERM a l'arret
CMD ["python", "app.py"]
