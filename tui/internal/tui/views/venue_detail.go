package views

import (
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
)

// VenueDetail shows the details of a selected venue
type VenueDetail struct {
	venue    *api.Venue
	viewport viewport.Model
	width    int
	height   int
}

// NewVenueDetail creates a new venue detail view
func NewVenueDetail(width, height int) VenueDetail {
	vp := viewport.New(width, height)
	vp.Style = lipgloss.NewStyle()

	return VenueDetail{
		viewport: vp,
		width:    width,
		height:   height,
	}
}

// SetVenue updates the displayed venue
func (m *VenueDetail) SetVenue(venue *api.Venue) {
	m.venue = venue
	m.updateContent()
}

// SetSize updates the viewport dimensions
func (m *VenueDetail) SetSize(width, height int) {
	m.width = width
	m.height = height
	m.viewport.Width = width
	m.viewport.Height = height
	m.updateContent()
}

func (m *VenueDetail) updateContent() {
	if m.venue == nil {
		m.viewport.SetContent(m.renderEmpty())
		return
	}
	m.viewport.SetContent(m.renderVenue())
}

func (m *VenueDetail) renderEmpty() string {
	return lipgloss.NewStyle().
		Foreground(lipgloss.Color("#626262")).
		Render("No venue selected")
}

func (m *VenueDetail) renderVenue() string {
	v := m.venue
	var b strings.Builder

	// Name
	b.WriteString(detailTitleStyle.Render(v.Name))
	b.WriteString("\n\n")

	// Address
	hasAddress := v.AddressLine1 != "" || v.City != "" || v.State != ""
	if hasAddress {
		b.WriteString(detailLabelStyle.Render("Address:"))
		b.WriteString("\n")

		if v.AddressLine1 != "" {
			b.WriteString(detailValueStyle.Render(v.AddressLine1))
			b.WriteString("\n")
		}
		if v.AddressLine2 != "" {
			b.WriteString(detailValueStyle.Render(v.AddressLine2))
			b.WriteString("\n")
		}

		cityLine := ""
		if v.City != "" {
			cityLine = v.City
		}
		if v.State != "" {
			if cityLine != "" {
				cityLine += ", "
			}
			cityLine += v.State
		}
		if v.PostalCode != "" {
			if cityLine != "" {
				cityLine += " "
			}
			cityLine += v.PostalCode
		}
		if cityLine != "" {
			b.WriteString(detailValueStyle.Render(cityLine))
			b.WriteString("\n")
		}

		if v.Country != "" && v.Country != "USA" && v.Country != "US" {
			b.WriteString(detailValueStyle.Render(v.Country))
			b.WriteString("\n")
		}
		b.WriteString("\n")
	}

	// Website
	if v.WebsiteURL != "" {
		b.WriteString(detailLabelStyle.Render("Website: "))
		b.WriteString(detailValueStyle.Render(v.WebsiteURL))
		b.WriteString("\n\n")
	}

	// Notes
	if v.Notes != "" {
		b.WriteString(detailLabelStyle.Render("Notes:"))
		b.WriteString("\n")
		wrapped := wordWrap(v.Notes, m.width-2)
		b.WriteString(detailValueStyle.Render(wrapped))
	}

	return b.String()
}

// Init initializes the venue detail view
func (m VenueDetail) Init() tea.Cmd {
	return nil
}

// Update handles messages for the venue detail view
func (m VenueDetail) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.SetSize(msg.Width, msg.Height)
		return m, nil
	}

	m.viewport, cmd = m.viewport.Update(msg)
	return m, cmd
}

// View renders the venue detail view
func (m VenueDetail) View() string {
	return m.viewport.View()
}

// ScrollUp scrolls the viewport up
func (m *VenueDetail) ScrollUp() {
	m.viewport.LineUp(1)
}

// ScrollDown scrolls the viewport down
func (m *VenueDetail) ScrollDown() {
	m.viewport.LineDown(1)
}

// ScrollToTop scrolls to the top
func (m *VenueDetail) ScrollToTop() {
	m.viewport.GotoTop()
}
