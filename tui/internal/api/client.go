package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/jakeprem/ohio_elixir/tui/internal/config"
)

type Client struct {
	baseURL    string
	token      string
	httpClient *http.Client
}

// JSON:API response structures
type JSONAPIResponse struct {
	Data     json.RawMessage `json:"data"`
	Included []Resource      `json:"included,omitempty"`
	Errors   []APIError      `json:"errors,omitempty"`
}

type APIError struct {
	Status string `json:"status"`
	Title  string `json:"title"`
	Detail string `json:"detail"`
}

type Resource struct {
	ID            string          `json:"id"`
	Type          string          `json:"type"`
	Attributes    json.RawMessage `json:"attributes"`
	Relationships json.RawMessage `json:"relationships,omitempty"`
}

// ResourceRelationship represents a relationship in JSON:API
type ResourceRelationship struct {
	Data *ResourceRef `json:"data"`
}

// ResourceRef is a reference to another resource
type ResourceRef struct {
	Type string `json:"type"`
	ID   string `json:"id"`
}

func NewClient() *Client {
	cfg := config.Get()
	return &Client{
		baseURL:    cfg.APIURL,
		token:      cfg.Token,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}
}

func (c *Client) request(method, path string, body io.Reader) (*http.Response, error) {
	url := c.baseURL + path
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Accept", "application/vnd.api+json")
	req.Header.Set("Content-Type", "application/vnd.api+json")

	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}

	return c.httpClient.Do(req)
}

func (c *Client) Get(path string) (*JSONAPIResponse, error) {
	resp, err := c.request("GET", path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized {
		return nil, fmt.Errorf("unauthorized: please run 'ohio login'")
	}

	if resp.StatusCode == http.StatusForbidden {
		return nil, fmt.Errorf("forbidden: you don't have permission for this action")
	}

	var result JSONAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	if len(result.Errors) > 0 {
		return nil, fmt.Errorf("API error: %s - %s", result.Errors[0].Title, result.Errors[0].Detail)
	}

	return &result, nil
}

func (c *Client) Post(path string, body interface{}) (*JSONAPIResponse, error) {
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	resp, err := c.request("POST", path, strings.NewReader(string(jsonBody)))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized {
		return nil, fmt.Errorf("unauthorized: please run 'ohio login'")
	}

	if resp.StatusCode == http.StatusForbidden {
		return nil, fmt.Errorf("forbidden: you don't have permission for this action")
	}

	var result JSONAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	if len(result.Errors) > 0 {
		return nil, fmt.Errorf("API error: %s - %s", result.Errors[0].Title, result.Errors[0].Detail)
	}

	return &result, nil
}

func (c *Client) Patch(path string, body interface{}) (*JSONAPIResponse, error) {
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	resp, err := c.request("PATCH", path, strings.NewReader(string(jsonBody)))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized {
		return nil, fmt.Errorf("unauthorized: please run 'ohio login'")
	}

	if resp.StatusCode == http.StatusForbidden {
		return nil, fmt.Errorf("forbidden: you don't have permission for this action")
	}

	var result JSONAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	if len(result.Errors) > 0 {
		return nil, fmt.Errorf("API error: %s - %s", result.Errors[0].Title, result.Errors[0].Detail)
	}

	return &result, nil
}

func (c *Client) Delete(path string) error {
	resp, err := c.request("DELETE", path, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized {
		return fmt.Errorf("unauthorized: please run 'ohio login'")
	}

	if resp.StatusCode == http.StatusForbidden {
		return fmt.Errorf("forbidden: you don't have permission for this action")
	}

	if resp.StatusCode >= 400 {
		var result JSONAPIResponse
		if err := json.NewDecoder(resp.Body).Decode(&result); err == nil && len(result.Errors) > 0 {
			return fmt.Errorf("API error: %s - %s", result.Errors[0].Title, result.Errors[0].Detail)
		}
		return fmt.Errorf("API error: status %d", resp.StatusCode)
	}

	return nil
}
