package views

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// FieldType represents the type of form field
type FieldType int

const (
	FieldInput FieldType = iota
	FieldSelect           // Simple select - cycles through options with Enter
	FieldSelectSearchable // Searchable select - type to filter, arrows to navigate
	FieldDescription      // Opens external editor
	FieldConfirm
)

// FormField represents a single field in the form
type FormField struct {
	Key         string
	Label       string
	Type        FieldType
	Value       string
	Options     []string // For Select fields
	Placeholder string
	Required    bool
}

// CustomForm is a form with "Enter to edit" interaction model
type CustomForm struct {
	fields       []FormField
	cursor       int  // Which field is highlighted
	editing      bool // Currently editing a field?
	editingValue string // Value being edited (for cancel restore)
	selectIndex  int  // For select fields, which option is selected
	textInput    textinput.Model
	width        int
	height       int
	submitted    bool
	cancelled    bool

	// Description edit tracking
	descriptionEditRequested bool
	descriptionToEdit        string

	// Searchable select state
	selectFiltered []string // Filtered options based on search
	selectCursor   int      // Cursor position in filtered list
}

// Form styling
var (
	formLabelStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#7D56F4")).
			Bold(true)

	formValueStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFFDF5"))

	formPlaceholderStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#626262")).
				Italic(true)

	formCursorStyle = lipgloss.NewStyle().
			Background(lipgloss.Color("#3D3D3D"))

	formEditingStyle = lipgloss.NewStyle().
				Background(lipgloss.Color("#7D56F4")).
				Foreground(lipgloss.Color("#FFFDF5"))

	formSelectedStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#04B575")).
				Bold(true)
)

// NewCustomForm creates a new custom form with the given fields
func NewCustomForm(fields []FormField, width, height int) CustomForm {
	ti := textinput.New()
	ti.CharLimit = 500
	ti.Width = width - 4

	return CustomForm{
		fields:    fields,
		cursor:    0,
		editing:   false,
		textInput: ti,
		width:     width,
		height:    height,
	}
}

// SetSize updates form dimensions
func (m *CustomForm) SetSize(width, height int) {
	m.width = width
	m.height = height
	m.textInput.Width = width - 4
}

// GetValue returns the value of a field by key
func (m CustomForm) GetValue(key string) string {
	for _, f := range m.fields {
		if f.Key == key {
			return f.Value
		}
	}
	return ""
}

// SetValue sets the value of a field by key
func (m *CustomForm) SetValue(key, value string) {
	for i := range m.fields {
		if m.fields[i].Key == key {
			m.fields[i].Value = value
			return
		}
	}
}

// IsSubmitted returns true if the form was submitted
func (m CustomForm) IsSubmitted() bool {
	return m.submitted
}

// IsCancelled returns true if the form was cancelled
func (m CustomForm) IsCancelled() bool {
	return m.cancelled
}

// DescriptionEditRequested returns true if a description edit was requested
func (m CustomForm) DescriptionEditRequested() bool {
	return m.descriptionEditRequested
}

// GetDescriptionToEdit returns the description value to edit
func (m CustomForm) GetDescriptionToEdit() string {
	return m.descriptionToEdit
}

// ClearDescriptionEditRequest clears the description edit request flag
func (m *CustomForm) ClearDescriptionEditRequest() {
	m.descriptionEditRequested = false
}

// CurrentField returns the currently focused field
func (m CustomForm) CurrentField() *FormField {
	if m.cursor >= 0 && m.cursor < len(m.fields) {
		return &m.fields[m.cursor]
	}
	return nil
}

// filterOptions filters options based on search text (case-insensitive)
func (m *CustomForm) filterOptions(options []string, search string) {
	search = strings.ToLower(search)
	m.selectFiltered = nil
	for _, opt := range options {
		if search == "" || strings.Contains(strings.ToLower(opt), search) {
			m.selectFiltered = append(m.selectFiltered, opt)
		}
	}
	// Reset cursor if out of bounds
	if m.selectCursor >= len(m.selectFiltered) {
		m.selectCursor = 0
	}
}

// Init initializes the form
func (m CustomForm) Init() tea.Cmd {
	return nil
}

// Update handles messages
func (m CustomForm) Update(msg tea.Msg) (CustomForm, tea.Cmd) {
	if m.submitted || m.cancelled {
		return m, nil
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		if m.editing {
			return m.updateEditMode(msg)
		}
		return m.updateNavigationMode(msg)
	}

	return m, nil
}

