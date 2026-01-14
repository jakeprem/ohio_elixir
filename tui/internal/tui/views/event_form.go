package views

import (
	"strconv"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
)

// EventForm is the event creation form
type EventForm struct {
	venues      []api.Venue
	width       int
	height      int
	form        CustomForm
	description string // Store description separately since external editor modifies it
}

// EventFormCreateMsg is sent when a new event should be created
type EventFormCreateMsg struct {
	Title            string
	Format           string
	StartsAt         time.Time
	EndsAt           *time.Time
	Timezone         string
	VenueID          string
	MeetingURL       string
	Capacity         *int
	ShortDescription string
	Description      string
}

// EventFormCancelMsg is sent when the form is cancelled
type EventFormCancelMsg struct{}

// NewEventForm creates a new event creation form
func NewEventForm(venues []api.Venue, width, height int) EventForm {
	// Build venue options
	venueOptions := []string{"(none)"}
	for _, v := range venues {
		venueOptions = append(venueOptions, v.Name)
	}

	fields := []FormField{
		{Key: "title", Label: "Title", Type: FieldInput, Value: "", Placeholder: "Event title", Required: true},
		{Key: "format", Label: "Format", Type: FieldSelect, Value: "in_person", Options: []string{"in_person", "online", "hybrid"}},
		{Key: "starts_at", Label: "Starts At", Type: FieldInput, Value: "", Placeholder: "YYYY-MM-DD HH:MM", Required: true},
		{Key: "ends_at", Label: "Ends At", Type: FieldInput, Value: "", Placeholder: "YYYY-MM-DD HH:MM (optional)"},
		{Key: "timezone", Label: "Timezone", Type: FieldInput, Value: "America/New_York", Placeholder: "America/New_York"},
		{Key: "venue", Label: "Venue", Type: FieldSelectSearchable, Value: "(none)", Options: venueOptions, Placeholder: "Type to search venues..."},
		{Key: "meeting_url", Label: "Meeting URL", Type: FieldInput, Value: "", Placeholder: "https://... (for virtual events)"},
		{Key: "capacity", Label: "Capacity", Type: FieldInput, Value: "", Placeholder: "0 (optional)"},
		{Key: "short_desc", Label: "Short Description", Type: FieldInput, Value: "", Placeholder: "Brief summary"},
		{Key: "description", Label: "Description", Type: FieldDescription, Value: "", Placeholder: "Press Enter to edit in external editor"},
		{Key: "create", Label: "Create Event", Type: FieldConfirm, Value: ""},
	}

	return EventForm{
		venues: venues,
		width:  width,
		height: height,
		form:   NewCustomForm(fields, width, height),
	}
}

// SetSize updates form dimensions
func (m *EventForm) SetSize(width, height int) {
	m.width = width
	m.height = height
	m.form.SetSize(width, height)
}

// SetVenues updates the venue list
func (m *EventForm) SetVenues(venues []api.Venue) {
	m.venues = venues
	venueOptions := []string{"(none)"}
	for _, v := range venues {
		venueOptions = append(venueOptions, v.Name)
	}
	for i := range m.form.fields {
		if m.form.fields[i].Key == "venue" {
			m.form.fields[i].Options = venueOptions
			break
		}
	}
}

// SetDescription updates the description
func (m *EventForm) SetDescription(desc string) {
	m.description = desc
	m.form.SetValue("description", desc)
}

// Init initializes the form
func (m EventForm) Init() tea.Cmd {
	return m.form.Init()
}

// Update handles messages for the form
func (m EventForm) Update(msg tea.Msg) (EventForm, tea.Cmd) {
	var cmd tea.Cmd
	m.form, cmd = m.form.Update(msg)

	// Check for description edit request via flag
	if m.form.DescriptionEditRequested() {
		desc := m.form.GetDescriptionToEdit()
		m.form.ClearDescriptionEditRequest()
		return m, func() tea.Msg {
			return EditDescriptionMsg{
				EventID:     "", // Empty for new event
				Description: desc,
			}
		}
	}

	// Check form state
	if m.form.IsSubmitted() {
		return m, m.buildCreateCmd()
	}
	if m.form.IsCancelled() {
		return m, func() tea.Msg { return EventFormCancelMsg{} }
	}

	return m, cmd
}

func (m EventForm) buildCreateCmd() tea.Cmd {
	startsAt, _ := time.Parse("2006-01-02 15:04", m.form.GetValue("starts_at"))

	var endsAt *time.Time
	if endsAtStr := m.form.GetValue("ends_at"); endsAtStr != "" {
		if t, err := time.Parse("2006-01-02 15:04", endsAtStr); err == nil {
			endsAt = &t
		}
	}

	var capacity *int
	if capStr := m.form.GetValue("capacity"); capStr != "" {
		if cap, err := strconv.Atoi(capStr); err == nil {
			capacity = &cap
		}
	}

	// Convert venue name to ID
	venueName := m.form.GetValue("venue")
	venueID := ""
	if venueName != "(none)" {
		for _, v := range m.venues {
			if v.Name == venueName {
				venueID = v.ID
				break
			}
		}
	}

	return func() tea.Msg {
		return EventFormCreateMsg{
			Title:            m.form.GetValue("title"),
			Format:           m.form.GetValue("format"),
			StartsAt:         startsAt,
			EndsAt:           endsAt,
			Timezone:         m.form.GetValue("timezone"),
			VenueID:          venueID,
			MeetingURL:       m.form.GetValue("meeting_url"),
			Capacity:         capacity,
			ShortDescription: m.form.GetValue("short_desc"),
			Description:      m.form.GetValue("description"),
		}
	}
}

// View renders the form
func (m EventForm) View() string {
	return m.form.View()
}
