package views

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
)

// VenueForm is the venue creation/edit form
type VenueForm struct {
	venueID  string // Empty for new venue
	venue    *api.Venue
	width    int
	height   int
	isCreate bool
	form     CustomForm
}

// VenueFormSaveMsg is sent when venue is saved (create or update)
type VenueFormSaveMsg struct {
	IsCreate bool
	VenueID  string // Empty for create
	Venue    api.Venue
}

// VenueFormCancelMsg is sent when the form is cancelled
type VenueFormCancelMsg struct{}

// NewVenueForm creates a new venue form for creation
func NewVenueForm(width, height int) VenueForm {
	fields := []FormField{
		{Key: "name", Label: "Name", Type: FieldInput, Value: "", Placeholder: "Venue name", Required: true},
		{Key: "address1", Label: "Address Line 1", Type: FieldInput, Value: "", Placeholder: "123 Main St"},
		{Key: "address2", Label: "Address Line 2", Type: FieldInput, Value: "", Placeholder: "Suite 100 (optional)"},
		{Key: "city", Label: "City", Type: FieldInput, Value: "", Placeholder: "Columbus"},
		{Key: "state", Label: "State", Type: FieldInput, Value: "", Placeholder: "OH"},
		{Key: "postal", Label: "Postal Code", Type: FieldInput, Value: "", Placeholder: "43215"},
		{Key: "country", Label: "Country", Type: FieldInput, Value: "USA", Placeholder: "USA"},
		{Key: "website", Label: "Website URL", Type: FieldInput, Value: "", Placeholder: "https://..."},
		{Key: "notes", Label: "Notes", Type: FieldInput, Value: "", Placeholder: "Additional information"},
		{Key: "create", Label: "Create Venue", Type: FieldConfirm, Value: ""},
	}

	return VenueForm{
		width:    width,
		height:   height,
		isCreate: true,
		form:     NewCustomForm(fields, width, height),
	}
}

// NewVenueEditForm creates a venue form for editing
func NewVenueEditForm(venue *api.Venue, width, height int) VenueForm {
	fields := []FormField{
		{Key: "name", Label: "Name", Type: FieldInput, Value: venue.Name, Placeholder: "Venue name", Required: true},
		{Key: "address1", Label: "Address Line 1", Type: FieldInput, Value: venue.AddressLine1, Placeholder: "123 Main St"},
		{Key: "address2", Label: "Address Line 2", Type: FieldInput, Value: venue.AddressLine2, Placeholder: "Suite 100 (optional)"},
		{Key: "city", Label: "City", Type: FieldInput, Value: venue.City, Placeholder: "Columbus"},
		{Key: "state", Label: "State", Type: FieldInput, Value: venue.State, Placeholder: "OH"},
		{Key: "postal", Label: "Postal Code", Type: FieldInput, Value: venue.PostalCode, Placeholder: "43215"},
		{Key: "country", Label: "Country", Type: FieldInput, Value: venue.Country, Placeholder: "USA"},
		{Key: "website", Label: "Website URL", Type: FieldInput, Value: venue.WebsiteURL, Placeholder: "https://..."},
		{Key: "notes", Label: "Notes", Type: FieldInput, Value: venue.Notes, Placeholder: "Additional information"},
		{Key: "save", Label: "Save Changes", Type: FieldConfirm, Value: ""},
	}

	return VenueForm{
		venueID:  venue.ID,
		venue:    venue,
		width:    width,
		height:   height,
		isCreate: false,
		form:     NewCustomForm(fields, width, height),
	}
}

// SetSize updates form dimensions
func (m *VenueForm) SetSize(width, height int) {
	m.width = width
	m.height = height
	m.form.SetSize(width, height)
}

// Init initializes the form
func (m VenueForm) Init() tea.Cmd {
	return m.form.Init()
}

// Update handles messages for the form
func (m VenueForm) Update(msg tea.Msg) (VenueForm, tea.Cmd) {
	var cmd tea.Cmd
	m.form, cmd = m.form.Update(msg)

	// Check form state
	if m.form.IsSubmitted() {
		return m, m.buildSaveCmd()
	}
	if m.form.IsCancelled() {
		return m, func() tea.Msg { return VenueFormCancelMsg{} }
	}

	return m, cmd
}

func (m VenueForm) buildSaveCmd() tea.Cmd {
	venue := api.Venue{
		ID:           m.venueID,
		Name:         m.form.GetValue("name"),
		AddressLine1: m.form.GetValue("address1"),
		AddressLine2: m.form.GetValue("address2"),
		City:         m.form.GetValue("city"),
		State:        m.form.GetValue("state"),
		PostalCode:   m.form.GetValue("postal"),
		Country:      m.form.GetValue("country"),
		WebsiteURL:   m.form.GetValue("website"),
		Notes:        m.form.GetValue("notes"),
	}

	return func() tea.Msg {
		return VenueFormSaveMsg{
			IsCreate: m.isCreate,
			VenueID:  m.venueID,
			Venue:    venue,
		}
	}
}

// View renders the form
func (m VenueForm) View() string {
	return m.form.View()
}
