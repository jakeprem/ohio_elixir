package ui

import (
	"os"
	"os/exec"
)

// EditInExternalEditor opens content in the user's preferred editor
// and returns the modified content.
func EditInExternalEditor(content string, suffix string) (string, error) {
	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = os.Getenv("VISUAL")
	}
	if editor == "" {
		// Try common editors
		for _, e := range []string{"nvim", "vim", "nano", "vi"} {
			if _, err := exec.LookPath(e); err == nil {
				editor = e
				break
			}
		}
	}
	if editor == "" {
		editor = "vi" // Last resort fallback
	}

	// Create temp file with appropriate suffix for syntax highlighting
	if suffix == "" {
		suffix = ".md"
	}
	tmpfile, err := os.CreateTemp("", "ohio-*"+suffix)
	if err != nil {
		return "", err
	}
	defer os.Remove(tmpfile.Name())

	// Write current content
	if _, err := tmpfile.WriteString(content); err != nil {
		tmpfile.Close()
		return "", err
	}
	tmpfile.Close()

	// Open editor
	cmd := exec.Command(editor, tmpfile.Name())
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", err
	}

	// Read back the edited content
	result, err := os.ReadFile(tmpfile.Name())
	if err != nil {
		return "", err
	}

	return string(result), nil
}
