package views

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
)

// Status badge styles
var (
	statusDraft     = lipgloss.NewStyle().Foreground(lipgloss.Color("#FFCC00")).Bold(true)
	statusPublished = lipgloss.NewStyle().Foreground(lipgloss.Color("#04B575")).Bold(true)
	statusCancelled = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF5F56")).Bold(true)

	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFFDF5")).
			Background(lipgloss.Color("#7D56F4")).
			Bold(true)

	normalStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFFDF5"))

	mutedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#626262"))

	searchStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#7D56F4"))
)

func formatStatus(status string) string {
	switch status {
	case "draft":
		return statusDraft.Render(status)
	case "published":
		return statusPublished.Render(status)
	case "cancelled":
		return statusCancelled.Render(status)
	default:
		return status
	}
}

// EventsList is the events list view
type EventsList struct {
	events       []api.Event
	filtered     []api.Event
	cursor       int
	width        int
	height       int
	offset       int // For scrolling
	searching    bool
	searchInput  textinput.Model
	client       *api.Client
}

// NewEventsList creates a new events list view
func NewEventsList(client *api.Client, width, height int) EventsList {
	ti := textinput.New()
	ti.Placeholder = "Type to filter..."
	ti.CharLimit = 50

	return EventsList{
		events:      []api.Event{},
		filtered:    []api.Event{},
		client:      client,
		width:       width,
		height:      height,
		searchInput: ti,
	}
}

// Init initializes the events list
func (m EventsList) Init() tea.Cmd {
	return nil // Loading handled by parent
}

// EventsLoadedMsg is sent when events are loaded (defined locally to avoid import cycle)
type EventsLoadedMsg struct {
	Events []api.Event
}

// Update handles messages for the events list
func (m EventsList) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case EventsLoadedMsg:
		m.events = msg.Events
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

func (m *EventsList) applyFilter() {
	query := strings.ToLower(m.searchInput.Value())
	if query == "" {
		m.filtered = m.events
		return
	}

	m.filtered = nil
	for _, e := range m.events {
		if strings.Contains(strings.ToLower(e.Title), query) ||
			strings.Contains(strings.ToLower(e.Status), query) ||
			strings.Contains(strings.ToLower(e.Format), query) {
			m.filtered = append(m.filtered, e)
		}
	}
}

func (m *EventsList) moveDown() {
	if m.cursor < len(m.filtered)-1 {
		m.cursor++
		m.ensureVisible()
	}
}

func (m *EventsList) moveUp() {
	if m.cursor > 0 {
		m.cursor--
		m.ensureVisible()
	}
}

func (m *EventsList) ensureVisible() {
	visibleLines := m.height - 2 // Account for padding
	if visibleLines < 1 {
		visibleLines = 1
	}

	// Each item takes 1 line
	itemsVisible := visibleLines

	if m.cursor < m.offset {
		m.offset = m.cursor
	} else if m.cursor >= m.offset+itemsVisible {
		m.offset = m.cursor - itemsVisible + 1
	}
}

// View renders the events list
func (m EventsList) View() string {
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
		if len(m.events) == 0 {
			b.WriteString(mutedStyle.Render("No events"))
		} else {
			b.WriteString(mutedStyle.Render("No matching events"))
		}
		return b.String()
	}

	// Calculate visible items
	visibleLines := m.height - 2
	if m.searching || m.searchInput.Value() != "" {
		visibleLines -= 1
	}
	itemsVisible := visibleLines // Each item = 1 line
	if itemsVisible < 1 {
		itemsVisible = 1
	}

	// Render visible items
	for i := m.offset; i < len(m.filtered) && i < m.offset+itemsVisible; i++ {
		event := m.filtered[i]
		isSelected := i == m.cursor

		// Format: YYYY-MM-DD Title [status]
		date := "          " // 10 chars placeholder for no date
		if event.StartsAt != nil {
			date = event.StartsAt.Format("2006-01-02")
		}

		// Status indicator
		var statusIndicator string
		switch event.Status {
		case "draft":
			statusIndicator = statusDraft.Render("[draft]")
		case "published":
			statusIndicator = statusPublished.Render("[pub]")
		case "cancelled":
			statusIndicator = statusCancelled.Render("[x]")
		default:
			statusIndicator = "[?]"
		}

		title := event.Title
		maxTitleLen := m.width - 22 // date(10) + space(1) + status(8) + padding(3)
		if maxTitleLen < 10 {
			maxTitleLen = 10
		}
		if len(title) > maxTitleLen {
			title = title[:maxTitleLen-3] + "..."
		}

		line := fmt.Sprintf("%s %s %s", date, title, statusIndicator)

		if isSelected {
			b.WriteString(selectedStyle.Render(fmt.Sprintf(" %-*s", m.width-2, line)))
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

// SelectedEvent returns the currently selected event, or nil
func (m EventsList) SelectedEvent() *api.Event {
	if m.cursor >= 0 && m.cursor < len(m.filtered) {
		return &m.filtered[m.cursor]
	}
	return nil
}

// SetSize updates the list dimensions
func (m *EventsList) SetSize(width, height int) {
	m.width = width
	m.height = height
}

// IsSearching returns true if search is active
func (m EventsList) IsSearching() bool {
	return m.searching
}

// ClearSearch clears the search filter
func (m *EventsList) ClearSearch() {
	m.searchInput.SetValue("")
	m.searching = false
	m.applyFilter()
}
