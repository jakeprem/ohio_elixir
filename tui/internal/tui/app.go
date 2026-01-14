package tui

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/jakeprem/ohio_elixir/tui/internal/api"
	"github.com/jakeprem/ohio_elixir/tui/internal/config"
	"github.com/jakeprem/ohio_elixir/tui/internal/tui/views"
)

// PanelFocus indicates which panel has focus
type PanelFocus int

const (
	FocusEvents PanelFocus = iota
	FocusVenues
	FocusDetail
	FocusAttendees
)

// App is the root model for the TUI application
type App struct {
	// Dependencies
	client *api.Client

	// Dimensions
	width  int
	height int
	ready  bool

	// Auth state
	authenticated bool
	userEmail     string

	// Section and view state
	currentSection  SectionType
	currentView     ViewType
	focusedPanel    PanelFocus
	editingType     string // "event" or "venue"

	// Events section
	eventsList       views.EventsList
	eventDetail      views.EventDetail
	editForm         views.EditForm
	eventForm        views.EventForm
	eventsListReady  bool
	attendeesPanel   views.AttendeesPanel
	attendeesEventID string // Track which event's attendees are loaded

	// Venues section
	venuesList      views.VenuesList
	venueDetail     views.VenueDetail
	venueForm       views.VenueForm
	venuesListReady bool

	// Cached data
	venues []api.Venue

	// Overlays
	showHelp      bool
	helpOverlay   views.HelpOverlay
	confirmDialog views.ConfirmDialog

	// Loading state
	loading    bool
	loadingMsg string
	spinner    spinner.Model

	// Error/status state
	err       error
	statusMsg string

	// Key bindings
	keys KeyMap
}

// NewApp creates a new TUI application
func NewApp(client *api.Client) App {
	cfg := config.Get()

	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = SpinnerStyle

	return App{
		client:        client,
		authenticated: cfg.Token != "",
		userEmail:     cfg.Email,
		currentView:   ViewList,
		focusedPanel:  FocusEvents,
		spinner:       s,
		loading:       true,
		loadingMsg:    "Loading data...",
		keys:          DefaultKeyMap,
	}
}

// Init initializes the application
func (m App) Init() tea.Cmd {
	if !m.authenticated {
		return nil
	}
	// Load both events and venues at startup
	return tea.Batch(
		m.spinner.Tick,
		LoadEvents(m.client),
		LoadVenues(m.client),
	)
}

