package cmd

import (
	"fmt"
	"os"
	"strings"
	"text/tabwriter"

	"github.com/jakeprem/ohio_elixir/tui/internal/api"
	"github.com/spf13/cobra"
)

var venuesCmd = &cobra.Command{
	Use:   "venues",
	Short: "Manage venues",
	Long:  `List, view, and manage Ohio Elixir venues.`,
	Run: func(cmd *cobra.Command, args []string) {
		// Default to list
		listVenuesCmd.Run(cmd, args)
	},
}

var listVenuesCmd = &cobra.Command{
	Use:   "list",
	Short: "List all venues",
	Run: func(cmd *cobra.Command, args []string) {
		client := api.NewClient()
		venues, err := client.ListVenues()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		if len(venues) == 0 {
			fmt.Println("No venues found.")
			return
		}

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "ID\tNAME\tCITY\tSTATE")
		fmt.Fprintln(w, "--\t----\t----\t-----")

		for _, v := range venues {
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", v.ID, v.Name, v.City, v.State)
		}
		w.Flush()
	},
}

var showVenueCmd = &cobra.Command{
	Use:   "show [id]",
	Short: "Show venue details",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		client := api.NewClient()
		venue, err := client.GetVenue(args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("Name: %s\n", venue.Name)
		fmt.Printf("ID: %s\n", venue.ID)

		// Build address
		var addrParts []string
		if venue.AddressLine1 != "" {
			addrParts = append(addrParts, venue.AddressLine1)
		}
		if venue.AddressLine2 != "" {
			addrParts = append(addrParts, venue.AddressLine2)
		}
		if venue.City != "" || venue.State != "" || venue.PostalCode != "" {
			cityLine := venue.City
			if venue.State != "" {
				if cityLine != "" {
					cityLine += ", "
				}
				cityLine += venue.State
			}
			if venue.PostalCode != "" {
				cityLine += " " + venue.PostalCode
			}
			addrParts = append(addrParts, cityLine)
		}
		if venue.Country != "" && venue.Country != "US" {
			addrParts = append(addrParts, venue.Country)
		}

		if len(addrParts) > 0 {
			fmt.Printf("Address:\n  %s\n", strings.Join(addrParts, "\n  "))
		}

		if venue.WebsiteURL != "" {
			fmt.Printf("Website: %s\n", venue.WebsiteURL)
		}
		if venue.Notes != "" {
			fmt.Printf("\nNotes:\n%s\n", venue.Notes)
		}
	},
}

func init() {
	rootCmd.AddCommand(venuesCmd)
	venuesCmd.AddCommand(listVenuesCmd)
	venuesCmd.AddCommand(showVenueCmd)
}
