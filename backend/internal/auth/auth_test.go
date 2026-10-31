package auth

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAuthMiddleware(t *testing.T) {
	secret := "test-secret-12345"
	mw := NewMiddleware(secret, "*")

	handler := mw.RequireAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))

	// 1. Healthz should bypass auth
	reqHealth := httptest.NewRequest("GET", "/healthz", nil)
	rrHealth := httptest.NewRecorder()
	handler.ServeHTTP(rrHealth, reqHealth)
	if rrHealth.Code != http.StatusOK {
		t.Errorf("expected /healthz to bypass auth and return 200, got %d", rrHealth.Code)
	}

	// 2. Missing token should return 401
	reqNoAuth := httptest.NewRequest("GET", "/api/v1/host", nil)
	rrNoAuth := httptest.NewRecorder()
	handler.ServeHTTP(rrNoAuth, reqNoAuth)
	if rrNoAuth.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized, got %d", rrNoAuth.Code)
	}
	var errResp map[string]string
	if err := json.Unmarshal(rrNoAuth.Body.Bytes(), &errResp); err != nil {
		t.Fatalf("failed to decode error json: %v", err)
	}
	if errResp["error"] != "Unauthorized" {
		t.Errorf("expected error 'Unauthorized', got '%s'", errResp["error"])
	}

	// 3. Valid Bearer Token
	reqBearer := httptest.NewRequest("GET", "/api/v1/host", nil)
	reqBearer.Header.Set("Authorization", "Bearer test-secret-12345")
	rrBearer := httptest.NewRecorder()
	handler.ServeHTTP(rrBearer, reqBearer)
	if rrBearer.Code != http.StatusOK {
		t.Errorf("expected 200 OK with Bearer token, got %d", rrBearer.Code)
	}

	// 4. Case-insensitive Bearer prefix
	reqBearerCase := httptest.NewRequest("GET", "/api/v1/host", nil)
	reqBearerCase.Header.Set("Authorization", "bearer test-secret-12345")
	rrBearerCase := httptest.NewRecorder()
	handler.ServeHTTP(rrBearerCase, reqBearerCase)
	if rrBearerCase.Code != http.StatusOK {
		t.Errorf("expected 200 OK with lowercase bearer token, got %d", rrBearerCase.Code)
	}

	// 5. Valid X-API-Key
	reqAPIKey := httptest.NewRequest("GET", "/api/v1/host", nil)
	reqAPIKey.Header.Set("X-API-Key", "test-secret-12345")
	rrAPIKey := httptest.NewRecorder()
	handler.ServeHTTP(rrAPIKey, reqAPIKey)
	if rrAPIKey.Code != http.StatusOK {
		t.Errorf("expected 200 OK with X-API-Key, got %d", rrAPIKey.Code)
	}

	// 6. Valid Query Token (?token=)
	reqQuery := httptest.NewRequest("GET", "/api/v1/events?token=test-secret-12345", nil)
	rrQuery := httptest.NewRecorder()
	handler.ServeHTTP(rrQuery, reqQuery)
	if rrQuery.Code != http.StatusOK {
		t.Errorf("expected 200 OK with ?token query parameter, got %d", rrQuery.Code)
	}

	// 7. Invalid Token
	reqInvalid := httptest.NewRequest("GET", "/api/v1/host", nil)
	reqInvalid.Header.Set("Authorization", "Bearer wrong-token")
	rrInvalid := httptest.NewRecorder()
	handler.ServeHTTP(rrInvalid, reqInvalid)
	if rrInvalid.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for wrong token, got %d", rrInvalid.Code)
	}
}

func TestCORSMiddleware(t *testing.T) {
	mw := NewMiddleware("dummy", "*")
	corsHandler := mw.CORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	// Test OPTIONS preflight
	reqOptions := httptest.NewRequest("OPTIONS", "/api/v1/host", nil)
	rrOptions := httptest.NewRecorder()
	corsHandler.ServeHTTP(rrOptions, reqOptions)

	if rrOptions.Code != http.StatusNoContent {
		t.Errorf("expected OPTIONS to return 204 No Content, got %d", rrOptions.Code)
	}
	if rrOptions.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Errorf("missing Access-Control-Allow-Origin")
	}
	if rrOptions.Header().Get("Access-Control-Allow-Methods") == "" {
		t.Errorf("missing Access-Control-Allow-Methods")
	}
}
