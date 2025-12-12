package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestHandleRoot(t *testing.T) {
	tests := []struct {
		name       string
		headers    map[string]string
		expectedIP string
	}{
		{
			name:       "Direct connection",
			headers:    map[string]string{},
			expectedIP: "", // Will be set by httptest
		},
		{
			name: "X-Forwarded-For header",
			headers: map[string]string{
				"X-Forwarded-For": "203.0.113.42",
			},
			expectedIP: "203.0.113.42",
		},
		{
			name: "X-Real-IP header",
			headers: map[string]string{
				"X-Real-IP": "198.51.100.23",
			},
			expectedIP: "198.51.100.23",
		},
		{
			name: "Multiple IPs in X-Forwarded-For",
			headers: map[string]string{
				"X-Forwarded-For": "203.0.113.42, 198.51.100.23, 192.0.2.1",
			},
			expectedIP: "203.0.113.42",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a request
			req := httptest.NewRequest(http.MethodGet, "/", nil)

			// Set headers
			for key, value := range tt.headers {
				req.Header.Set(key, value)
			}

			// Create a response recorder
			rr := httptest.NewRecorder()

			// Call the handler
			handleRoot(rr, req)

			// Check status code
			if status := rr.Code; status != http.StatusOK {
				t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
			}

			// Check content type
			contentType := rr.Header().Get("Content-Type")
			if contentType != "application/json" {
				t.Errorf("handler returned wrong content type: got %v want %v", contentType, "application/json")
			}

			// Parse response
			var response TimeResponse
			if err := json.NewDecoder(rr.Body).Decode(&response); err != nil {
				t.Fatalf("Failed to decode response: %v", err)
			}

			// Check timestamp format
			if _, err := time.Parse(time.RFC3339Nano, response.Timestamp); err != nil {
				t.Errorf("Invalid timestamp format: %v", err)
			}

			// Check IP address
			if tt.expectedIP != "" && response.IP != tt.expectedIP {
				t.Errorf("handler returned wrong IP: got %v want %v", response.IP, tt.expectedIP)
			}

			// Verify IP is not empty
			if response.IP == "" {
				t.Error("IP address should not be empty")
			}
		})
	}
}

func TestHandleHealth(t *testing.T) {
	// Create a request
	req := httptest.NewRequest(http.MethodGet, "/health", nil)

	// Create a response recorder
	rr := httptest.NewRecorder()

	// Call the handler
	handleHealth(rr, req)

	// Check status code
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	// Check content type
	contentType := rr.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("handler returned wrong content type: got %v want %v", contentType, "application/json")
	}

	// Parse response
	var response HealthResponse
	if err := json.NewDecoder(rr.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	// Check status
	if response.Status != "healthy" {
		t.Errorf("handler returned wrong status: got %v want %v", response.Status, "healthy")
	}
}

func TestGetClientIP(t *testing.T) {
	tests := []struct {
		name       string
		headers    map[string]string
		remoteAddr string
		expectedIP string
	}{
		{
			name:       "X-Forwarded-For takes precedence",
			headers:    map[string]string{"X-Forwarded-For": "203.0.113.42"},
			remoteAddr: "192.0.2.1:12345",
			expectedIP: "203.0.113.42",
		},
		{
			name:       "X-Real-IP if no X-Forwarded-For",
			headers:    map[string]string{"X-Real-IP": "198.51.100.23"},
			remoteAddr: "192.0.2.1:12345",
			expectedIP: "198.51.100.23",
		},
		{
			name:       "RemoteAddr if no headers",
			headers:    map[string]string{},
			remoteAddr: "192.0.2.1:12345",
			expectedIP: "192.0.2.1",
		},
		{
			name: "Multiple IPs in X-Forwarded-For",
			headers: map[string]string{
				"X-Forwarded-For": "203.0.113.42, 198.51.100.23, 192.0.2.1",
			},
			remoteAddr: "10.0.0.1:12345",
			expectedIP: "203.0.113.42",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			req.RemoteAddr = tt.remoteAddr

			for key, value := range tt.headers {
				req.Header.Set(key, value)
			}

			ip := getClientIP(req)
			if ip != tt.expectedIP {
				t.Errorf("getClientIP() = %v, want %v", ip, tt.expectedIP)
			}
		})
	}
}

func BenchmarkHandleRoot(b *testing.B) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("X-Forwarded-For", "203.0.113.42")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		rr := httptest.NewRecorder()
		handleRoot(rr, req)
	}
}

