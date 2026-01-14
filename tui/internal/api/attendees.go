package api

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"fmt"
)

type Attendee struct {
	ID             string `json:"id"`
	EventID        string `json:"event_id"`
	UserID         string `json:"user_id"`
	Email          string `json:"email"`
	Name           string `json:"name"`
	Status         string `json:"status"` // confirmed, cancelled, waitlisted
	Attended       bool   `json:"attended"`
	AttendanceMode string `json:"attendance_mode"` // in_person, online
	Notes          string `json:"notes"`
}

type AttendeeAttributes struct {
	Status         string `json:"status"`
	Attended       bool   `json:"attended"`
	AttendanceMode string `json:"attendance_mode"`
	Notes          string `json:"notes"`
}

// RSVPRelationships represents the relationships on an RSVP resource
type RSVPRelationships struct {
	User *ResourceRelationship `json:"user,omitempty"`
}

// UserAttributes represents user attributes from the API
type UserAttributes struct {
	Email     string `json:"email"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
}

func (c *Client) ListEventAttendees(eventID string) ([]Attendee, error) {
	resp, err := c.Get(fmt.Sprintf("/rsvps/events/%s?include=user", eventID))
	if err != nil {
		return nil, err
	}

	var resources []Resource
	if err := json.Unmarshal(resp.Data, &resources); err != nil {
		return nil, err
	}

	// Build a map of included users by ID
	userMap := make(map[string]UserAttributes)
	for _, inc := range resp.Included {
		if inc.Type == "user" {
			var userAttrs UserAttributes
			if err := json.Unmarshal(inc.Attributes, &userAttrs); err == nil {
				userMap[inc.ID] = userAttrs
			}
		}
	}

	attendees := make([]Attendee, len(resources))
	for i, r := range resources {
		var attrs AttendeeAttributes
		if err := json.Unmarshal(r.Attributes, &attrs); err != nil {
			return nil, err
		}

		attendee := Attendee{
			ID:             r.ID,
			EventID:        eventID,
			Status:         attrs.Status,
			Attended:       attrs.Attended,
			AttendanceMode: attrs.AttendanceMode,
			Notes:          attrs.Notes,
		}

		// Parse relationships to get user ID
		if r.Relationships != nil {
			var rels RSVPRelationships
			if err := json.Unmarshal(r.Relationships, &rels); err == nil {
				if rels.User != nil && rels.User.Data != nil {
					userID := rels.User.Data.ID
					attendee.UserID = userID
					// Look up user in included
					if user, ok := userMap[userID]; ok {
						attendee.Email = user.Email
						name := user.FirstName
						if user.LastName != "" {
							if name != "" {
								name += " "
							}
							name += user.LastName
						}
						attendee.Name = name
					}
				}
			}
		}

		attendees[i] = attendee
	}

	return attendees, nil
}

func (c *Client) MarkAttended(rsvpID string, attended bool) (*Attendee, error) {
	resp, err := c.Patch(fmt.Sprintf("/rsvps/%s/attended", rsvpID), struct{}{})
	if err != nil {
		return nil, err
	}

	var resource Resource
	if err := json.Unmarshal(resp.Data, &resource); err != nil {
		return nil, err
	}

	var attrs AttendeeAttributes
	if err := json.Unmarshal(resource.Attributes, &attrs); err != nil {
		return nil, err
	}

	return &Attendee{
		ID:       resource.ID,
		Status:   attrs.Status,
		Attended: attrs.Attended,
	}, nil
}

func (c *Client) CancelRSVP(rsvpID string) error {
	_, err := c.Patch(fmt.Sprintf("/rsvps/%s/cancel", rsvpID), struct{}{})
	return err
}

func ExportAttendeesToCSV(attendees []Attendee) ([]byte, error) {
	var buf bytes.Buffer
	writer := csv.NewWriter(&buf)

	// Write header
	header := []string{"Name", "Email", "Status", "Attended", "Mode", "Notes"}
	if err := writer.Write(header); err != nil {
		return nil, err
	}

	// Write data rows
	for _, a := range attendees {
		attended := "No"
		if a.Attended {
			attended = "Yes"
		}
		row := []string{a.Name, a.Email, a.Status, attended, a.AttendanceMode, a.Notes}
		if err := writer.Write(row); err != nil {
			return nil, err
		}
	}

	writer.Flush()
	if err := writer.Error(); err != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}
