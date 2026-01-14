package views

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
)

// VenuesList is the venues list view
type VenuesList struct {
	venues      []api.Venue
	filtered    []api.Venue
	cursor      int
	width       int
	height      int
	offset      int // For scrolling
	searching   bool
	searchInput textinput.Model
}

// VenuesLoadedMsg is sent when venues are loaded
type VenuesLoadedMsg struct {
	Venues []api.Venue
}

// NewVenuesList creates a new venues list view
func NewVenuesList(width, height int) VenuesList {
	ti := textinput.New()
	ti.Placeholder = "Type to filter..."
	ti.CharLimit = 50

	return VenuesList{
		venues:      []api.Venue{},
		filtered:    []api.Venue{},
		width:       width,
		height:      height,
		searchInput: ti,
	}
}

// Init initializes the venues list
func (m VenuesList) Init() tea.Cmd {
	return nil // Loading handled by parent
}

// Update handles messages for the venues list
func (m VenuesList) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case VenuesLoadedMsg:
		m.venues = msg.Venues
		m.applyFilter()
		m.cursor = 0
		m.offset = 0
		return m, nil

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tea.KeyMsg:
		if m.searching {
			switch msg.String() {
			case "enter", "esc":
				m.searching = false
				m.searchInput.Blur()
				return m, nil
			default:
				var cmd tea.Cmd
				m.searchInput, cmd = m.searchInput.Update(msg)
				m.applyFilter()
				m.cursor = 0
				m.offset = 0
				return m, cmd
			}
		}

		switch {
		case key.Matches(msg, key.NewBinding(key.WithKeys("/"))):
			m.searching = true
			m.searchInput.Focus()
			return m, textinput.Blink

		case key.Matches(msg, key.NewBinding(key.WithKeys("j", "down"))):
			m.moveDown()
			return m, nil

		case key.Matches(msg, key.NewBinding(key.WithKeys("k", "up"))):
			m.moveUp()
			return m, nil

		case key.Matches(msg, key.NewBinding(key.WithKeys("g"))):
			m.cursor = 0
			m.offset = 0
			return m, nil

		case key.Matches(msg, key.NewBinding(key.WithKeys("G"))):
			m.cursor = len(m.filtered) - 1
			m.ensureVisible()
			return m, nil
		}
	}

	return m, nil
}

func (m *VenuesList) applyFilter() {
	query := strings.ToLower(m.searchInput.Value())
	if query == "" {
		m.filtered = m.venues
		return
	}

	m.filtered = nil
	for _, v := range m.venues {
		if strings.Contains(strings.ToLower(v.Name), query) ||
			strings.Contains(strings.ToLower(v.City), query) ||
			strings.Contains(strings.ToLower(v.State), query) {
			m.filtered = append(m.filtered, v)
		}
	}
}

func (m *VenuesList) moveDown() {
	if m.cursor < len(m.filtered)-1 {
		m.cursor++
		m.ensureVisible()
	}
}

func (m *VenuesList) moveUp() {
	if m.cursor > 0 {
		m.cursor--
		m.ensureVisible()
	}
}

func (m *VenuesList) ensureVisible() {
	visibleLines := m.height - 2
	if visibleLines < 1 {
		visibleLines = 1
	}

	itemsVisible := visibleLines

	if m.cursor < m.offset {
		m.offset = m.cursor
	} else if m.cursor >= m.offset+itemsVisible {
		m.offset = m.cursor - itemsVisible + 1
	}
}

// View renders the venues list
func (m VenuesList) View() string {
	var b strings.Builder

	// Search bar if active
	if m.searching {
		b.WriteString(searchStyle.Render("/") + m.searchInput.View())
		b.WriteString("\n")
	} else if m.searchInput.Value() != "" {
		b.WriteString(mutedStyle.Render(fmt.Sprintf("Filter: %s (/ to edit)", m.searchInput.Value())))
		b.WriteString("\n")
	}

	if len(m.filtered) == 0 {
		if len(m.venues) == 0 {
			b.WriteString(mutedStyle.Render("No venues"))
		} else {
			b.WriteString(mutedStyle.Render("No matching venues"))
		}
		return b.String()
	}

	// Calculate visible items
	visibleLines := m.height - 2
	if m.searching || m.searchInput.Value() != "" {
		visibleLines -= 1
	}
	itemsVisible := visibleLines
	if itemsVisible < 1 {
		itemsVisible = 1
	}

	// Render visible items
	for i := m.offset; i < len(m.filtered) && i < m.offset+itemsVisible; i++ {
		venue := m.filtered[i]
		isSelected := i == m.cursor

		// Format: Name, City, State
		name := venue.Name
		maxNameLen := m.width - 20 // Space for city/state
		if maxNameLen < 10 {
			maxNameLen = 10
		}
		if len(name) > maxNameLen {
			name = name[:maxNameLen-3] + "..."
		}

		location := ""
		if venue.City != "" && venue.State != "" {
			location = fmt.Sprintf(" (%s, %s)", venue.City, venue.State)
		} else if venue.City != "" {
			location = fmt.Sprintf(" (%s)", venue.City)
		}

		line := name + mutedStyle.Render(location)

		if isSelected {
			// For selected, use raw text without extra styling
			rawLine := name
			if venue.City != "" && venue.State != "" {
				rawLine += fmt.Sprintf(" (%s, %s)", venue.City, venue.State)
			} else if venue.City != "" {
				rawLine += fmt.Sprintf(" (%s)", venue.City)
			}
			b.WriteString(selectedStyle.Render(fmt.Sprintf(" %-*s", m.width-2, rawLine)))
		} else {
			b.WriteString(normalStyle.Render(" " + line))
		}

		if i < m.offset+itemsVisible-1 && i < len(m.filtered)-1 {
			b.WriteString("\n")
		}
	}

	// Show scroll indicator if needed
	if len(m.filtered) > itemsVisible {
		total := len(m.filtered)
		pos := m.cursor + 1
		indicator := fmt.Sprintf(" [%d/%d]", pos, total)
		b.WriteString("\n")
		b.WriteString(mutedStyle.Render(indicator))
	}

	return b.String()
}

// SelectedVenue returns the currently selected venue, or nil
func (m VenuesList) SelectedVenue() *api.Venue {
	if m.cursor >= 0 && m.cursor < len(m.filtered) {
		return &m.filtered[m.cursor]
	}
	return nil
}

// SetSize updates the list dimensions
func (m *VenuesList) SetSize(width, height int) {
	m.width = width
	m.height = height
}

// SetVenues updates the venues list
func (m *VenuesList) SetVenues(venues []api.Venue) {
	m.venues = venues
	m.applyFilter()
}

// IsSearching returns true if search is active
func (m VenuesList) IsSearching() bool {
	return m.searching
}

// ClearSearch clears the search filter
func (m *VenuesList) ClearSearch() {
	m.searchInput.SetValue("")
	m.searching = false
	m.applyFilter()
}