// Update handles messages
func (m App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	// Handle confirmation dialog first if visible
	if m.confirmDialog.IsVisible() {
		switch msg := msg.(type) {
		case tea.KeyMsg:
			var cmd tea.Cmd
			m.confirmDialog, cmd = m.confirmDialog.Update(msg)
			if cmd != nil {
				cmds = append(cmds, cmd)
			}
			return m, tea.Batch(cmds...)

		case views.ConfirmResultMsg:
			if msg.Confirmed {
				switch msg.Action {
				case views.ConfirmPublish:
					m.loading = true
					m.loadingMsg = "Publishing..."
					cmds = append(cmds, PublishEvent(m.client, msg.EventID))
				case views.ConfirmCancel:
					m.loading = true
					m.loadingMsg = "Cancelling..."
					cmds = append(cmds, CancelEvent(m.client, msg.EventID))
				}
			}
			return m, tea.Batch(cmds...)
		}
	}

	// Handle help overlay
	if m.showHelp {
		switch msg := msg.(type) {
		case tea.KeyMsg:
			switch msg.String() {
			case "?", "esc", "q":
				m.showHelp = false
				return m, nil
			}
		case tea.WindowSizeMsg:
			m.width = msg.Width
			m.height = msg.Height
			m.helpOverlay.SetSize(msg.Width, msg.Height)
			return m, nil
		}
		return m, nil
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		// Clear error on any keypress
		if m.err != nil {
			m.err = nil
		}
		// Clear status on any keypress (unless we're searching)
		if m.statusMsg != "" && !m.eventsList.IsSearching() {
			m.statusMsg = ""
		}

		// Handle edit mode - let form handle keys
		if m.currentView == ViewEdit {
			if m.currentSection == SectionEvents {
				var cmd tea.Cmd
				m.editForm, cmd = m.editForm.Update(msg)
				if cmd != nil {
					cmds = append(cmds, cmd)
				}
			} else if m.currentSection == SectionVenues {
				var cmd tea.Cmd
				m.venueForm, cmd = m.venueForm.Update(msg)
				if cmd != nil {
					cmds = append(cmds, cmd)
				}
			}
			return m, tea.Batch(cmds...)
		}

		// Handle create mode - let form handle keys
		if m.currentView == ViewCreate {
			if m.currentSection == SectionEvents {
				var cmd tea.Cmd
				m.eventForm, cmd = m.eventForm.Update(msg)
				if cmd != nil {
					cmds = append(cmds, cmd)
				}
			} else if m.currentSection == SectionVenues {
				var cmd tea.Cmd
				m.venueForm, cmd = m.venueForm.Update(msg)
				if cmd != nil {
					cmds = append(cmds, cmd)
				}
			}
			return m, tea.Batch(cmds...)
		}

		// Don't handle global keys while searching
		if m.eventsList.IsSearching() {
			return m.updateEventsList(msg)
		}

		// Global keys
		switch {
		case key.Matches(msg, m.keys.Quit):
			return m, tea.Quit

		case key.Matches(msg, m.keys.Help):
			m.showHelp = true
			return m, nil

		// Number keys for quick panel focus
		case key.Matches(msg, m.keys.EventsSection): // "1"
			m.currentSection = SectionEvents
			m.focusedPanel = FocusEvents
			m.attendeesPanel.SetFocused(false)
			return m, nil

		case key.Matches(msg, m.keys.VenuesSection): // "2"
			m.currentSection = SectionVenues
			m.focusedPanel = FocusVenues
			m.attendeesPanel.SetFocused(false)
			return m, nil

		case msg.String() == "3":
			m.focusedPanel = FocusDetail
			m.attendeesPanel.SetFocused(false)
			return m, nil

		case msg.String() == "4":
			m.focusedPanel = FocusAttendees
			m.attendeesPanel.SetFocused(true)
			return m, nil

		case key.Matches(msg, m.keys.Tab):
			// Cycle forward: Events → Venues → Detail → Attendees → Events
			m.attendeesPanel.SetFocused(false)
			switch m.focusedPanel {
			case FocusEvents:
				m.focusedPanel = FocusVenues
			case FocusVenues:
				m.focusedPanel = FocusDetail
			case FocusDetail:
				m.focusedPanel = FocusAttendees
				m.attendeesPanel.SetFocused(true)
			case FocusAttendees:
				m.focusedPanel = FocusEvents
			}
			return m, nil

		case msg.String() == "shift+tab":
			// Cycle backward: Events → Attendees → Detail → Venues → Events
			m.attendeesPanel.SetFocused(false)
			switch m.focusedPanel {
			case FocusEvents:
				m.focusedPanel = FocusAttendees
				m.attendeesPanel.SetFocused(true)
			case FocusVenues:
				m.focusedPanel = FocusEvents
			case FocusDetail:
				m.focusedPanel = FocusVenues
			case FocusAttendees:
				m.focusedPanel = FocusDetail
			}
			return m, nil

		case key.Matches(msg, m.keys.Refresh):
			m.loading = true
			m.loadingMsg = "Refreshing..."
			if m.currentSection == SectionEvents {
				return m, LoadEvents(m.client)
			}
			return m, LoadVenues(m.client)

		case key.Matches(msg, m.keys.Publish):
			if m.currentSection == SectionEvents {
				if event := m.eventsList.SelectedEvent(); event != nil {
					if event.Status == "draft" {
						m.confirmDialog.Show(views.ConfirmPublish, event.ID, event.Title)
					} else {
						m.statusMsg = "Only draft events can be published"
					}
				}
			}
			return m, nil

		case key.Matches(msg, m.keys.Cancel):
			if m.currentSection == SectionEvents {
				if event := m.eventsList.SelectedEvent(); event != nil {
					if event.Status != "cancelled" {
						m.confirmDialog.Show(views.ConfirmCancel, event.ID, event.Title)
					} else {
						m.statusMsg = "Event is already cancelled"
					}
				}
			}
			return m, nil

		case key.Matches(msg, m.keys.New):
			m.attendeesPanel.SetFocused(false)
			if m.currentSection == SectionEvents {
				// Create new event
				m.currentView = ViewCreate
				_, detailWidth, contentHeight := m.calculatePanelSizes()
				m.eventForm = views.NewEventForm(m.venues, detailWidth-2, contentHeight-2)
				initCmd := m.eventForm.Init()
				// Load venues if not already loaded
				if len(m.venues) == 0 {
					return m, tea.Batch(initCmd, LoadVenues(m.client))
				}
				return m, initCmd
			} else if m.currentSection == SectionVenues {
				// Create new venue
				m.currentView = ViewCreate
				_, detailWidth, contentHeight := m.calculatePanelSizes()
				m.venueForm = views.NewVenueForm(detailWidth-2, contentHeight-2)
				return m, m.venueForm.Init()
			}
			return m, nil

		case key.Matches(msg, m.keys.Edit):
			m.attendeesPanel.SetFocused(false)
			if m.currentSection == SectionEvents {
				if event := m.eventsList.SelectedEvent(); event != nil {
					// Enter edit mode
					m.currentView = ViewEdit
					m.editingType = "event"
					_, detailWidth, contentHeight := m.calculatePanelSizes()
					m.editForm = views.NewEditForm(event, m.venues, detailWidth-2, contentHeight-2)
					initCmd := m.editForm.Init()
					// Load venues if not already loaded
					if len(m.venues) == 0 {
						return m, tea.Batch(initCmd, LoadVenues(m.client))
					}
					return m, initCmd
				}
			} else if m.currentSection == SectionVenues {
				if venue := m.venuesList.SelectedVenue(); venue != nil {
					m.currentView = ViewEdit
					m.editingType = "venue"
					_, detailWidth, contentHeight := m.calculatePanelSizes()
					m.venueForm = views.NewVenueEditForm(venue, detailWidth-2, contentHeight-2)
					return m, m.venueForm.Init()
				}
			}
			return m, nil

		case key.Matches(msg, m.keys.Back):
			// Clear search if active
			if m.eventsList.IsSearching() {
				m.eventsList.ClearSearch()
			}
			return m, nil
		}

		// Handle navigation based on focused panel
		switch m.focusedPanel {
		case FocusEvents:
			return m.updateEventsList(msg)
		case FocusVenues:
			return m.updateVenuesList(msg)
		case FocusDetail:
			// Detail shows event or venue based on which list was last selected
			return m.updateEventDetail(msg)
		case FocusAttendees:
			return m.updateAttendeesPanel(msg)
		}
		return m, nil

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.ready = true

		// Calculate panel dimensions (same as renderPanels)
		_, _, contentHeight := m.calculatePanelSizes()

		leftWidth := m.width * 35 / 100
		rightWidth := m.width - leftWidth

		eventsHeight := contentHeight / 2
		venuesHeight := contentHeight - eventsHeight

		detailHeight := contentHeight * 60 / 100
		attendeesHeight := contentHeight - detailHeight

		// Update all panel dimensions
		m.eventsList.SetSize(leftWidth-2, eventsHeight-4)
		m.venuesList.SetSize(leftWidth-2, venuesHeight-4)
		m.eventDetail.SetSize(rightWidth-2, detailHeight-4)
		m.venueDetail.SetSize(rightWidth-2, detailHeight-4)
		m.attendeesPanel.SetSize(rightWidth-2, attendeesHeight-4)

		m.helpOverlay.SetSize(msg.Width, msg.Height)
		m.confirmDialog.SetSize(msg.Width, msg.Height)
		return m, nil

	case spinner.TickMsg:
		if m.loading {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			cmds = append(cmds, cmd)
		}

	case EventsLoadedMsg:
		m.loading = false
		m.loadingMsg = ""

		listWidth, detailWidth, contentHeight := m.calculatePanelSizes()

		// Initialize views if not ready
		if !m.eventsListReady {
			m.eventsList = views.NewEventsList(m.client, listWidth-2, contentHeight-2)
			m.eventDetail = views.NewEventDetail(detailWidth-2, contentHeight-2)
			m.helpOverlay = views.NewHelpOverlay(m.width, m.height)
			m.confirmDialog = views.NewConfirmDialog(m.width, m.height)
			m.eventsListReady = true
		}

		// Update events list
		viewMsg := views.EventsLoadedMsg{Events: msg.Events}
		model, cmd := m.eventsList.Update(viewMsg)
		if el, ok := model.(views.EventsList); ok {
			m.eventsList = el
		}
		cmds = append(cmds, cmd)

		// Update detail view with first event and load attendees
		if len(msg.Events) > 0 {
			m.eventDetail.SetEvent(&msg.Events[0])
			m.attendeesEventID = msg.Events[0].ID
			m.attendeesPanel.SetEventID(msg.Events[0].ID)
			cmds = append(cmds, LoadAttendeesCmd(m.client, msg.Events[0].ID))
		}

	case EventPublishedMsg:
		m.loading = false
		m.statusMsg = fmt.Sprintf("Published: %s", msg.Event.Title)
		cmds = append(cmds, LoadEvents(m.client))

	case EventCancelledMsg:
		m.loading = false
		m.statusMsg = fmt.Sprintf("Cancelled: %s", msg.Event.Title)
		cmds = append(cmds, LoadEvents(m.client))

	case EventUpdatedMsg:
		m.loading = false
		m.statusMsg = fmt.Sprintf("Updated: %s", msg.Event.Title)
		cmds = append(cmds, LoadEvents(m.client))

	case EditorReturnedMsg:
		m.loading = false
		if msg.Err != nil {
			m.err = msg.Err
		} else if msg.Content != "" {
			// If in edit mode, just update the form's description
			if m.currentView == ViewEdit {
				m.editForm.SetDescription(msg.Content)
			} else {
				m.loading = true
				m.loadingMsg = "Saving..."
				cmds = append(cmds, UpdateEventDescription(m.client, msg.EventID, msg.Content))
			}
		}

	case ErrMsg:
		m.loading = false
		m.err = msg.Err

	case StatusMsg:
		m.statusMsg = string(msg)

	case VenuesLoadedMsg:
		m.venues = msg.Venues
		m.loading = false

		// Always initialize/update the venues list (all panels visible now)
		listWidth, detailWidth, contentHeight := m.calculatePanelSizes()

		if !m.venuesListReady {
			m.venuesList = views.NewVenuesList(listWidth-2, contentHeight-2)
			m.venueDetail = views.NewVenueDetail(detailWidth-2, contentHeight-2)
			m.venuesListReady = true
		}

		// Update venues list
		viewMsg := views.VenuesLoadedMsg{Venues: msg.Venues}
		model, cmd := m.venuesList.Update(viewMsg)
		if vl, ok := model.(views.VenuesList); ok {
			m.venuesList = vl
		}
		cmds = append(cmds, cmd)

		// Update detail view with first venue
		if len(msg.Venues) > 0 {
			m.venueDetail.SetVenue(&msg.Venues[0])
		}

		// Update edit form if in edit mode
		if m.currentView == ViewEdit {
			m.editForm.SetVenues(msg.Venues)
		}

	case views.EditFormSaveMsg:
		m.currentView = ViewList
		m.focusedPanel = FocusEvents
		m.loading = true
		m.loadingMsg = "Saving..."
		cmds = append(cmds, UpdateEventCmd(m.client, msg.EventID, msg.Update))

	case views.EditFormCancelMsg:
		m.currentView = ViewList
		m.focusedPanel = FocusEvents

	case views.EditDescriptionMsg:
		// Open external editor for description
		return m, m.editDescription(msg.EventID, msg.Description)

	case views.EventFormCreateMsg:
		m.currentView = ViewList
		m.focusedPanel = FocusEvents
		m.loading = true
		m.loadingMsg = "Creating event..."
		cmds = append(cmds, CreateEventCmd(m.client, msg.Title, msg.Description, msg.ShortDescription, msg.Format, msg.StartsAt, msg.EndsAt, msg.Timezone, msg.MeetingURL, msg.Capacity))

	case views.EventFormCancelMsg:
		m.currentView = ViewList
		m.focusedPanel = FocusEvents

	case views.VenueFormSaveMsg:
		m.currentView = ViewList
		m.focusedPanel = FocusVenues
		m.loading = true
		if msg.IsCreate {
			m.loadingMsg = "Creating venue..."
			cmds = append(cmds, CreateVenueCmd(m.client, &msg.Venue))
		} else {
			m.loadingMsg = "Updating venue..."
			cmds = append(cmds, UpdateVenueCmd(m.client, msg.VenueID, &msg.Venue))
		}

	case views.VenueFormCancelMsg:
		m.currentView = ViewList
		m.focusedPanel = FocusVenues

	case EventCreatedMsg:
		m.loading = false
		m.statusMsg = fmt.Sprintf("Created: %s", msg.Event.Title)
		cmds = append(cmds, LoadEvents(m.client))

	case VenueCreatedMsg:
		m.loading = false
		m.statusMsg = fmt.Sprintf("Created: %s", msg.Venue.Name)
		cmds = append(cmds, LoadVenues(m.client))

	case VenueUpdatedMsg:
		m.loading = false
		m.statusMsg = fmt.Sprintf("Updated: %s", msg.Venue.Name)
		cmds = append(cmds, LoadVenues(m.client))

	case VenueDeletedMsg:
		m.loading = false
		m.statusMsg = "Venue deleted"
		cmds = append(cmds, LoadVenues(m.client))

	case AttendeesLoadedMsg:
		m.attendeesPanel.SetAttendees(msg.Attendees)

	case AttendeeMarkedMsg:
		m.statusMsg = fmt.Sprintf("Marked %s as attended", msg.Attendee.Name)
		// Reload attendees
		if m.attendeesEventID != "" {
			cmds = append(cmds, LoadAttendeesCmd(m.client, m.attendeesEventID))
		}

	case RSVPCancelledMsg:
		m.statusMsg = "RSVP cancelled"
		// Reload attendees
		if m.attendeesEventID != "" {
			cmds = append(cmds, LoadAttendeesCmd(m.client, m.attendeesEventID))
		}

	case views.AttendeeMarkMsg:
		cmds = append(cmds, MarkAttendeeCmd(m.client, msg.AttendeeID))

	case views.AttendeeCancelMsg:
		cmds = append(cmds, CancelRSVPCmd(m.client, msg.AttendeeID))

	case views.AttendeeExportMsg:
		// Export attendees to CSV
		if attendees := m.attendeesPanel.SelectedAttendee(); attendees != nil || len(m.attendeesPanel.View()) > 0 {
			// Get all attendees from panel and export
			m.statusMsg = "Attendee export not yet implemented"
		}
	}

	// Update child views if not loading
	if !m.loading {
		if m.currentSection == SectionEvents && m.eventsListReady {
			// Update detail view when selection changes
			if event := m.eventsList.SelectedEvent(); event != nil {
				m.eventDetail.SetEvent(event)
			}
		} else if m.currentSection == SectionVenues && m.venuesListReady {
			// Update venue detail view when selection changes
			if venue := m.venuesList.SelectedVenue(); venue != nil {
				m.venueDetail.SetVenue(venue)
			}
		}
	}

	return m, tea.Batch(cmds...)
}

