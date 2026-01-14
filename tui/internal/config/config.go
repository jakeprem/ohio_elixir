package config

import (
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

type Config struct {
	APIURL string `yaml:"api_url"`
	Token  string `yaml:"token"`
	Email  string `yaml:"email"`
}

var (
	cfg        Config
	configFile string
	apiURLFlag string
)

const defaultAPIURL = "https://ohioelixir.com/api"

func SetConfigFile(path string) {
	configFile = path
}

func SetAPIURL(url string) {
	apiURLFlag = url
}

func configPath() string {
	if configFile != "" {
		return configFile
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}

	return filepath.Join(home, ".ohio_elixir", "config.yaml")
}

func Load() (*Config, error) {
	path := configPath()
	if path == "" {
		cfg = Config{APIURL: defaultAPIURL}
		return &cfg, nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			cfg = Config{APIURL: defaultAPIURL}
			return &cfg, nil
		}
		return nil, err
	}

	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}

	// Apply defaults
	if cfg.APIURL == "" {
		cfg.APIURL = defaultAPIURL
	}

	return &cfg, nil
}

func Save(c *Config) error {
	path := configPath()
	if path == "" {
		return nil
	}

	// Ensure directory exists
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}

	data, err := yaml.Marshal(c)
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0600)
}

func Get() *Config {
	if cfg.APIURL == "" {
		if _, err := Load(); err != nil {
			// Fall back to defaults on error
			cfg = Config{APIURL: defaultAPIURL}
		}
	}

	return &cfg
}

// APIURL returns the API URL with precedence:
// 1. --api-url flag (highest)
// 2. LAZYOH_API_URL env var
// 3. Config file value
// 4. Default (https://ohioelixir.com/api)
func APIURL() string {
	// Flag takes highest precedence
	if apiURLFlag != "" {
		return apiURLFlag
	}

	// Then environment variable
	if envURL := os.Getenv("LAZYOH_API_URL"); envURL != "" {
		return envURL
	}

	// Then config file / default
	return Get().APIURL
}

func Token() string {
	return Get().Token
}

func IsAuthenticated() bool {
	return Get().Token != ""
}
