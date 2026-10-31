package auth

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/json"
	"net/http"
	"path"
	"strings"
)

// Middleware provides authentication, CORS, and security checks.
type Middleware struct {
	token          string
	allowedOrigins string
}

// NewMiddleware creates an authentication and CORS middleware with the specified token.
func NewMiddleware(token, allowedOrigins string) *Middleware {
	if allowedOrigins == "" {
		allowedOrigins = "*"
	}
	return &Middleware{
		token:          strings.TrimSpace(token),
		allowedOrigins: allowedOrigins,
	}
}

// RequireAuth wraps an http.Handler and enforces Bearer token or X-API-Key authentication.
func (m *Middleware) RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Clean and normalize path for comparison
		cleanedPath := path.Clean(r.URL.Path)

		// Bypass unauthenticated endpoints and CORS preflight
		if cleanedPath == "/healthz" || r.Method == http.MethodOptions {
			next.ServeHTTP(w, r)
			return
		}

		if !m.ValidateRequest(r) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]string{
				"error": "Unauthorized",
			})
			return
		}

		next.ServeHTTP(w, r)
	})
}

// ValidateRequest checks if the request has a valid token using constant-time hash comparison.
func (m *Middleware) ValidateRequest(r *http.Request) bool {
	if m.token == "" {
		return false
	}

	extracted := ExtractToken(r)
	if extracted == "" {
		return false
	}

	// Constant-time comparison using SHA-256 digests prevents timing attacks and length-leakage attacks
	h1 := sha256.Sum256([]byte(extracted))
	h2 := sha256.Sum256([]byte(m.token))
	return subtle.ConstantTimeCompare(h1[:], h2[:]) == 1
}

// ExtractToken retrieves the auth token securely.
func ExtractToken(r *http.Request) string {
	// 1. Authorization: Bearer <TOKEN>
	if authHeader := r.Header.Get("Authorization"); authHeader != "" {
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) == 2 && strings.EqualFold(parts[0], "Bearer") {
			if token := strings.TrimSpace(parts[1]); token != "" {
				return token
			}
		}
	}

	// 2. X-API-Key: <TOKEN>
	if apiKey := r.Header.Get("X-API-Key"); apiKey != "" {
		if token := strings.TrimSpace(apiKey); token != "" {
			return token
		}
	}

	// 3. Query param: ?token=<TOKEN> (Strictly restricted to WebSocket upgrade to prevent URL token leakage in logs)
	cleanedPath := path.Clean(r.URL.Path)
	if cleanedPath == "/api/v1/events" {
		if queryToken := r.URL.Query().Get("token"); queryToken != "" {
			return strings.TrimSpace(queryToken)
		}
	}

	return ""
}

// CORS wraps an http.Handler with Cross-Origin Resource Sharing headers.
func (m *Middleware) CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", m.allowedOrigins)
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Accept, Authorization, Content-Type, X-API-Key")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}