func (m App) updateEventsList(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd
	model, cmd := m.eventsList.Update(msg)
	if cmd != nil {
		cmds = append(cmds, cmd)
	}
	if el, ok := model.(views.EventsList); ok {
		m.eventsList = el
		// Update detail when selection changes
		if event := m.eventsList.SelectedEvent(); event != nil {
			m.eventDetail.SetEvent(event)
			// Load attendees if event changed
			if event.ID != m.attendeesEventID {
				m.attendeesEventID = event.ID
				m.attendeesPanel.SetEventID(event.ID)
				cmds = append(cmds, LoadAttendeesCmd(m.client, event.ID))
			}
		}
	}
	return m, tea.Batch(cmds...)
}

func (m App) updateEventDetail(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch {
		case key.Matches(msg, m.keys.Up):
			m.eventDetail.ScrollUp()
		case key.Matches(msg, m.keys.Down):
			m.eventDetail.ScrollDown()
		case key.Matches(msg, m.keys.GoTop):
			m.eventDetail.ScrollToTop()
		}
	}
	return m, nil
}

func (m App) updateAttendeesPanel(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	m.attendeesPanel, cmd = m.attendeesPanel.Update(msg)
	return m, cmd
}

func (m App) updateVenuesList(msg tea.Msg) (tea.Model, tea.Cmd) {
	model, cmd := m.venuesList.Update(msg)
	if vl, ok := model.(views.VenuesList); ok {
		m.venuesList = vl
		// Update detail when selection changes
		if venue := m.venuesList.SelectedVenue(); venue != nil {
			m.venueDetail.SetVenue(venue)
		}
	}
	return m, cmd
}

