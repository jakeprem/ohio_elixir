package tui

import (
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
)

// LoadEvents fetches all events from the API
func LoadEvents(client *api.Client) tea.Cmd {
	return func() tea.Msg {
		events, err := client.ListEvents()
		if err != nil {
			return ErrMsg{Err: err}
		}
		return EventsLoadedMsg{Events: events}
	}
}

// LoadEvent fetches a single event from the API
func LoadEvent(client *api.Client, id string) tea.Cmd {
	return func() tea.Msg {
		event, err := client.GetEvent(id)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return EventLoadedMsg{Event: event}
	}
}

// PublishEvent publishes an event
func PublishEvent(client *api.Client, id string) tea.Cmd {
	return func() tea.Msg {
		event, err := client.PublishEvent(id)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return EventPublishedMsg{Event: event}
	}
}

// CancelEvent cancels an event
func CancelEvent(client *api.Client, id string) tea.Cmd {
	return func() tea.Msg {
		event, err := client.CancelEvent(id)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return EventCancelledMsg{Event: event}
	}
}

// UpdateEventDescription updates an event's description
func UpdateEventDescription(client *api.Client, id, description string) tea.Cmd {
	return func() tea.Msg {
		event, err := client.UpdateEventDescription(id, description)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return EventUpdatedMsg{Event: event}
	}
}

// UpdateEventCmd updates an event with the provided changes
func UpdateEventCmd(client *api.Client, id string, update api.EventUpdate) tea.Cmd {
	return func() tea.Msg {
		event, err := client.UpdateEvent(id, update)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return EventUpdatedMsg{Event: event}
	}
}

// LoadVenues fetches all venues from the API
func LoadVenues(client *api.Client) tea.Cmd {
	return func() tea.Msg {
		venues, err := client.ListVenues()
		if err != nil {
			return ErrMsg{Err: err}
		}
		return VenuesLoadedMsg{Venues: venues}
	}
}

// CreateEventCmd creates a new event
func CreateEventCmd(client *api.Client, title, description, shortDesc, format string, startsAt time.Time, endsAt *time.Time, timezone, meetingURL string, capacity *int) tea.Cmd {
	return func() tea.Msg {
		event, err := client.CreateEvent(title, description, shortDesc, format, startsAt, endsAt, timezone, meetingURL, capacity)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return EventCreatedMsg{Event: event}
	}
}

// CreateVenueCmd creates a new venue
func CreateVenueCmd(client *api.Client, venue *api.Venue) tea.Cmd {
	return func() tea.Msg {
		created, err := client.CreateVenue(venue)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return VenueCreatedMsg{Venue: created}
	}
}

// UpdateVenueCmd updates an existing venue
func UpdateVenueCmd(client *api.Client, id string, venue *api.Venue) tea.Cmd {
	return func() tea.Msg {
		updated, err := client.UpdateVenue(id, venue)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return VenueUpdatedMsg{Venue: updated}
	}
}

// DeleteVenueCmd deletes a venue
func DeleteVenueCmd(client *api.Client, id string) tea.Cmd {
	return func() tea.Msg {
		err := client.DeleteVenue(id)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return VenueDeletedMsg{VenueID: id}
	}
}

// LoadAttendeesCmd fetches attendees for an event
func LoadAttendeesCmd(client *api.Client, eventID string) tea.Cmd {
	return func() tea.Msg {
		attendees, err := client.ListEventAttendees(eventID)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return AttendeesLoadedMsg{Attendees: attendees}
	}
}

// MarkAttendeeCmd marks an attendee as attended
func MarkAttendeeCmd(client *api.Client, attendeeID string) tea.Cmd {
	return func() tea.Msg {
		attendee, err := client.MarkAttended(attendeeID, true)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return AttendeeMarkedMsg{Attendee: attendee}
	}
}

// CancelRSVPCmd cancels an RSVP
func CancelRSVPCmd(client *api.Client, attendeeID string) tea.Cmd {
	return func() tea.Msg {
		err := client.CancelRSVP(attendeeID)
		if err != nil {
			return ErrMsg{Err: err}
		}
		return RSVPCancelledMsg{AttendeeID: attendeeID}
	}
}
