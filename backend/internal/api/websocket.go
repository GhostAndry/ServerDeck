package api

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/serverdeck/serverdeck-backend/internal/docker"
	"github.com/serverdeck/serverdeck-backend/internal/metrics"
)

const (
	// Time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// Send pings to peer with this period. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer.
	maxMessageSize = 512
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Homelab / Tailscale friendly
	},
}

// WebSocketMessage matches the event envelope specified in SHARED_SPEC.md.
type WebSocketMessage struct {
	Type      string `json:"type"`
	Timestamp int64  `json:"timestamp"`
	Data      any    `json:"data"`
}

// WSClient wraps a connected WebSocket client.
type WSClient struct {
	hub  *WSHub
	conn *websocket.Conn
	send chan []byte
}

func (c *WSClient) readPump() {
	defer func() {
		c.hub.unregister <- c
		_ = c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, _, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[WebSocket] Client read error: %v", err)
			}
			break
		}
	}
}

func (c *WSClient) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		_ = c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// The hub closed the channel.
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			_, _ = w.Write(message)

			// Add queued chat messages to the current websocket message.
			n := len(c.send)
			for i := 0; i < n; i++ {
				_, _ = w.Write([]byte{'\n'})
				_, _ = w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// WSHub coordinates active WebSocket connections and broadcasts.
type WSHub struct {
	clients    map[*WSClient]bool
	broadcast  chan []byte
	register   chan *WSClient
	unregister chan *WSClient
	mu         sync.RWMutex
}

// NewWSHub creates a new WebSocket Hub.
func NewWSHub() *WSHub {
	return &WSHub{
		broadcast:  make(chan []byte, 256),
		register:   make(chan *WSClient),
		unregister: make(chan *WSClient),
		clients:    make(map[*WSClient]bool),
	}
}

// Run begins the hub event loop.
func (h *WSHub) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			h.mu.Lock()
			for client := range h.clients {
				close(client.send)
				_ = client.conn.Close()
				delete(h.clients, client)
			}
			h.mu.Unlock()
			return

		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			h.mu.Unlock()

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mu.RUnlock()
		}
	}
}

// BroadcastEvent sends an event envelope to all connected clients.
func (h *WSHub) BroadcastEvent(eventType string, data any) {
	msg := WebSocketMessage{
		Type:      eventType,
		Timestamp: time.Now().Unix(),
		Data:      data,
	}

	payload, err := json.Marshal(msg)
	if err != nil {
		log.Printf("[WebSocket] Failed to marshal event %s: %v", eventType, err)
		return
	}

	select {
	case h.broadcast <- payload:
	default:
	}
}

// BroadcastHostTick broadcasts the periodic host_tick event.
func (h *WSHub) BroadcastHostTick(overview *metrics.HostOverview) {
	h.BroadcastEvent("host_tick", overview)
}

// BroadcastContainerEvent broadcasts a container lifecycle event.
func (h *WSHub) BroadcastContainerEvent(event docker.ContainerEventData) {
	h.BroadcastEvent("container_event", event)
}

// ConnectedClientsCount returns current number of active connections.
func (h *WSHub) ConnectedClientsCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}