func (m App) updateVenueDetail(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch {
		case key.Matches(msg, m.keys.Up):
			m.venueDetail.ScrollUp()
		case key.Matches(msg, m.keys.Down):
			m.venueDetail.ScrollDown()
		case key.Matches(msg, m.keys.GoTop):
			m.venueDetail.ScrollToTop()
		}
	}
	return m, nil
}

func (m App) editEventDescription(event *api.Event) tea.Cmd {
	return m.editDescription(event.ID, event.Description)
}

func (m App) editDescription(eventID, description string) tea.Cmd {
	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = os.Getenv("VISUAL")
	}
	if editor == "" {
		editor = "vim"
	}

	// Create temp file with content
	tmpfile, err := os.CreateTemp("", "ohio-*.md")
	if err != nil {
		return func() tea.Msg {
			return ErrMsg{Err: err}
		}
	}
	tmpfile.WriteString(description)
	tmpfile.Close()

	tmpPath := tmpfile.Name()

	c := exec.Command(editor, tmpPath)
	return tea.ExecProcess(c, func(err error) tea.Msg {
		defer os.Remove(tmpPath)
		if err != nil {
			return EditorReturnedMsg{Err: err}
		}
		content, readErr := os.ReadFile(tmpPath)
		if readErr != nil {
			return EditorReturnedMsg{Err: readErr}
		}
		return EditorReturnedMsg{
			EventID: eventID,
			Content: string(content),
		}
	})
}

