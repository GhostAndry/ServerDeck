# 🚀 ServerDeck

> **Il pannello di controllo tascabile del tuo homelab.**  
> Unisce il monitoraggio hardware, la gestione Docker e la dashboard dei servizi self-hosted in un'unica app nativa iOS (SwiftUI) alimentata da un leggero agent Go su Debian/Linux.

---

## 🏛️ Architettura

```
┌────────────────────────────────────────┐
│         iPhone (iOS 17+)               │
│      ServerDeck (SwiftUI Native)       │
│  Keychain · URLSession · WebSockets    │
└───────────────────┬────────────────────┘
                    │
                    │ HTTPS / Tailscale VPN (privato & sicuro)
                    ▼
┌────────────────────────────────────────┐
│     srv-01 (Debian GNU/Linux)          │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │   serverdeck-backend (Go)        │  │
│  │   REST API + WebSocket Stream    │  │
│  │   Token Authentication           │  │
│  └───────┬──────────────────┬───────┘  │
│          │                  │          │
│          ▼                  ▼          │
│    Docker Engine         Host OS       │
│  /var/run/docker.sock   /proc, /sys    │
│  (Containers, Logs,     (CPU, RAM,     │
│   Stats, Restarts)       Disks, Net)   │
└────────────────────────────────────────┘
```

---

## 📁 Struttura del Progetto

- **[`backend/`](backend/)**: Backend agent scritto in **Go**.
  - REST API per host overview, container Docker, log live e statistiche.
  - WebSocket per aggiornamenti in tempo reale (host ticks ed eventi container).
  - Probe HTTP per la dashboard dei servizi (`services.yml`).
  - Containerizzabile via Docker Compose con accesso minimale e sicuro.
- **[`ios/`](ios/)**: Applicazione nativa per **iOS** sviluppata in **SwiftUI**.
  - Dashboard overview con gauge CPU, RAM, dischi (`/` e `/mnt/DATA`), rete.
  - Gestione container Docker: filtri per stack Compose, statistiche, riavvio/stop/start, viewer log con ricerca live.
  - Homepage servizi self-hosted (OpenWebUI, Portainer, qBittorrent, ecc.) con ping in tempo reale e quick-launch.
  - Quick Actions & Emergency Sheet per interventi rapidi fuori casa.
  - Supporto Face ID e archiviazione sicura delle credenziali nel Keychain iOS.
- **[`SHARED_SPEC.md`](SHARED_SPEC.md)**: Specifica API e contratti dati condivisi tra backend e client iOS.

---

## ⚡ Quick Start

### 1. Avviare il Backend (su Debian / srv-01)

```bash
cd backend

# Copia la configurazione d'esempio
cp config/services.yml.example config/services.yml

# Avvia con Docker Compose
docker compose up -d --build
```

Oppure in modalità locale Go (dev/test):
```bash
cd backend
go run cmd/server/main.go
```

Il backend sarà disponibile su `http://0.0.0.0:8080` (o sul tuo IP Tailscale).

### 2. Configurare l'App iOS

1. Apri la cartella `ios/` in **Xcode**.
2. Collega il tuo iPhone o avvia il Simulator.
3. Seleziona il tuo **Team di sviluppo personale** (Free Apple Developer Account).
4. Compila ed esegui sull'iPhone.
5. In **Settings** nell'app:
   - Inserisci l'indirizzo del server (es. `http://srv-01:8080` o via IP Tailscale `http://100.x.y.z:8080`).
   - Inserisci il token API configurato nel backend.
   - Premi **Test Connection** per verificare la connessione.

---

## 🔒 Sicurezza e Best Practices

1. **Nessuna porta esposta su Internet**: Comunica con il server esclusivamente tramite la tua rete privata **Tailscale** o WireGuard.
2. **Docker Socket protetto**: Il socket Docker non viene mai esposto direttamente all'esterno; tutte le operazioni passano attraverso l'agent Go con autenticazione via Bearer token / API key.
3. **Credenziali sicure**: I token di autenticazione sull'iPhone sono salvati nell'iOS Keychain con protezione biometrica Face ID / Touch ID.