func (m CustomForm) updateNavigationMode(msg tea.KeyMsg) (CustomForm, tea.Cmd) {
	field := m.CurrentField()

	switch msg.String() {
	case "j", "down", "tab":
		m.cursor++
		if m.cursor >= len(m.fields) {
			m.cursor = len(m.fields) - 1
		}
		return m, nil

	case "k", "up", "shift+tab":
		m.cursor--
		if m.cursor < 0 {
			m.cursor = 0
		}
		return m, nil

	case "i":
		// Vim-style: 'i' to enter edit mode for input fields
		if field == nil {
			return m, nil
		}
		if field.Type == FieldInput || field.Type == FieldSelectSearchable {
			m.editing = true
			m.editingValue = field.Value
			if field.Type == FieldInput {
				m.textInput.SetValue(field.Value)
				m.textInput.CursorEnd()
			} else {
				m.textInput.SetValue("")
				m.textInput.Placeholder = "Type to filter..."
				m.filterOptions(field.Options, "")
				m.selectCursor = 0
				for i, opt := range m.selectFiltered {
					if opt == field.Value {
						m.selectCursor = i
						break
					}
				}
			}
			m.textInput.Focus()
			return m, textinput.Blink
		}
		return m, nil

	case "enter":
		if field == nil {
			return m, nil
		}

		switch field.Type {
		case FieldInput:
			// Enter edit mode
			m.editing = true
			m.editingValue = field.Value
			m.textInput.SetValue(field.Value)
			m.textInput.Focus()
			m.textInput.CursorEnd()
			return m, textinput.Blink

		case FieldSelect:
			// Cycle to next option
			if len(field.Options) > 0 {
				currentIdx := 0
				for i, opt := range field.Options {
					if opt == field.Value {
						currentIdx = i
						break
					}
				}
				nextIdx := (currentIdx + 1) % len(field.Options)
				m.fields[m.cursor].Value = field.Options[nextIdx]
			}
			return m, nil

		case FieldSelectSearchable:
			// Enter edit mode with search/filter
			m.editing = true
			m.editingValue = field.Value
			m.textInput.SetValue("")
			m.textInput.Placeholder = "Type to filter..."
			m.textInput.Focus()
			m.filterOptions(field.Options, "")
			// Set cursor to current selection
			m.selectCursor = 0
			for i, opt := range m.selectFiltered {
				if opt == field.Value {
					m.selectCursor = i
					break
				}
			}
			return m, textinput.Blink

		case FieldDescription:
			// Set flag for parent to handle (opens external editor)
			m.descriptionEditRequested = true
			m.descriptionToEdit = field.Value
			return m, nil

		case FieldConfirm:
			// Submit the form
			m.submitted = true
			return m, nil
		}

	case "y", "Y":
		// For confirm fields, set to yes
		if field != nil && field.Type == FieldConfirm {
			m.fields[m.cursor].Value = "yes"
			m.submitted = true
			return m, nil
		}

	case "n", "N":
		// For confirm fields, cancel
		if field != nil && field.Type == FieldConfirm {
			m.cancelled = true
			return m, nil
		}

	case "esc", "q":
		m.cancelled = true
		return m, nil
	}

	return m, nil
}

func (m CustomForm) updateEditMode(msg tea.KeyMsg) (CustomForm, tea.Cmd) {
	field := m.CurrentField()

	// Handle searchable select specially
	if field != nil && field.Type == FieldSelectSearchable {
		return m.updateSearchableSelect(msg)
	}

	switch msg.String() {
	case "enter":
		// Confirm edit, save value, exit edit mode
		m.fields[m.cursor].Value = m.textInput.Value()
		m.editing = false
		m.textInput.Blur()
		// Move to next field
		m.cursor++
		if m.cursor >= len(m.fields) {
			m.cursor = len(m.fields) - 1
		}
		return m, nil

	case "esc":
		// Cancel edit, restore previous value, exit edit mode
		m.editing = false
		m.textInput.Blur()
		return m, nil

	default:
		// Pass to textinput
		var cmd tea.Cmd
		m.textInput, cmd = m.textInput.Update(msg)
		return m, cmd
	}
}