func (m App) calculatePanelSizes() (listWidth, detailWidth, contentHeight int) {
	// Split width: 35% list, 65% detail
	listWidth = m.width * 35 / 100
	if listWidth < 30 {
		listWidth = 30
	}
	detailWidth = m.width - listWidth

	// Height: leave room for header (1 line) and help bar (1 line)
	contentHeight = m.height - 2
	if contentHeight < 5 {
		contentHeight = 5
	}

	return
}

// View renders the UI
func (m App) View() string {
	if !m.ready {
		return "Initializing..."
	}

	// If not authenticated, show login prompt
	if !m.authenticated {
		return m.renderUnauthenticated()
	}

	// Render overlays if active
	if m.showHelp {
		return m.helpOverlay.View()
	}

	if m.confirmDialog.IsVisible() {
		// Render dialog centered on screen
		dialog := m.confirmDialog.View()
		return dialog
	}

	return m.renderMainUI()
}

func (m App) renderMainUI() string {
	header := m.renderHeader()
	content := m.renderPanels()
	helpBar := m.renderHelpBar()

	return lipgloss.JoinVertical(lipgloss.Left,
		header,
		content,
		helpBar,
	)
}

func (m App) renderUnauthenticated() string {
	box := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(PrimaryColor).
		Padding(2, 4).
		Render(lipgloss.JoinVertical(lipgloss.Center,
			TitleStyle.Render("Lazyoh"),
			"",
			"Not logged in.",
			"",
			"Run 'ohio login' to authenticate,",
			"then restart the application.",
			"",
			HelpKeyStyle.Render("q")+" "+HelpDescStyle.Render("quit"),
		))

	return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, box)
}

