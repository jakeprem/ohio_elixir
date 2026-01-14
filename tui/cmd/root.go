package cmd

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
	"github.com/jakeprem/ohio_elixir/tui/internal/config"
	"github.com/jakeprem/ohio_elixir/tui/internal/tui"
	"github.com/spf13/cobra"
)

var cfgFile string

var rootCmd = &cobra.Command{
	Use:   "ohio",
	Short: "Ohio Elixir admin CLI",
	Long: `Ohio is a CLI tool for managing Ohio Elixir events, venues, and RSVPs.

Use 'ohio login' to authenticate, then manage resources with subcommands
like 'ohio events' and 'ohio venues'.

Running 'ohio' without arguments opens the interactive TUI.`,
	Run: func(cmd *cobra.Command, args []string) {
		// Launch interactive TUI
		client := api.NewClient()
		app := tui.NewApp(client)

		p := tea.NewProgram(
			app,
			tea.WithAltScreen(),
		)

		if _, err := p.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "Error running TUI: %v\n", err)
			os.Exit(1)
		}
	},
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	cobra.OnInitialize(initConfig)

	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.ohio_elixir/config.yaml)")
	rootCmd.PersistentFlags().StringP("api-url", "u", "", "API URL (default: https://ohioelixir.com/api)")
}

func initConfig() {
	if cfgFile != "" {
		config.SetConfigFile(cfgFile)
	}

	if apiURL, _ := rootCmd.Flags().GetString("api-url"); apiURL != "" {
		config.SetAPIURL(apiURL)
	}
}