func (m CustomForm) updateSearchableSelect(msg tea.KeyMsg) (CustomForm, tea.Cmd) {
	field := m.CurrentField()

	switch msg.String() {
	case "enter":
		// Select current item
		if len(m.selectFiltered) > 0 && m.selectCursor < len(m.selectFiltered) {
			m.fields[m.cursor].Value = m.selectFiltered[m.selectCursor]
		}
		m.editing = false
		m.textInput.Blur()
		// Move to next field
		m.cursor++
		if m.cursor >= len(m.fields) {
			m.cursor = len(m.fields) - 1
		}
		return m, nil

	case "esc":
		// Cancel, restore previous value
		m.editing = false
		m.textInput.Blur()
		return m, nil

	case "up", "ctrl+p":
		// Move up in list
		if m.selectCursor > 0 {
			m.selectCursor--
		}
		return m, nil

	case "down", "ctrl+n":
		// Move down in list
		if m.selectCursor < len(m.selectFiltered)-1 {
			m.selectCursor++
		}
		return m, nil

	default:
		// Pass to textinput for filtering
		var cmd tea.Cmd
		m.textInput, cmd = m.textInput.Update(msg)
		// Re-filter based on new input
		if field != nil {
			m.filterOptions(field.Options, m.textInput.Value())
		}
		return m, cmd
	}
}

// View renders the form
func (m CustomForm) View() string {
	var b strings.Builder

	for i, field := range m.fields {
		isCursor := i == m.cursor
		isEditing := isCursor && m.editing

		// Render label
		label := formLabelStyle.Render(field.Label + ":")
		b.WriteString(label)
		b.WriteString("\n")

		// Render value/input
		var valueStr string

		if isEditing && field.Type == FieldInput {
			// Show textinput
			valueStr = m.textInput.View()
		} else if isEditing && field.Type == FieldSelectSearchable {
			// Show search input + filtered list
			var sb strings.Builder
			sb.WriteString(m.textInput.View())
			sb.WriteString("\n")
			// Show filtered options (max 5 visible)
			maxVisible := 5
			start := 0
			if m.selectCursor >= maxVisible {
				start = m.selectCursor - maxVisible + 1
			}
			for i := start; i < len(m.selectFiltered) && i < start+maxVisible; i++ {
				opt := m.selectFiltered[i]
				if i == m.selectCursor {
					sb.WriteString(formSelectedStyle.Render("  > " + opt))
				} else {
					sb.WriteString(formPlaceholderStyle.Render("    " + opt))
				}
				if i < start+maxVisible-1 && i < len(m.selectFiltered)-1 {
					sb.WriteString("\n")
				}
			}
			if len(m.selectFiltered) == 0 {
				sb.WriteString(formPlaceholderStyle.Render("    (no matches)"))
			}
			valueStr = sb.String()
		} else {
			switch field.Type {
			case FieldInput, FieldDescription:
				if field.Value == "" {
					valueStr = formPlaceholderStyle.Render(field.Placeholder)
				} else {
					if field.Type == FieldDescription {
						// Show character count for description
						valueStr = formValueStyle.Render(fmt.Sprintf("(%d chars)", len(field.Value)))
					} else {
						valueStr = formValueStyle.Render(field.Value)
					}
				}

			case FieldSelect:
				// Show current selection with all options
				var opts []string
				for _, opt := range field.Options {
					if opt == field.Value {
						opts = append(opts, formSelectedStyle.Render("● "+opt))
					} else {
						opts = append(opts, formPlaceholderStyle.Render("○ "+opt))
					}
				}
				valueStr = strings.Join(opts, "  ")

			case FieldSelectSearchable:
				// Show current selection only
				if field.Value == "" {
					valueStr = formPlaceholderStyle.Render(field.Placeholder)
				} else {
					valueStr = formValueStyle.Render(field.Value)
				}

			case FieldConfirm:
				valueStr = formValueStyle.Render("[Enter to save] [Esc to cancel]")
			}
		}

		// Apply cursor highlighting
		if isCursor && !isEditing {
			valueStr = formCursorStyle.Render(" " + valueStr + " ")
		} else if !isEditing {
			valueStr = "  " + valueStr
		}

		b.WriteString(valueStr)
		b.WriteString("\n\n")
	}

	// Help text at bottom
	if m.editing {
		field := m.CurrentField()
		if field != nil && field.Type == FieldSelectSearchable {
			b.WriteString(formPlaceholderStyle.Render("Type to filter  ↑/↓: select  Enter: confirm  Esc: cancel"))
		} else {
			b.WriteString(formPlaceholderStyle.Render("Enter: confirm  Esc: cancel"))
		}
	} else {
		b.WriteString(formPlaceholderStyle.Render("j/k: navigate  i/Enter: edit  Esc: cancel"))
	}

	return b.String()
}
