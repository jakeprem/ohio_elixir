package views

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	helpOverlayStyle = lipgloss.NewStyle().
				Border(lipgloss.RoundedBorder()).
				BorderForeground(lipgloss.Color("#7D56F4")).
				Padding(1, 2).
				Background(lipgloss.Color("#1E1E1E"))

	helpTitleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#7D56F4")).
			MarginBottom(1)

	helpSectionStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("#04B575")).
				MarginTop(1)

	helpKeyStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#7D56F4")).
			Bold(true).
			Width(12)

	helpDescStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFFDF5"))
)

// HelpOverlay displays a full-screen help overlay
type HelpOverlay struct {
	width  int
	height int
}

// NewHelpOverlay creates a new help overlay
func NewHelpOverlay(width, height int) HelpOverlay {
	return HelpOverlay{
		width:  width,
		height: height,
	}
}

// SetSize updates the overlay dimensions
func (m *HelpOverlay) SetSize(width, height int) {
	m.width = width
	m.height = height
}

// Init initializes the help overlay
func (m HelpOverlay) Init() tea.Cmd {
	return nil
}

// Update handles messages for the help overlay
func (m HelpOverlay) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	return m, nil
}

// View renders the help overlay
func (m HelpOverlay) View() string {
	var b strings.Builder

	b.WriteString(helpTitleStyle.Render("Keyboard Shortcuts"))
	b.WriteString("\n")

	// Navigation section
	b.WriteString(helpSectionStyle.Render("Navigation"))
	b.WriteString("\n")
	b.WriteString(m.renderKey("j / down", "Move down"))
	b.WriteString(m.renderKey("k / up", "Move up"))
	b.WriteString(m.renderKey("g", "Go to top"))
	b.WriteString(m.renderKey("G", "Go to bottom"))
	b.WriteString(m.renderKey("Tab", "Switch panel focus"))
	b.WriteString(m.renderKey("/", "Search/filter events"))

	// Actions section
	b.WriteString("\n")
	b.WriteString(helpSectionStyle.Render("Actions"))
	b.WriteString("\n")
	b.WriteString(m.renderKey("Enter", "View event details"))
	b.WriteString(m.renderKey("p", "Publish draft event"))
	b.WriteString(m.renderKey("x", "Cancel event"))
	b.WriteString(m.renderKey("e", "Edit event description"))
	b.WriteString(m.renderKey("r", "Refresh events list"))

	// General section
	b.WriteString("\n")
	b.WriteString(helpSectionStyle.Render("General"))
	b.WriteString("\n")
	b.WriteString(m.renderKey("?", "Toggle this help"))
	b.WriteString(m.renderKey("q", "Quit"))
	b.WriteString(m.renderKey("Esc", "Close dialog/go back"))

	content := b.String()

	// Calculate overlay size
	overlayWidth := 50
	overlayHeight := 24

	// Ensure it fits
	if overlayWidth > m.width-4 {
		overlayWidth = m.width - 4
	}
	if overlayHeight > m.height-4 {
		overlayHeight = m.height - 4
	}

	styled := helpOverlayStyle.
		Width(overlayWidth).
		Render(content)

	// Center the overlay
	return lipgloss.Place(
		m.width, m.height,
		lipgloss.Center, lipgloss.Center,
		styled,
	)
}

func (m HelpOverlay) renderKey(key, desc string) string {
	return helpKeyStyle.Render(key) + helpDescStyle.Render(desc) + "\n"
}
