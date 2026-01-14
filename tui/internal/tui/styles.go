package tui

import "github.com/charmbracelet/lipgloss"

var (
	// Colors - Lazygit-inspired palette
	PrimaryColor    = lipgloss.Color("#7D56F4") // Purple accent
	SecondaryColor  = lipgloss.Color("#04B575") // Green for success
	ErrorColor      = lipgloss.Color("#FF5F56") // Red for errors
	WarningColor    = lipgloss.Color("#FFCC00") // Yellow for warnings/draft
	MutedColor      = lipgloss.Color("#626262") // Gray for muted text
	HighlightColor  = lipgloss.Color("#FFFDF5") // Light for highlights
	BorderColor     = lipgloss.Color("#3D3D3D") // Inactive border
	ActiveColor     = lipgloss.Color("#7D56F4") // Active border (same as primary)
	BackgroundColor = lipgloss.Color("#1E1E1E") // Dark background

	// Panel styles - Lazygit-inspired bordered panels
	ActivePanelStyle = lipgloss.NewStyle().
				Border(lipgloss.RoundedBorder()).
				BorderForeground(ActiveColor)

	InactivePanelStyle = lipgloss.NewStyle().
				Border(lipgloss.RoundedBorder()).
				BorderForeground(BorderColor)

	// Panel title styles
	ActiveTitleStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(ActiveColor).
				Padding(0, 1)

	InactiveTitleStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(BorderColor).
				Padding(0, 1)

	// Header
	HeaderStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(PrimaryColor).
			Padding(0, 1)

	// Title style
	TitleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(PrimaryColor)

	// Status bar (bottom help bar)
	StatusBarStyle = lipgloss.NewStyle().
			Foreground(HighlightColor).
			Background(lipgloss.Color("#353533")).
			Padding(0, 1)

	// Status badges
	StatusDraft = lipgloss.NewStyle().
			Foreground(WarningColor).
			Bold(true)

	StatusPublished = lipgloss.NewStyle().
			Foreground(SecondaryColor).
			Bold(true)

	StatusCancelled = lipgloss.NewStyle().
			Foreground(ErrorColor).
			Bold(true)

	// Help bar styles
	HelpKeyStyle = lipgloss.NewStyle().
			Foreground(PrimaryColor).
			Bold(true)

	HelpDescStyle = lipgloss.NewStyle().
			Foreground(MutedColor)

	HelpBarStyle = lipgloss.NewStyle().
			Background(lipgloss.Color("#252525")).
			Foreground(HighlightColor).
			Padding(0, 1)

	// Error display
	ErrorStyle = lipgloss.NewStyle().
			Foreground(ErrorColor).
			Bold(true)

	// Success display
	SuccessStyle = lipgloss.NewStyle().
			Foreground(SecondaryColor).
			Bold(true)

	// List item styles
	SelectedItemStyle = lipgloss.NewStyle().
				Foreground(HighlightColor).
				Background(lipgloss.Color("#3D3D3D")).
				Bold(true)

	NormalItemStyle = lipgloss.NewStyle().
			Foreground(HighlightColor)

	// Detail view styles
	DetailLabelStyle = lipgloss.NewStyle().
				Foreground(MutedColor).
				Bold(true)

	DetailValueStyle = lipgloss.NewStyle().
				Foreground(HighlightColor)

	DetailTitleStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(PrimaryColor).
				MarginBottom(1)

	// Confirmation dialog styles
	DialogStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(PrimaryColor).
			Padding(1, 2).
			Background(lipgloss.Color("#2D2D2D"))

	DialogTitleStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(WarningColor)

	DialogButtonStyle = lipgloss.NewStyle().
				Padding(0, 2).
				Background(lipgloss.Color("#3D3D3D")).
				Foreground(HighlightColor)

	DialogButtonActiveStyle = lipgloss.NewStyle().
				Padding(0, 2).
				Background(PrimaryColor).
				Foreground(HighlightColor).
				Bold(true)

	// Spinner style
	SpinnerStyle = lipgloss.NewStyle().
			Foreground(PrimaryColor)
)

// FormatStatus returns a styled status string
func FormatStatus(status string) string {
	switch status {
	case "draft":
		return StatusDraft.Render(status)
	case "published":
		return StatusPublished.Render(status)
	case "cancelled":
		return StatusCancelled.Render(status)
	default:
		return status
	}
}

// RenderPanel renders content inside a panel with a title
func RenderPanel(title, content string, width, height int, active bool) string {
	var style lipgloss.Style
	var titleStyle lipgloss.Style

	if active {
		style = ActivePanelStyle
		titleStyle = ActiveTitleStyle
	} else {
		style = InactivePanelStyle
		titleStyle = InactiveTitleStyle
	}

	// Account for border (2 chars each side)
	innerWidth := width - 2
	innerHeight := height - 2

	if innerWidth < 1 {
		innerWidth = 1
	}
	if innerHeight < 1 {
		innerHeight = 1
	}

	// Render title in top border
	renderedTitle := titleStyle.Render(title)

	// Pad/truncate content to fill panel
	contentStyle := lipgloss.NewStyle().
		Width(innerWidth).
		Height(innerHeight)

	renderedContent := contentStyle.Render(content)

	panel := style.
		Width(width).
		Height(height).
		Render(renderedContent)

	// Overlay title on top border
	lines := []rune(panel)
	titleRunes := []rune(renderedTitle)

	// Find position to insert title (after first border corner + 1)
	insertPos := 2
	if insertPos+len(titleRunes) < len(lines) {
		for i, r := range titleRunes {
			if insertPos+i < len(lines) {
				lines[insertPos+i] = r
			}
		}
	}

	return string(lines)
}