func (m App) renderHeader() string {
	title := TitleStyle.Render(" Lazyoh ")
	user := HelpDescStyle.Render(m.userEmail + " ")

	// Fill space between title and user
	gap := m.width - lipgloss.Width(title) - lipgloss.Width(user)
	if gap < 0 {
		gap = 0
	}
	spacing := strings.Repeat(" ", gap)

	return lipgloss.JoinHorizontal(lipgloss.Top, title, spacing, user)
}

func (m App) renderPanels() string {
	_, _, contentHeight := m.calculatePanelSizes()

	if m.loading {
		loadingContent := fmt.Sprintf("\n  %s %s\n", m.spinner.View(), m.loadingMsg)
		return lipgloss.NewStyle().
			Width(m.width).
			Height(contentHeight).
			MaxHeight(contentHeight).
			Render(loadingContent)
	}

	if m.err != nil {
		errorContent := fmt.Sprintf("\n  %s\n", ErrorStyle.Render("Error: "+m.err.Error()))
		return lipgloss.NewStyle().
			Width(m.width).
			Height(contentHeight).
			MaxHeight(contentHeight).
			Render(errorContent)
	}

	// New lazygit-style layout: 4 panels always visible
	// Left column (35%): Events (top 50%) + Venues (bottom 50%)
	// Right column (65%): Details (top 60%) + Attendees (bottom 40%)

	leftWidth := m.width * 35 / 100
	rightWidth := m.width - leftWidth

	eventsHeight := contentHeight / 2
	venuesHeight := contentHeight - eventsHeight

	detailHeight := contentHeight * 60 / 100
	attendeesHeight := contentHeight - detailHeight

	// Handle edit/create views - they take over the right column
	if m.currentView == ViewEdit || m.currentView == ViewCreate {
		return m.renderWithForm(leftWidth, rightWidth, eventsHeight, venuesHeight, contentHeight)
	}

	// Normal view - all 4 panels visible
	return m.renderAllPanels(leftWidth, rightWidth, eventsHeight, venuesHeight, detailHeight, attendeesHeight)
}

