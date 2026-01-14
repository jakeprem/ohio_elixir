package views

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
)

var (
	attendeeConfirmedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#04B575"))
	attendeeCancelledStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF5F56"))
	attendeeWaitlistStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("#FFCC00"))
	attendeeAttendedStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("#7D56F4")).Bold(true)
)

// AttendeesPanel displays attendees for an event
type AttendeesPanel struct {
	eventID   string
	attendees []api.Attendee
	cursor    int
	width     int
	height    int
	offset    int
	focused   bool
}

// AttendeeMarkMsg requests marking an attendee as attended
type AttendeeMarkMsg struct {
	AttendeeID string
}

// AttendeeCancelMsg requests cancelling an RSVP
type AttendeeCancelMsg struct {
	AttendeeID string
}

// AttendeeExportMsg requests exporting attendees to CSV
type AttendeeExportMsg struct {
	EventID string
}

// NewAttendeesPanel creates a new attendees panel
func NewAttendeesPanel(eventID string, width, height int) AttendeesPanel {
	return AttendeesPanel{
		eventID: eventID,
		width:   width,
		height:  height,
	}
}

// SetAttendees updates the attendees list
func (m *AttendeesPanel) SetAttendees(attendees []api.Attendee) {
	m.attendees = attendees
	if m.cursor >= len(attendees) && len(attendees) > 0 {
		m.cursor = len(attendees) - 1
	}
}

// SetEventID updates the event ID
func (m *AttendeesPanel) SetEventID(eventID string) {
	m.eventID = eventID
	m.cursor = 0
	m.offset = 0
}

// SetSize updates panel dimensions
func (m *AttendeesPanel) SetSize(width, height int) {
	m.width = width
	m.height = height
}

// SetFocused sets whether the panel is focused
func (m *AttendeesPanel) SetFocused(focused bool) {
	m.focused = focused
}

// Init initializes the panel
func (m AttendeesPanel) Init() tea.Cmd {
	return nil
}

// Update handles messages for the panel
func (m AttendeesPanel) Update(msg tea.Msg) (AttendeesPanel, tea.Cmd) {
	if !m.focused {
		return m, nil
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch {
		case key.Matches(msg, key.NewBinding(key.WithKeys("j", "down"))):
			m.moveDown()
			return m, nil

		case key.Matches(msg, key.NewBinding(key.WithKeys("k", "up"))):
			m.moveUp()
			return m, nil

		case key.Matches(msg, key.NewBinding(key.WithKeys("a"))):
			// Mark as attended
			if attendee := m.SelectedAttendee(); attendee != nil {
				return m, func() tea.Msg {
					return AttendeeMarkMsg{AttendeeID: attendee.ID}
				}
			}

		case key.Matches(msg, key.NewBinding(key.WithKeys("c"))):
			// Cancel RSVP
			if attendee := m.SelectedAttendee(); attendee != nil {
				return m, func() tea.Msg {
					return AttendeeCancelMsg{AttendeeID: attendee.ID}
				}
			}

		case key.Matches(msg, key.NewBinding(key.WithKeys("X"))):
			// Export CSV
			return m, func() tea.Msg {
				return AttendeeExportMsg{EventID: m.eventID}
			}
		}
	}

	return m, nil
}

func (m *AttendeesPanel) moveDown() {
	if m.cursor < len(m.attendees)-1 {
		m.cursor++
		m.ensureVisible()
	}
}

func (m *AttendeesPanel) moveUp() {
	if m.cursor > 0 {
		m.cursor--
		m.ensureVisible()
	}
}

func (m *AttendeesPanel) ensureVisible() {
	// Reserve space for: header (2) + help hint (2) = 4
	visibleLines := m.height - 4
	if visibleLines < 1 {
		visibleLines = 1
	}

	if m.cursor < m.offset {
		m.offset = m.cursor
	} else if m.cursor >= m.offset+visibleLines {
		m.offset = m.cursor - visibleLines + 1
	}
}

// SelectedAttendee returns the currently selected attendee
func (m AttendeesPanel) SelectedAttendee() *api.Attendee {
	if m.cursor >= 0 && m.cursor < len(m.attendees) {
		return &m.attendees[m.cursor]
	}
	return nil
}

// View renders the attendees panel
func (m AttendeesPanel) View() string {
	var b strings.Builder

	// Header with count
	confirmedCount := 0
	for _, a := range m.attendees {
		if a.Status == "confirmed" {
			confirmedCount++
		}
	}
	header := fmt.Sprintf("Attendees (%d)", confirmedCount)
	b.WriteString(detailLabelStyle.Render(header))
	b.WriteString("\n\n")

	if len(m.attendees) == 0 {
		b.WriteString(mutedStyle.Render("No attendees yet"))
		return b.String()
	}

	// Calculate visible items
	// Reserve space for: header (2) + help hint (2) = 4
	visibleLines := m.height - 4
	if visibleLines < 1 {
		visibleLines = 1
	}

	// Render visible attendees
	for i := m.offset; i < len(m.attendees) && i < m.offset+visibleLines; i++ {
		attendee := m.attendees[i]
		isSelected := i == m.cursor && m.focused

		// Status indicator
		var statusIcon string
		var statusStyle lipgloss.Style
		switch attendee.Status {
		case "confirmed":
			if attendee.Attended {
				statusIcon = "+"
				statusStyle = attendeeAttendedStyle
			} else {
				statusIcon = "o"
				statusStyle = attendeeConfirmedStyle
			}
		case "cancelled":
			statusIcon = "x"
			statusStyle = attendeeCancelledStyle
		case "waitlisted":
			statusIcon = "~"
			statusStyle = attendeeWaitlistStyle
		default:
			statusIcon = "?"
			statusStyle = mutedStyle
		}

		// Format: [status] Name (email) or just email if no name
		displayName := attendee.Name
		if displayName != "" && attendee.Email != "" {
			displayName = displayName + " (" + attendee.Email + ")"
		} else if attendee.Email != "" {
			displayName = attendee.Email
		}

		maxNameLen := m.width - 15
		if maxNameLen < 10 {
			maxNameLen = 10
		}
		if len(displayName) > maxNameLen {
			displayName = displayName[:maxNameLen-3] + "..."
		}

		mode := ""
		if attendee.AttendanceMode != "" {
			mode = " [" + attendee.AttendanceMode + "]"
		}

		line := fmt.Sprintf("%s %s%s",
			statusStyle.Render(statusIcon),
			displayName,
			mutedStyle.Render(mode),
		)

		if isSelected {
			// Highlight the whole line for selected
			rawLine := fmt.Sprintf("%s %s%s", statusIcon, displayName, mode)
			b.WriteString(selectedStyle.Render(fmt.Sprintf(" %-*s", m.width-2, rawLine)))
		} else {
			b.WriteString(" " + line)
		}

		if i < m.offset+visibleLines-1 && i < len(m.attendees)-1 {
			b.WriteString("\n")
		}
	}

	// Show scroll indicator if needed
	if len(m.attendees) > visibleLines {
		total := len(m.attendees)
		pos := m.cursor + 1
		indicator := fmt.Sprintf(" [%d/%d]", pos, total)
		b.WriteString("\n")
		b.WriteString(mutedStyle.Render(indicator))
	}

	// Help hint when focused
	if m.focused {
		b.WriteString("\n\n")
		b.WriteString(mutedStyle.Render("a:attend  c:cancel  X:export"))
	}

	return b.String()
}
