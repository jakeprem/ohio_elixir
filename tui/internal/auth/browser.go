package auth

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/jakeprem/ohio_elixir/tui/internal/config"
	"github.com/pkg/browser"
)

type PollResponse struct {
	Status string `json:"status"`
	Token  string `json:"token,omitempty"`
	Email  string `json:"email,omitempty"`
	Error  string `json:"error,omitempty"`
}

// GenerateCode creates a random authentication code
func GenerateCode() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// BuildAuthURL constructs the browser URL for authentication
func BuildAuthURL(code string) string {
	apiURL := config.APIURL()
	// Safely remove /api suffix to get base URL
	baseURL := strings.TrimSuffix(apiURL, "/api")
	if baseURL == apiURL {
		// URL didn't have /api suffix, try without trailing slash
		baseURL = strings.TrimSuffix(apiURL, "/")
	}
	return fmt.Sprintf("%s/cli/auth?code=%s", baseURL, url.QueryEscape(code))
}

// OpenBrowser opens the authentication URL in the default browser
func OpenBrowser(url string) error {
	return browser.OpenURL(url)
}

// PollForToken polls the API for authentication completion
func PollForToken(code string, timeout time.Duration, interval time.Duration) (*PollResponse, error) {
	apiURL := config.APIURL()
	pollURL := fmt.Sprintf("%s/cli/auth/poll?code=%s", apiURL, url.QueryEscape(code))

	deadline := time.Now().Add(timeout)
	client := &http.Client{Timeout: 10 * time.Second}

	notFoundCount := 0
	maxNotFound := 3 // Allow a few not_found before giving up (race condition handling)

	for time.Now().Before(deadline) {
		resp, err := client.Get(pollURL)
		if err != nil {
			fmt.Printf("Poll error: %v\n", err)
			time.Sleep(interval)
			continue
		}

		var pollResp PollResponse
		if err := json.NewDecoder(resp.Body).Decode(&pollResp); err != nil {
			resp.Body.Close()
			time.Sleep(interval)
			continue
		}
		resp.Body.Close()

		switch pollResp.Status {
		case "complete":
			return &pollResp, nil
		case "pending":
			notFoundCount = 0 // Reset counter when we get a valid pending
			time.Sleep(interval)
			continue
		case "not_found":
			notFoundCount++
			if notFoundCount > maxNotFound {
				return nil, fmt.Errorf("authentication code not found after %d attempts", notFoundCount)
			}
			time.Sleep(interval)
			continue
		default:
			return nil, fmt.Errorf("unexpected status: %s", pollResp.Status)
		}
	}

	return nil, fmt.Errorf("authentication timed out - please try again")
}

// Login performs the full browser-based login flow
func Login() (string, string, error) {
	code, err := GenerateCode()
	if err != nil {
		return "", "", fmt.Errorf("failed to generate auth code: %w", err)
	}

	authURL := BuildAuthURL(code)

	fmt.Println("Opening browser to authenticate...")
	fmt.Printf("If browser doesn't open, visit:\n  %s\n\n", authURL)

	if err := OpenBrowser(authURL); err != nil {
		// Browser failed to open, but user can manually visit URL
		fmt.Println("Could not open browser automatically.")
	}

	fmt.Println("Waiting for authentication...")

	// Give the browser a moment to open and register the code
	time.Sleep(1 * time.Second)

	resp, err := PollForToken(code, 10*time.Minute, 2*time.Second)
	if err != nil {
		return "", "", err
	}

	return resp.Token, resp.Email, nil
}