func (m App) renderAllPanels(leftWidth, rightWidth, eventsHeight, venuesHeight, detailHeight, attendeesHeight int) string {
	// Update view sizes
	m.eventsList.SetSize(leftWidth-2, eventsHeight-4)
	m.venuesList.SetSize(leftWidth-2, venuesHeight-4)
	m.eventDetail.SetSize(rightWidth-2, detailHeight-4)
	m.venueDetail.SetSize(rightWidth-2, detailHeight-4)
	m.attendeesPanel.SetSize(rightWidth-2, attendeesHeight-4)

	// Left column: Events + Venues
	eventsContent := m.eventsList.View()
	if !m.eventsListReady {
		eventsContent = "  Loading events..."
	}
	eventsPanel := m.renderPanel("[1] Events", eventsContent, leftWidth, eventsHeight, m.focusedPanel == FocusEvents)

	venuesContent := m.venuesList.View()
	if !m.venuesListReady {
		venuesContent = "  Loading venues..."
	}
	venuesPanel := m.renderPanel("[2] Venues", venuesContent, leftWidth, venuesHeight, m.focusedPanel == FocusVenues)

	leftCol := lipgloss.JoinVertical(lipgloss.Left, eventsPanel, venuesPanel)

	// Right column layout depends on current section
	var rightCol string
	fullRightHeight := detailHeight + attendeesHeight
	if m.currentSection == SectionVenues {
		// Venues section: Detail panel takes full height (no attendees panel)
		m.venueDetail.SetSize(rightWidth-2, fullRightHeight-4)
		detailContent := m.venueDetail.View()
		detailPanel := m.renderPanel("[3] Venue Details", detailContent, rightWidth, fullRightHeight, m.focusedPanel == FocusDetail)
		rightCol = detailPanel
	} else {
		// Events section: Detail + Attendees panels
		detailContent := m.eventDetail.View()
		detailPanel := m.renderPanel("[3] Event Details", detailContent, rightWidth, detailHeight, m.focusedPanel == FocusDetail)

		attendeesContent := m.attendeesPanel.View()
		attendeesPanel := m.renderPanel("[4] Attendees", attendeesContent, rightWidth, attendeesHeight, m.focusedPanel == FocusAttendees)

		rightCol = lipgloss.JoinVertical(lipgloss.Left, detailPanel, attendeesPanel)
	}

	return lipgloss.JoinHorizontal(lipgloss.Top, leftCol, rightCol)
}

func (m App) renderWithForm(leftWidth, rightWidth, eventsHeight, venuesHeight, contentHeight int) string {
	// Update list sizes
	m.eventsList.SetSize(leftWidth-2, eventsHeight-4)
	m.venuesList.SetSize(leftWidth-2, venuesHeight-4)

	// Left column: Events + Venues (always visible)
	eventsContent := m.eventsList.View()
	if !m.eventsListReady {
		eventsContent = "  Loading events..."
	}
	eventsPanel := m.renderPanel("[1] Events", eventsContent, leftWidth, eventsHeight, m.focusedPanel == FocusEvents)

	venuesContent := m.venuesList.View()
	if !m.venuesListReady {
		venuesContent = "  Loading venues..."
	}
	venuesPanel := m.renderPanel("[2] Venues", venuesContent, leftWidth, venuesHeight, m.focusedPanel == FocusVenues)

	leftCol := lipgloss.JoinVertical(lipgloss.Left, eventsPanel, venuesPanel)

	// Right column: Form (takes full height)
	var formTitle string
	var formContent string

	switch m.currentView {
	case ViewEdit:
		if m.editingType == "venue" {
			formTitle = "Edit Venue"
			formContent = m.venueForm.View()
		} else {
			formTitle = "Edit Event"
			formContent = m.editForm.View()
		}
	case ViewCreate:
		formTitle = "New Event"
		formContent = m.eventForm.View()
	}

	formPanel := m.renderPanel(formTitle, formContent, rightWidth, contentHeight, true)

	return lipgloss.JoinHorizontal(lipgloss.Top, leftCol, formPanel)
}

