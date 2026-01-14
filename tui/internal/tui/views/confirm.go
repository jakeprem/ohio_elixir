package views

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	dialogStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#7D56F4")).
			Padding(1, 2).
			Background(lipgloss.Color("#2D2D2D"))

	dialogTitleStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("#FFCC00"))

	dialogMessageStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FFFDF5")).
				MarginTop(1).
				MarginBottom(1)

	dialogButtonStyle = lipgloss.NewStyle().
				Padding(0, 2).
				Background(lipgloss.Color("#3D3D3D")).
				Foreground(lipgloss.Color("#FFFDF5"))

	dialogButtonActiveStyle = lipgloss.NewStyle().
				Padding(0, 2).
				Background(lipgloss.Color("#7D56F4")).
				Foreground(lipgloss.Color("#FFFDF5")).
				Bold(true)

	dialogHintStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#626262")).
			MarginTop(1)
)

// ConfirmAction represents the type of action being confirmed
type ConfirmAction int

const (
	ConfirmNone ConfirmAction = iota
	ConfirmPublish
	ConfirmCancel
)

// ConfirmDialog displays a confirmation dialog for destructive actions
type ConfirmDialog struct {
	Action    ConfirmAction
	EventID   string
	EventName string
	Confirmed bool
	width     int
	height    int
}

// NewConfirmDialog creates a new confirmation dialog
func NewConfirmDialog(width, height int) ConfirmDialog {
	return ConfirmDialog{
		Action: ConfirmNone,
		width:  width,
		height: height,
	}
}

// Show displays the dialog for a specific action
func (m *ConfirmDialog) Show(action ConfirmAction, eventID, eventName string) {
	m.Action = action
	m.EventID = eventID
	m.EventName = eventName
	m.Confirmed = false
}

// Hide closes the dialog
func (m *ConfirmDialog) Hide() {
	m.Action = ConfirmNone
	m.EventID = ""
	m.EventName = ""
	m.Confirmed = false
}

// IsVisible returns true if the dialog is showing
func (m ConfirmDialog) IsVisible() bool {
	return m.Action != ConfirmNone
}

// SetSize updates the dialog dimensions
func (m *ConfirmDialog) SetSize(width, height int) {
	m.width = width
	m.height = height
}

// Init initializes the confirm dialog
func (m ConfirmDialog) Init() tea.Cmd {
	return nil
}

// ConfirmResultMsg is sent when the user confirms or cancels
type ConfirmResultMsg struct {
	Action    ConfirmAction
	EventID   string
	Confirmed bool
}

// Update handles messages for the confirm dialog
func (m ConfirmDialog) Update(msg tea.Msg) (ConfirmDialog, tea.Cmd) {
	if !m.IsVisible() {
		return m, nil
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "y", "Y", "enter":
			m.Confirmed = true
			result := ConfirmResultMsg{
				Action:    m.Action,
				EventID:   m.EventID,
				Confirmed: true,
			}
			m.Hide()
			return m, func() tea.Msg { return result }

		case "n", "N", "esc", "q":
			result := ConfirmResultMsg{
				Action:    m.Action,
				EventID:   m.EventID,
				Confirmed: false,
			}
			m.Hide()
			return m, func() tea.Msg { return result }
		}
	}

	return m, nil
}

// View renders the confirm dialog
func (m ConfirmDialog) View() string {
	if !m.IsVisible() {
		return ""
	}

	var title, message string

	switch m.Action {
	case ConfirmPublish:
		title = "Publish Event?"
		message = fmt.Sprintf("Are you sure you want to publish\n\"%s\"?", m.EventName)
	case ConfirmCancel:
		title = "Cancel Event?"
		message = fmt.Sprintf("Are you sure you want to cancel\n\"%s\"?\n\nThis cannot be undone.", m.EventName)
	default:
		return ""
	}

	content := lipgloss.JoinVertical(lipgloss.Left,
		dialogTitleStyle.Render(title),
		dialogMessageStyle.Render(message),
		lipgloss.JoinHorizontal(lipgloss.Top,
			dialogButtonActiveStyle.Render("[Y]es"),
			"  ",
			dialogButtonStyle.Render("[N]o"),
		),
		dialogHintStyle.Render("Press Y to confirm, N or Esc to cancel"),
	)

	styled := dialogStyle.Render(content)

	// Center the dialog
	return lipgloss.Place(
		m.width, m.height,
		lipgloss.Center, lipgloss.Center,
		styled,
	)
}
