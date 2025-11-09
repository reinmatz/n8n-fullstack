# SSH Setup für GitHub

Diese Anleitung zeigt, wie Sie SSH-Keys für GitHub einrichten und das Projekt hochladen.

## 1. SSH-Key generieren

Falls Sie noch keinen SSH-Key haben:

```bash
# Neuen SSH-Key erstellen
ssh-keygen -t ed25519 -C "ihre.email@example.com"

# Oder RSA verwenden (falls ed25519 nicht unterstützt wird)
ssh-keygen -t rsa -b 4096 -C "ihre.email@example.com"

# Standardpfad akzeptieren: ~/.ssh/id_ed25519 (oder ~/.ssh/id_rsa)
# Optional: Passphrase eingeben für zusätzliche Sicherheit
```

## 2. SSH-Key zu GitHub hinzufügen

```bash
# Public Key anzeigen und kopieren (macOS)
cat ~/.ssh/id_ed25519.pub | pbcopy

# Oder manuell anzeigen
cat ~/.ssh/id_ed25519.pub
```

**In GitHub:**
1. Gehen Sie zu: https://github.com/settings/keys
2. Klicken Sie auf "New SSH key"
3. Titel: z.B. "MacBook M1" oder "Work Laptop"
4. Key: Fügen Sie den kopierten Public Key ein
5. Klicken Sie auf "Add SSH key"

## 3. SSH-Verbindung testen

```bash
# Verbindung zu GitHub testen
ssh -T git@github.com

# Erwartete Ausgabe:
# Hi USERNAME! You've successfully authenticated, but GitHub does not provide shell access.
```

## 4. Repository auf GitHub erstellen

**Via GitHub Web Interface:**
1. Gehen Sie zu: https://github.com/new
2. Repository Name: `n8n-rag` (oder beliebiger Name)
3. Beschreibung: "Local self-hosted RAG system with n8n, Qdrant, Ollama"
4. Wählen Sie: **Private** oder **Public**
5. **WICHTIG:** Keine README, .gitignore oder License hinzufügen (existiert bereits lokal)
6. Klicken Sie auf "Create repository"

## 5. Lokales Repository mit GitHub verbinden

```bash
# Wechseln Sie ins Projektverzeichnis
cd /Users/reinhard/n8n/n8n-rag

# Remote Repository hinzufügen (SSH-URL von GitHub kopieren)
git remote add origin git@github.com:USERNAME/n8n-rag.git

# Überprüfen
git remote -v
```

## 6. Erste Commit und Push

```bash
# Git-Benutzername und E-Mail konfigurieren (falls noch nicht geschehen)
git config --global user.name "Ihr Name"
git config --global user.email "ihre.email@example.com"

# Dateien zum Staging hinzufügen
git add .

# Ersten Commit erstellen
git commit -m "Initial commit: n8n-RAG system with Docker Compose

- Full local RAG stack with n8n, Qdrant, Ollama, Docling
- Observability stack (Prometheus, Grafana, Loki, Tempo)
- German language optimization
- Multi-format document support (PDF, DOCX, XLSX, MD, TXT)
- Complete documentation and setup scripts"

# Zum Main-Branch umbenennen (falls nötig)
git branch -M main

# Zu GitHub pushen
git push -u origin main
```

## 7. Zukünftige Updates pushen

```bash
# Status prüfen
git status

# Geänderte Dateien hinzufügen
git add .

# Commit erstellen
git commit -m "Beschreibung der Änderungen"

# Pushen
git push
```

## Wichtige Hinweise

### .env Datei (Credentials)
Die `.env` Datei wird **automatisch ignoriert** (via `.gitignore`) und **nicht zu GitHub hochgeladen**. Dies schützt Ihre Zugangsdaten.

### Dateien die NICHT hochgeladen werden:
- `data/` - Persistente Datenbanken und Volumes
- `.env` - Credentials
- Observability Logs
- Shared/Temporary Files
- macOS `.DS_Store` Dateien

### Weitere nützliche Git-Befehle

```bash
# Änderungen anzeigen
git diff

# Commit-Historie anzeigen
git log --oneline

# Letzten Commit ändern (vor push)
git commit --amend

# Branch erstellen und wechseln
git checkout -b feature-name

# Branches anzeigen
git branch -a

# Remote-URL ändern
git remote set-url origin git@github.com:USERNAME/neuer-name.git
```

## Troubleshooting

### "Permission denied (publickey)"
```bash
# SSH-Agent starten
eval "$(ssh-agent -s)"

# Key zum Agent hinzufügen
ssh-add ~/.ssh/id_ed25519

# Nochmal testen
ssh -T git@github.com
```

### "Repository not found"
- Überprüfen Sie die Remote-URL: `git remote -v`
- Stellen Sie sicher, dass das Repository auf GitHub existiert
- Überprüfen Sie den USERNAME in der URL

### Große Dateien (> 100MB)
GitHub hat ein Dateilimit von 100MB. Falls nötig:
```bash
# Git LFS installieren (für große Dateien)
brew install git-lfs  # macOS
git lfs install

# Große Dateien tracken
git lfs track "*.bin"
git add .gitattributes
```

## Alternative: HTTPS statt SSH

Falls SSH Probleme macht:

```bash
# HTTPS Remote hinzufügen
git remote add origin https://github.com/USERNAME/n8n-rag.git

# Push (Username/Password oder Personal Access Token erforderlich)
git push -u origin main
```

**Hinweis:** Für HTTPS benötigen Sie einen Personal Access Token:
https://github.com/settings/tokens
