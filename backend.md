La struttura aggiornata sarebbe questa:

```
iPhone (ServerDeck / SwiftUI)
          │
          │ HTTPS / Tailscale
          ▼
┌──────────────────────────────┐
│ Docker: serverdeck-backend   │
│                              │
│ REST API + WebSocket         │
│ Autenticazione               │
│ Docker Engine API client     │
│ Metriche host                │
└──────────────┬───────────────┘
               │
               │ /var/run/docker.sock
               ▼
          Docker Engine
               │
       ┌───────┴────────┐
       │                │
   Container       Altri stack
   ServerDeck      OpenWebUI, Films...
```

Una precisazione importante: montare `/var/run/docker.sock` nel backend permette di gestire praticamente tutto Docker, ma equivale a concedere privilegi molto elevati sull'host. Il backend dovrà quindi essere protetto con autenticazione, operazioni autorizzate e accesso esclusivamente tramite la rete privata.

## 1. Stack Docker aggiornato

Per il tuo Debian, metterei tutto in `/mnt/DATA/serverdeck/`, usando Docker Compose e immagini aggiornabili.

```
/mnt/DATA/serverdeck/
├── compose.yml
├── .env
├── backend/
│   ├── Dockerfile
│   ├── go.mod
│   └── cmd/
├── config/
│   └── services.yml
└── data/
    └── serverdeck.db
```

### 2. Componenti del backend

| Componente     | Tecnologia                  | Funzione                                     |
| -------------- | --------------------------- | -------------------------------------------- |
| API            | Go + REST                   | Comunica con l'app iOS                       |
| Docker         | Docker Engine API           | Container, log, stats, start/stop/restart    |
| Metriche       | `/proc`, `/sys`, filesystem | CPU, RAM, dischi e uptime                    |
| Real-time      | WebSocket                   | Aggiornamento live di log e statistiche      |
| Configurazione | YAML + SQLite               | Servizi preferiti, impostazioni e storico    |
| Sicurezza      | Token + TLS                 | Autenticazione e protezione delle operazioni |

Per le metriche dell'host monterei le risorse necessarie in sola lettura. Il backend deve distinguere chiaramente le metriche del container da quelle dell'intero server.

## 3. Compose del backend

Questa è la base del servizio, da integrare nel compose definitivo quando implementeremo l'agent.

```

services:
  serverdeck-backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: serverdeck-backend
    restart: unless-stopped
    init: true

    environment:
      TZ: Europe/Rome
      SERVERDECK_LISTEN: "0.0.0.0:8080"
      SERVERDECK_CONFIG: /app/config/services.yml
      SERVERDECK_DB: /app/data/serverdeck.db

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /mnt/DATA/serverdeck/config:/app/config:ro
      - /mnt/DATA/serverdeck/data:/app/data

    networks:
      - serverdeck

    # Nessuna porta pubblicata sull'host.
    # Accesso tramite Tailscale e reverse proxy autenticato.

    security_opt:
      - no-new-privileges:true

    cap_drop:
      - ALL

networks:
  serverdeck:
    driver: bridge

```

Attenzione: questo è uno scheletro infrastrutturale, non un backend già funzionante. Mancano il Dockerfile, il codice API, l'autenticazione e la configurazione di accesso remoto.

Inoltre, `:ro` sul mount del socket impedisce di modificare il file del socket dal container, ma non rende read-only le operazioni Docker. Chi può inviare richieste al daemon tramite quel socket può ancora avviare container privilegiati e compromettere l'host.

Per una versione realmente distribuibile, preferirei un Docker Socket Proxy con endpoint esplicitamente autorizzati e backend non esposto direttamente. Anche così, le operazioni abilitate vanno limitate e protette.

## 4. Le API che esporrei

| Endpoint                               | Funzione                     |
| -------------------------------------- | ---------------------------- |
| `GET /api/v1/host`                     | Stato del server             |
| `GET /api/v1/containers`               | Lista dei container          |
| `GET /api/v1/containers/{id}/stats`    | Metriche del container       |
| `GET /api/v1/containers/{id}/logs`     | Log                          |
| `POST /api/v1/containers/{id}/restart` | Riavvio                      |
| `POST /api/v1/containers/{id}/start`   | Avvio                        |
| `POST /api/v1/containers/{id}/stop`    | Arresto                      |
| `GET /api/v1/services`                 | Homepage e stato dei servizi |
| `GET /api/v1/events`                   | Eventi live via WebSocket    |

Il backend dovrebbe validare gli ID dei container, applicare autorizzazioni per ciascuna operazione e non consentire API arbitrarie verso Docker.

La configurazione che sceglierei: Go per il backend, SwiftUI per iOS, Docker Compose su `srv-01`, Tailscale per l'accesso remoto e proxy del socket con permessi minimi. Così ServerDeck resta indipendente da Portainer, ma può convivere con tutti gli stack già presenti sul server. 🔥