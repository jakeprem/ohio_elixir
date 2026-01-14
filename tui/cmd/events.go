package cmd

import (
	"fmt"
	"os"
	"text/tabwriter"

	"github.com/jakeprem/ohio_elixir/tui/internal/api"
	"github.com/jakeprem/ohio_elixir/tui/internal/config"
	"github.com/jakeprem/ohio_elixir/tui/internal/ui"
	"github.com/spf13/cobra"
)

var eventsCmd = &cobra.Command{
	Use:   "events",
	Short: "Manage events",
	Long:  `List, view, create, and manage Ohio Elixir events.`,
	Run: func(cmd *cobra.Command, args []string) {
		// Default to list
		listEventsCmd.Run(cmd, args)
	},
}

var listEventsCmd = &cobra.Command{
	Use:   "list",
	Short: "List all events",
	Run: func(cmd *cobra.Command, args []string) {
		client := api.NewClient()
		events, err := client.ListEvents()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		if len(events) == 0 {
			fmt.Println("No events found.")
			return
		}

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "ID\tTITLE\tSTATUS\tFORMAT\tDATE")
		fmt.Fprintln(w, "--\t-----\t------\t------\t----")

		for _, e := range events {
			date := "N/A"
			if e.StartsAt != nil {
				date = e.StartsAt.Format("2006-01-02 15:04")
			}
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", e.ID, e.Title, e.Status, e.Format, date)
		}
		w.Flush()
	},
}

var showEventCmd = &cobra.Command{
	Use:   "show [id]",
	Short: "Show event details",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		client := api.NewClient()
		event, err := client.GetEvent(args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("Title: %s\n", event.Title)
		fmt.Printf("ID: %s\n", event.ID)
		fmt.Printf("Status: %s\n", event.Status)
		fmt.Printf("Format: %s\n", event.Format)

		if event.StartsAt != nil {
			fmt.Printf("Starts: %s\n", event.StartsAt.Format("2006-01-02 15:04 MST"))
		}
		if event.EndsAt != nil {
			fmt.Printf("Ends: %s\n", event.EndsAt.Format("2006-01-02 15:04 MST"))
		}
		if event.Timezone != "" {
			fmt.Printf("Timezone: %s\n", event.Timezone)
		}
		if event.MeetingURL != "" {
			fmt.Printf("Meeting URL: %s\n", event.MeetingURL)
		}
		if event.Capacity != nil {
			fmt.Printf("Capacity: %d\n", *event.Capacity)
		}
		if event.ShortDescription != "" {
			fmt.Printf("\nShort Description:\n%s\n", event.ShortDescription)
		}
		if event.Description != "" {
			fmt.Printf("\nDescription:\n%s\n", event.Description)
		}
	},
}

var publishEventCmd = &cobra.Command{
	Use:   "publish [id]",
	Short: "Publish an event",
	Long:  `Publish a draft event to make it publicly visible.`,
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !config.IsAuthenticated() {
			fmt.Fprintln(os.Stderr, "Error: Not logged in. Run 'ohio login' first.")
			os.Exit(1)
		}

		client := api.NewClient()
		event, err := client.PublishEvent(args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("✓ Published: %s\n", event.Title)
	},
}

var cancelEventCmd = &cobra.Command{
	Use:   "cancel [id]",
	Short: "Cancel an event",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !config.IsAuthenticated() {
			fmt.Fprintln(os.Stderr, "Error: Not logged in. Run 'ohio login' first.")
			os.Exit(1)
		}

		client := api.NewClient()
		event, err := client.CancelEvent(args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("✓ Cancelled: %s\n", event.Title)
	},
}

var editEventCmd = &cobra.Command{
	Use:   "edit [id]",
	Short: "Edit event description in external editor",
	Long: `Opens the event description in your $EDITOR.
Save and quit to update the event.`,
	Args: cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !config.IsAuthenticated() {
			fmt.Fprintln(os.Stderr, "Error: Not logged in. Run 'ohio login' first.")
			os.Exit(1)
		}

		client := api.NewClient()

		// Fetch current event
		event, err := client.GetEvent(args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error fetching event: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("Editing: %s\n", event.Title)
		fmt.Println("Opening editor...")

		// Open description in editor
		newDesc, err := ui.EditInExternalEditor(event.Description, ".md")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		// Check if changed
		if newDesc == event.Description {
			fmt.Println("No changes made.")
			return
		}

		// Update event
		updated, err := client.UpdateEventDescription(event.ID, newDesc)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error updating event: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("✓ Updated: %s\n", updated.Title)
	},
}

func init() {
	rootCmd.AddCommand(eventsCmd)
	eventsCmd.AddCommand(listEventsCmd)
	eventsCmd.AddCommand(showEventCmd)
	eventsCmd.AddCommand(publishEventCmd)
	eventsCmd.AddCommand(cancelEventCmd)
	eventsCmd.AddCommand(editEventCmd)
}
