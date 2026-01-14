package views

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
)

var (
	detailLabelStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#626262")).
				Bold(true)

	detailValueStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FFFDF5"))

	detailTitleStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("#7D56F4")).
				MarginBottom(1)
)

// EventDetail shows the details of a selected event
type EventDetail struct {
	event    *api.Event
	viewport viewport.Model
	width    int
	height   int
	ready    bool
}

// NewEventDetail creates a new event detail view
func NewEventDetail(width, height int) EventDetail {
	vp := viewport.New(width, height)
	vp.Style = lipgloss.NewStyle()

	return EventDetail{
		viewport: vp,
		width:    width,
		height:   height,
	}
}

// SetEvent updates the displayed event
func (m *EventDetail) SetEvent(event *api.Event) {
	m.event = event
	m.updateContent()
}

// SetSize updates the viewport dimensions
func (m *EventDetail) SetSize(width, height int) {
	m.width = width
	m.height = height
	m.viewport.Width = width
	m.viewport.Height = height
	m.updateContent()
}

func (m *EventDetail) updateContent() {
	if m.event == nil {
		m.viewport.SetContent(m.renderEmpty())
		return
	}
	m.viewport.SetContent(m.renderEvent())
}

func (m *EventDetail) renderEmpty() string {
	return lipgloss.NewStyle().
		Foreground(lipgloss.Color("#626262")).
		Render("No event selected")
}

func (m *EventDetail) renderEvent() string {
	e := m.event
	var b strings.Builder

	// Title
	b.WriteString(detailTitleStyle.Render(e.Title))
	b.WriteString("\n\n")

	// Status with color
	b.WriteString(detailLabelStyle.Render("Status: "))
	b.WriteString(formatStatus(e.Status))
	b.WriteString("\n\n")

	// Format
	b.WriteString(detailLabelStyle.Render("Format: "))
	b.WriteString(detailValueStyle.Render(e.Format))
	b.WriteString("\n\n")

	// Date/Time
	if e.StartsAt != nil {
		b.WriteString(detailLabelStyle.Render("Date: "))
		dateStr := e.StartsAt.Format("Monday, January 2, 2006")
		b.WriteString(detailValueStyle.Render(dateStr))
		b.WriteString("\n\n")

		b.WriteString(detailLabelStyle.Render("Time: "))
		timeStr := e.StartsAt.Format("3:04 PM")
		if e.EndsAt != nil {
			timeStr += " - " + e.EndsAt.Format("3:04 PM")
		}
		if e.Timezone != "" {
			timeStr += " " + e.Timezone
		}
		b.WriteString(detailValueStyle.Render(timeStr))
		b.WriteString("\n\n")
	}

	// Venue/Location
	if e.Format == "in-person" && e.VenueID != "" {
		b.WriteString(detailLabelStyle.Render("Venue ID: "))
		b.WriteString(detailValueStyle.Render(e.VenueID))
		b.WriteString("\n\n")
	}

	// Meeting URL for virtual events
	if e.Format == "virtual" && e.MeetingURL != "" {
		b.WriteString(detailLabelStyle.Render("Meeting URL: "))
		b.WriteString(detailValueStyle.Render(e.MeetingURL))
		b.WriteString("\n\n")
	}

	// Capacity
	if e.Capacity != nil {
		b.WriteString(detailLabelStyle.Render("Capacity: "))
		b.WriteString(detailValueStyle.Render(fmt.Sprintf("%d", *e.Capacity)))
		b.WriteString("\n\n")
	}

	// Short Description
	if e.ShortDescription != "" {
		b.WriteString(detailLabelStyle.Render("Summary:"))
		b.WriteString("\n")
		b.WriteString(detailValueStyle.Render(e.ShortDescription))
		b.WriteString("\n\n")
	}

	// Full Description
	if e.Description != "" {
		b.WriteString(detailLabelStyle.Render("Description:"))
		b.WriteString("\n")
		// Word wrap the description to fit the panel
		wrapped := wordWrap(e.Description, m.width-2)
		b.WriteString(detailValueStyle.Render(wrapped))
	}

	return b.String()
}

// wordWrap wraps text to the specified width
func wordWrap(text string, width int) string {
	if width <= 0 {
		return text
	}

	var result strings.Builder
	lines := strings.Split(text, "\n")

	for i, line := range lines {
		if i > 0 {
			result.WriteString("\n")
		}

		words := strings.Fields(line)
		if len(words) == 0 {
			continue
		}

		lineLen := 0
		for j, word := range words {
			wordLen := len(word)

			if lineLen+wordLen+1 > width && lineLen > 0 {
				result.WriteString("\n")
				lineLen = 0
			} else if j > 0 {
				result.WriteString(" ")
				lineLen++
			}

			result.WriteString(word)
			lineLen += wordLen
		}
	}

	return result.String()
}

// Init initializes the event detail view
func (m EventDetail) Init() tea.Cmd {
	return nil
}

// Update handles messages for the event detail view
func (m EventDetail) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.SetSize(msg.Width, msg.Height)
		return m, nil
	}

	m.viewport, cmd = m.viewport.Update(msg)
	return m, cmd
}

// View renders the event detail view
func (m EventDetail) View() string {
	return m.viewport.View()
}

// ScrollUp scrolls the viewport up
func (m *EventDetail) ScrollUp() {
	m.viewport.LineUp(1)
}

// ScrollDown scrolls the viewport down
func (m *EventDetail) ScrollDown() {
	m.viewport.LineDown(1)
}

// ScrollToTop scrolls to the top
func (m *EventDetail) ScrollToTop() {
	m.viewport.GotoTop()
}