func (m App) renderPanel(title, content string, width, height int, active bool) string {
	var borderStyle lipgloss.Style
	var titleStyle lipgloss.Style

	if active {
		borderStyle = ActivePanelStyle
		titleStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#7D56F4"))
	} else {
		borderStyle = InactivePanelStyle
		titleStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#626262"))
	}

	// Inner dimensions:
	// - border takes 2 lines vertically (top + bottom)
	// - border takes 2 chars horizontally (left + right)
	// - title takes 1 line
	innerWidth := width - 2
	innerHeight := height - 2 - 1 // -2 for border, -1 for title

	if innerWidth < 1 {
		innerWidth = 1
	}
	if innerHeight < 1 {
		innerHeight = 1
	}

	// Render title as first line of content
	styledTitle := titleStyle.Render(title)
	contentWithTitle := styledTitle + "\n" + content

	// Create content area with fixed dimensions
	// Use Height() only - it pads short content to fill space
	contentArea := lipgloss.NewStyle().
		Width(innerWidth).
		Height(innerHeight + 1). // +1 to include title line
		Render(contentWithTitle)

	// Create panel with border
	// Don't set Height on border - let it naturally wrap the content
	// Border adds 2 lines (top+bottom), content is already sized correctly
	panel := borderStyle.
		Width(width).
		Render(contentArea)

	return panel
}

func (m App) renderHelpBar() string {
	var help string

	if m.statusMsg != "" {
		help = m.statusMsg
	} else if m.err != nil {
		help = ErrorStyle.Render(m.err.Error())
	} else if m.currentView == ViewEdit || m.currentView == ViewCreate {
		help = fmt.Sprintf(
			"%s %s  %s %s  %s %s",
			HelpKeyStyle.Render("j/k"), HelpDescStyle.Render("navigate"),
			HelpKeyStyle.Render("i/Enter"), HelpDescStyle.Render("edit field"),
			HelpKeyStyle.Render("Esc"), HelpDescStyle.Render("cancel"),
		)
	} else if m.focusedPanel == FocusAttendees {
		help = fmt.Sprintf(
			"%s %s  %s %s  %s %s  %s %s  %s %s",
			HelpKeyStyle.Render("Tab/1-4"), HelpDescStyle.Render("panels"),
			HelpKeyStyle.Render("j/k"), HelpDescStyle.Render("nav"),
			HelpKeyStyle.Render("a"), HelpDescStyle.Render("attended"),
			HelpKeyStyle.Render("c"), HelpDescStyle.Render("cancel RSVP"),
			HelpKeyStyle.Render("X"), HelpDescStyle.Render("export"),
		)
	} else if m.focusedPanel == FocusEvents {
		help = fmt.Sprintf(
			"%s %s  %s %s  %s %s  %s %s  %s %s  %s %s",
			HelpKeyStyle.Render("Tab/1-4"), HelpDescStyle.Render("panels"),
			HelpKeyStyle.Render("j/k"), HelpDescStyle.Render("nav"),
			HelpKeyStyle.Render("n"), HelpDescStyle.Render("new"),
			HelpKeyStyle.Render("e"), HelpDescStyle.Render("edit"),
			HelpKeyStyle.Render("p"), HelpDescStyle.Render("publish"),
			HelpKeyStyle.Render("?"), HelpDescStyle.Render("help"),
		)
	} else if m.focusedPanel == FocusVenues {
		help = fmt.Sprintf(
			"%s %s  %s %s  %s %s  %s %s  %s %s",
			HelpKeyStyle.Render("Tab/1-4"), HelpDescStyle.Render("panels"),
			HelpKeyStyle.Render("j/k"), HelpDescStyle.Render("nav"),
			HelpKeyStyle.Render("n"), HelpDescStyle.Render("new"),
			HelpKeyStyle.Render("e"), HelpDescStyle.Render("edit"),
			HelpKeyStyle.Render("?"), HelpDescStyle.Render("help"),
		)
	} else {
		// Detail panel
		help = fmt.Sprintf(
			"%s %s  %s %s  %s %s  %s %s",
			HelpKeyStyle.Render("Tab/1-4"), HelpDescStyle.Render("panels"),
			HelpKeyStyle.Render("j/k"), HelpDescStyle.Render("scroll"),
			HelpKeyStyle.Render("e"), HelpDescStyle.Render("edit"),
			HelpKeyStyle.Render("?"), HelpDescStyle.Render("help"),
		)
	}

	return HelpBarStyle.Width(m.width).Render(help)
}
