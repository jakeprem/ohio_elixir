package views

import (
	"strconv"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
)

// EditForm is the event edit form
type EditForm struct {
	eventID string
	event   *api.Event
	venues  []api.Venue
	width   int
	height  int
	form    CustomForm
}

// EditFormSaveMsg is sent when save is triggered
type EditFormSaveMsg struct {
	EventID string
	Update  api.EventUpdate
}

// EditFormCancelMsg is sent when cancel is triggered
type EditFormCancelMsg struct{}

// EditDescriptionMsg requests opening editor for description
type EditDescriptionMsg struct {
	EventID     string
	Description string
}

// NewEditForm creates a new edit form
func NewEditForm(event *api.Event, venues []api.Venue, width, height int) EditForm {
	// Build venue options
	venueOptions := []string{"(none)"}
	venueMap := map[string]string{"(none)": ""} // display -> id
	for _, v := range venues {
		venueOptions = append(venueOptions, v.Name)
		venueMap[v.Name] = v.ID
	}

	// Get current venue display name
	currentVenue := "(none)"
	for _, v := range venues {
		if v.ID == event.VenueID {
			currentVenue = v.Name
			break
		}
	}

	// Initialize date strings
	startsAt := ""
	if event.StartsAt != nil {
		startsAt = event.StartsAt.Format("2006-01-02 15:04")
	}
	endsAt := ""
	if event.EndsAt != nil {
		endsAt = event.EndsAt.Format("2006-01-02 15:04")
	}
	capacity := ""
	if event.Capacity != nil {
		capacity = strconv.Itoa(*event.Capacity)
	}

	// Set default format
	format := event.Format
	if format == "" {
		format = "in_person"
	}

	fields := []FormField{
		{Key: "title", Label: "Title", Type: FieldInput, Value: event.Title, Placeholder: "Event title"},
		{Key: "format", Label: "Format", Type: FieldSelect, Value: format, Options: []string{"in_person", "online", "hybrid"}},
		{Key: "starts_at", Label: "Starts At", Type: FieldInput, Value: startsAt, Placeholder: "YYYY-MM-DD HH:MM"},
		{Key: "ends_at", Label: "Ends At", Type: FieldInput, Value: endsAt, Placeholder: "YYYY-MM-DD HH:MM (optional)"},
		{Key: "timezone", Label: "Timezone", Type: FieldInput, Value: event.Timezone, Placeholder: "America/New_York"},
		{Key: "venue", Label: "Venue", Type: FieldSelectSearchable, Value: currentVenue, Options: venueOptions, Placeholder: "Type to search venues..."},
		{Key: "meeting_url", Label: "Meeting URL", Type: FieldInput, Value: event.MeetingURL, Placeholder: "https://..."},
		{Key: "capacity", Label: "Capacity", Type: FieldInput, Value: capacity, Placeholder: "0 (optional)"},
		{Key: "short_desc", Label: "Short Description", Type: FieldInput, Value: event.ShortDescription, Placeholder: "Brief summary"},
		{Key: "description", Label: "Description", Type: FieldDescription, Value: event.Description, Placeholder: "Press Enter to edit in external editor"},
		{Key: "save", Label: "Save Changes", Type: FieldConfirm, Value: ""},
	}

	m := EditForm{
		eventID: event.ID,
		event:   event,
		venues:  venues,
		width:   width,
		height:  height,
		form:    NewCustomForm(fields, width, height),
	}

	return m
}

// SetSize updates form dimensions
func (m *EditForm) SetSize(width, height int) {
	m.width = width
	m.height = height
	m.form.SetSize(width, height)
}

// SetVenues updates the venue list
func (m *EditForm) SetVenues(venues []api.Venue) {
	m.venues = venues
	// Update venue options in form
	venueOptions := []string{"(none)"}
	for _, v := range venues {
		venueOptions = append(venueOptions, v.Name)
	}
	// Find venue field and update options
	for i := range m.form.fields {
		if m.form.fields[i].Key == "venue" {
			m.form.fields[i].Options = venueOptions
			break
		}
	}
}

// SetDescription updates the description
func (m *EditForm) SetDescription(desc string) {
	m.form.SetValue("description", desc)
}

// Init initializes the form
func (m EditForm) Init() tea.Cmd {
	return m.form.Init()
}

// Update handles messages for the form
func (m EditForm) Update(msg tea.Msg) (EditForm, tea.Cmd) {
	var cmd tea.Cmd
	m.form, cmd = m.form.Update(msg)

	// Check for description edit request via flag
	if m.form.DescriptionEditRequested() {
		desc := m.form.GetDescriptionToEdit()
		m.form.ClearDescriptionEditRequest()
		return m, func() tea.Msg {
			return EditDescriptionMsg{
				EventID:     m.eventID,
				Description: desc,
			}
		}
	}

	// Check form state
	if m.form.IsSubmitted() {
		return m, m.buildSaveCmd()
	}
	if m.form.IsCancelled() {
		return m, func() tea.Msg { return EditFormCancelMsg{} }
	}

	return m, cmd
}

func (m EditForm) buildSaveCmd() tea.Cmd {
	update := api.EventUpdate{}

	// Title
	if title := m.form.GetValue("title"); title != m.event.Title {
		update.Title = &title
	}

	// Format
	if format := m.form.GetValue("format"); format != m.event.Format {
		update.Format = &format
	}

	// StartsAt
	if startsAtStr := m.form.GetValue("starts_at"); startsAtStr != "" {
		if startsAt, err := time.Parse("2006-01-02 15:04", startsAtStr); err == nil {
			if m.event.StartsAt == nil || !startsAt.Equal(*m.event.StartsAt) {
				update.StartsAt = &startsAt
			}
		}
	}

	// EndsAt
	if endsAtStr := m.form.GetValue("ends_at"); endsAtStr != "" {
		if endsAt, err := time.Parse("2006-01-02 15:04", endsAtStr); err == nil {
			if m.event.EndsAt == nil || !endsAt.Equal(*m.event.EndsAt) {
				update.EndsAt = &endsAt
			}
		}
	}

	// Timezone
	if tz := m.form.GetValue("timezone"); tz != m.event.Timezone {
		update.Timezone = &tz
	}

	// Venue - need to convert display name back to ID
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
	if venueID != m.event.VenueID {
		update.VenueID = &venueID
	}

	// Meeting URL
	if url := m.form.GetValue("meeting_url"); url != m.event.MeetingURL {
		update.MeetingURL = &url
	}

	// Capacity
	if capStr := m.form.GetValue("capacity"); capStr != "" {
		if cap, err := strconv.Atoi(capStr); err == nil {
			if m.event.Capacity == nil || cap != *m.event.Capacity {
				update.Capacity = &cap
			}
		}
	}

	// Short description
	if shortDesc := m.form.GetValue("short_desc"); shortDesc != m.event.ShortDescription {
		update.ShortDescription = &shortDesc
	}

	// Description
	if desc := m.form.GetValue("description"); desc != m.event.Description {
		update.Description = &desc
	}

	return func() tea.Msg {
		return EditFormSaveMsg{
			EventID: m.eventID,
			Update:  update,
		}
	}
}

// View renders the form
func (m EditForm) View() string {
	return m.form.View()
}
