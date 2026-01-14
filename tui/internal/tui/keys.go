package tui

import "github.com/charmbracelet/bubbles/key"

type KeyMap struct {
	// Global
	Quit key.Binding
	Help key.Binding

	// Section switching
	EventsSection key.Binding
	VenuesSection key.Binding

	// Navigation
	Up       key.Binding
	Down     key.Binding
	Enter    key.Binding
	Back     key.Binding
	Tab      key.Binding
	GoTop    key.Binding
	GoBottom key.Binding

	// Actions
	New     key.Binding
	Edit    key.Binding
	Delete  key.Binding
	Publish key.Binding
	Cancel  key.Binding
	Refresh key.Binding
	Search  key.Binding

	// Attendee actions
	MarkAttended  key.Binding
	CancelRSVP    key.Binding
	ExportCSV     key.Binding

	// Confirm dialog
	Yes key.Binding
	No  key.Binding
}

var DefaultKeyMap = KeyMap{
	Quit: key.NewBinding(
		key.WithKeys("q", "ctrl+c"),
		key.WithHelp("q", "quit"),
	),
	Help: key.NewBinding(
		key.WithKeys("?"),
		key.WithHelp("?", "help"),
	),
	EventsSection: key.NewBinding(
		key.WithKeys("1"),
		key.WithHelp("1", "events"),
	),
	VenuesSection: key.NewBinding(
		key.WithKeys("2"),
		key.WithHelp("2", "venues"),
	),
	Up: key.NewBinding(
		key.WithKeys("up", "k"),
		key.WithHelp("j/k", "navigate"),
	),
	Down: key.NewBinding(
		key.WithKeys("down", "j"),
		key.WithHelp("j/k", "navigate"),
	),
	Enter: key.NewBinding(
		key.WithKeys("enter"),
		key.WithHelp("enter", "select"),
	),
	Back: key.NewBinding(
		key.WithKeys("esc"),
		key.WithHelp("esc", "back"),
	),
	Tab: key.NewBinding(
		key.WithKeys("tab"),
		key.WithHelp("tab", "switch panel"),
	),
	GoTop: key.NewBinding(
		key.WithKeys("g"),
		key.WithHelp("g", "go to top"),
	),
	GoBottom: key.NewBinding(
		key.WithKeys("G"),
		key.WithHelp("G", "go to bottom"),
	),
	New: key.NewBinding(
		key.WithKeys("n"),
		key.WithHelp("n", "new"),
	),
	Edit: key.NewBinding(
		key.WithKeys("e"),
		key.WithHelp("e", "edit"),
	),
	Delete: key.NewBinding(
		key.WithKeys("d"),
		key.WithHelp("d", "delete"),
	),
	Publish: key.NewBinding(
		key.WithKeys("p"),
		key.WithHelp("p", "publish"),
	),
	Cancel: key.NewBinding(
		key.WithKeys("x"),
		key.WithHelp("x", "cancel"),
	),
	Refresh: key.NewBinding(
		key.WithKeys("r"),
		key.WithHelp("r", "refresh"),
	),
	Search: key.NewBinding(
		key.WithKeys("/"),
		key.WithHelp("/", "search"),
	),
	MarkAttended: key.NewBinding(
		key.WithKeys("a"),
		key.WithHelp("a", "mark attended"),
	),
	CancelRSVP: key.NewBinding(
		key.WithKeys("c"),
		key.WithHelp("c", "cancel RSVP"),
	),
	ExportCSV: key.NewBinding(
		key.WithKeys("X"),
		key.WithHelp("X", "export CSV"),
	),
	Yes: key.NewBinding(
		key.WithKeys("y", "Y"),
		key.WithHelp("y", "yes"),
	),
	No: key.NewBinding(
		key.WithKeys("n", "N"),
		key.WithHelp("n", "no"),
	),
}

// ShortHelp returns keybindings to show in the mini help view
func (k KeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Help, k.Quit}
}

// FullHelp returns keybindings for the expanded help view
func (k KeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Up, k.Down, k.Tab, k.GoTop, k.GoBottom},
		{k.Enter, k.Edit, k.Publish, k.Cancel},
		{k.Refresh, k.Search, k.Help, k.Quit},
	}
}
