package tui

import "github.com/jakeprem/ohio_elixir/tui/internal/api"

// SectionType represents the current section (Events or Venues)
type SectionType int

const (
	SectionEvents SectionType = iota
	SectionVenues
)

// ViewType represents the current view being displayed
type ViewType int

const (
	ViewList ViewType = iota
	ViewDetail
	ViewEdit
	ViewCreate
)

// SwitchViewMsg requests a view change
type SwitchViewMsg struct {
	View ViewType
	Data interface{} // Optional: event ID, etc.
}

// EventsLoadedMsg is sent when events are fetched from API
type EventsLoadedMsg struct {
	Events []api.Event
}

// EventLoadedMsg is sent when a single event is fetched
type EventLoadedMsg struct {
	Event *api.Event
}

// EventPublishedMsg is sent when an event is published
type EventPublishedMsg struct {
	Event *api.Event
}

// EventCancelledMsg is sent when an event is cancelled
type EventCancelledMsg struct {
	Event *api.Event
}

// EventUpdatedMsg is sent when an event is updated
type EventUpdatedMsg struct {
	Event *api.Event
}

// ErrMsg represents an error from an async operation
type ErrMsg struct {
	Err error
}

func (e ErrMsg) Error() string { return e.Err.Error() }

// StatusMsg is a status message to display
type StatusMsg string

// EditorReturnedMsg is sent when the external editor exits
type EditorReturnedMsg struct {
	EventID string
	Content string
	Err     error
}

// VenuesLoadedMsg is sent when venues are fetched from API
type VenuesLoadedMsg struct {
	Venues []api.Venue
}

// EditFormSaveMsg is sent when the edit form is saved
type EditFormSaveMsg struct {
	EventID string
	Update  api.EventUpdate
}

// EditFormCancelMsg is sent when edit form is cancelled
type EditFormCancelMsg struct{}

// EditDescriptionRequestMsg requests opening editor for description
type EditDescriptionRequestMsg struct {
	EventID     string
	Description string
}

// VenueCreatedMsg is sent when a venue is created
type VenueCreatedMsg struct {
	Venue *api.Venue
}

// VenueUpdatedMsg is sent when a venue is updated
type VenueUpdatedMsg struct {
	Venue *api.Venue
}

// VenueDeletedMsg is sent when a venue is deleted
type VenueDeletedMsg struct {
	VenueID string
}

// EventCreatedMsg is sent when an event is created
type EventCreatedMsg struct {
	Event *api.Event
}

// AttendeesLoadedMsg is sent when attendees are fetched
type AttendeesLoadedMsg struct {
	Attendees []api.Attendee
}

// AttendeeMarkedMsg is sent when an attendee is marked as attended
type AttendeeMarkedMsg struct {
	Attendee *api.Attendee
}

// RSVPCancelledMsg is sent when an RSVP is cancelled
type RSVPCancelledMsg struct {
	AttendeeID string
}
