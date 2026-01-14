package cmd

import (
	"fmt"
	"os"

	"github.com/jakeprem/ohio_elixir/tui/internal/auth"
	"github.com/jakeprem/ohio_elixir/tui/internal/config"
	"github.com/spf13/cobra"
)

var loginCmd = &cobra.Command{
	Use:   "login",
	Short: "Authenticate with Ohio Elixir",
	Long: `Opens your browser to authenticate with Ohio Elixir.

After signing in, your credentials will be saved locally
and used for subsequent commands.`,
	Run: func(cmd *cobra.Command, args []string) {
		cfg, err := config.Load()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}

		if cfg.Token != "" {
			fmt.Printf("Already logged in as %s\n", cfg.Email)
			fmt.Println("Use 'ohio logout' to sign out first.")
			return
		}

		token, email, err := auth.Login()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Authentication failed: %v\n", err)
			os.Exit(1)
		}

		cfg.Token = token
		cfg.Email = email

		if err := config.Save(cfg); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to save credentials: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("\n✓ Logged in as %s\n", email)
	},
}

var logoutCmd = &cobra.Command{
	Use:   "logout",
	Short: "Sign out of Ohio Elixir",
	Long:  `Removes your saved credentials from this machine.`,
	Run: func(cmd *cobra.Command, args []string) {
		cfg, err := config.Load()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}

		if cfg.Token == "" {
			fmt.Println("Not logged in.")
			return
		}

		email := cfg.Email
		cfg.Token = ""
		cfg.Email = ""

		if err := config.Save(cfg); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to save config: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("✓ Logged out from %s\n", email)
	},
}

var whoamiCmd = &cobra.Command{
	Use:   "whoami",
	Short: "Show current logged in user",
	Run: func(cmd *cobra.Command, args []string) {
		cfg, err := config.Load()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}

		if cfg.Token == "" {
			fmt.Println("Not logged in. Run 'ohio login' to authenticate.")
			os.Exit(1)
		}

		fmt.Printf("Logged in as %s\n", cfg.Email)
		fmt.Printf("API: %s\n", config.APIURL())
	},
}

func init() {
	rootCmd.AddCommand(loginCmd)
	rootCmd.AddCommand(logoutCmd)
	rootCmd.AddCommand(whoamiCmd)
}
