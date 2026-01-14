package api

import (
	"encoding/json"
	"fmt"
	"time"
)

type Event struct {
	ID               string     `json:"id"`
	Title            string     `json:"title"`
	Description      string     `json:"description,omitempty"`
	ShortDescription string     `json:"short_description,omitempty"`
	Status           string     `json:"status"`
	Format           string     `json:"format"`
	StartsAt         *time.Time `json:"starts_at,omitempty"`
	EndsAt           *time.Time `json:"ends_at,omitempty"`
	Timezone         string     `json:"timezone"`
	MeetingURL       string     `json:"meeting_url,omitempty"`
	Capacity         *int       `json:"capacity,omitempty"`
	VenueID          string     `json:"venue_id,omitempty"`
}

type EventAttributes struct {
	Title            string     `json:"title"`
	Description      string     `json:"description,omitempty"`
	ShortDescription string     `json:"short_description,omitempty"`
	Status           string     `json:"status"`
	Format           string     `json:"format"`
	StartsAt         *time.Time `json:"starts_at,omitempty"`
	EndsAt           *time.Time `json:"ends_at,omitempty"`
	Timezone         string     `json:"timezone"`
	MeetingURL       string     `json:"meeting_url,omitempty"`
	Capacity         *int       `json:"capacity,omitempty"`
	VenueID          string     `json:"venue_id,omitempty"`
}

func (c *Client) ListEvents() ([]Event, error) {
	resp, err := c.Get("/events")
	if err != nil {
		return nil, err
	}

	// Parse as array of resources
	var resources []Resource
	if err := json.Unmarshal(resp.Data, &resources); err != nil {
		return nil, err
	}

	events := make([]Event, len(resources))
	for i, r := range resources {
		var attrs EventAttributes
		if err := json.Unmarshal(r.Attributes, &attrs); err != nil {
			return nil, err
		}
		events[i] = Event{
			ID:               r.ID,
			Title:            attrs.Title,
			Description:      attrs.Description,
			ShortDescription: attrs.ShortDescription,
			Status:           attrs.Status,
			Format:           attrs.Format,
			StartsAt:         attrs.StartsAt,
			EndsAt:           attrs.EndsAt,
			Timezone:         attrs.Timezone,
			MeetingURL:       attrs.MeetingURL,
			Capacity:         attrs.Capacity,
			VenueID:          attrs.VenueID,
		}
	}

	return events, nil
}

func (c *Client) GetEvent(id string) (*Event, error) {
	resp, err := c.Get("/events/" + id)
	if err != nil {
		return nil, err
	}

	var resource Resource
	if err := json.Unmarshal(resp.Data, &resource); err != nil {
		return nil, err
	}

	var attrs EventAttributes
	if err := json.Unmarshal(resource.Attributes, &attrs); err != nil {
		return nil, err
	}

	return &Event{
		ID:               resource.ID,
		Title:            attrs.Title,
		Description:      attrs.Description,
		ShortDescription: attrs.ShortDescription,
		Status:           attrs.Status,
		Format:           attrs.Format,
		StartsAt:         attrs.StartsAt,
		EndsAt:           attrs.EndsAt,
		Timezone:         attrs.Timezone,
		MeetingURL:       attrs.MeetingURL,
		Capacity:         attrs.Capacity,
		VenueID:          attrs.VenueID,
	}, nil
}

type CreateEventRequest struct {
	Data struct {
		Type       string `json:"type"`
		Attributes struct {
			Title            string `json:"title"`
			Description      string `json:"description,omitempty"`
			ShortDescription string `json:"short_description,omitempty"`
			Format           string `json:"format"`
			StartsAt         string `json:"starts_at"`
			EndsAt           string `json:"ends_at,omitempty"`
			Timezone         string `json:"timezone,omitempty"`
			MeetingURL       string `json:"meeting_url,omitempty"`
			Capacity         *int   `json:"capacity,omitempty"`
		} `json:"attributes"`
	} `json:"data"`
}

func (c *Client) CreateEvent(title, description, shortDesc, format string, startsAt time.Time, endsAt *time.Time, timezone, meetingURL string, capacity *int) (*Event, error) {
	req := CreateEventRequest{}
	req.Data.Type = "event"
	req.Data.Attributes.Title = title
	req.Data.Attributes.Description = description
	req.Data.Attributes.ShortDescription = shortDesc
	req.Data.Attributes.Format = format
	req.Data.Attributes.StartsAt = startsAt.Format(time.RFC3339)
	if endsAt != nil {
		req.Data.Attributes.EndsAt = endsAt.Format(time.RFC3339)
	}
	if timezone != "" {
		req.Data.Attributes.Timezone = timezone
	}
	req.Data.Attributes.MeetingURL = meetingURL
	req.Data.Attributes.Capacity = capacity

	resp, err := c.Post("/events", req)
	if err != nil {
		return nil, err
	}

	var resource Resource
	if err := json.Unmarshal(resp.Data, &resource); err != nil {
		return nil, err
	}

	var attrs EventAttributes
	if err := json.Unmarshal(resource.Attributes, &attrs); err != nil {
		return nil, err
	}

	return &Event{
		ID:               resource.ID,
		Title:            attrs.Title,
		Description:      attrs.Description,
		ShortDescription: attrs.ShortDescription,
		Status:           attrs.Status,
		Format:           attrs.Format,
		StartsAt:         attrs.StartsAt,
		EndsAt:           attrs.EndsAt,
		Timezone:         attrs.Timezone,
		MeetingURL:       attrs.MeetingURL,
		Capacity:         attrs.Capacity,
		VenueID:          attrs.VenueID,
	}, nil
}

func (c *Client) PublishEvent(id string) (*Event, error) {
	resp, err := c.Patch(fmt.Sprintf("/events/%s/publish", id), struct{}{})
	if err != nil {
		return nil, err
	}

	var resource Resource
	if err := json.Unmarshal(resp.Data, &resource); err != nil {
		return nil, err
	}

	var attrs EventAttributes
	if err := json.Unmarshal(resource.Attributes, &attrs); err != nil {
		return nil, err
	}

	return &Event{
		ID:     resource.ID,
		Title:  attrs.Title,
		Status: attrs.Status,
	}, nil
}

func (c *Client) CancelEvent(id string) (*Event, error) {
	resp, err := c.Patch(fmt.Sprintf("/events/%s/cancel", id), struct{}{})
	if err != nil {
		return nil, err
	}

	var resource Resource
	if err := json.Unmarshal(resp.Data, &resource); err != nil {
		return nil, err
	}

	var attrs EventAttributes
	if err := json.Unmarshal(resource.Attributes, &attrs); err != nil {
		return nil, err
	}

	return &Event{
		ID:     resource.ID,
		Title:  attrs.Title,
		Status: attrs.Status,
	}, nil
}

type UpdateEventRequest struct {
	Data struct {
		Type       string `json:"type"`
		ID         string `json:"id"`
		Attributes struct {
			Title            *string `json:"title,omitempty"`
			Description      *string `json:"description,omitempty"`
			ShortDescription *string `json:"short_description,omitempty"`
			Format           *string `json:"format,omitempty"`
			StartsAt         *string `json:"starts_at,omitempty"`
			EndsAt           *string `json:"ends_at,omitempty"`
			Timezone         *string `json:"timezone,omitempty"`
			MeetingURL       *string `json:"meeting_url,omitempty"`
			Capacity         *int    `json:"capacity,omitempty"`
			VenueID          *string `json:"venue_id,omitempty"`
		} `json:"attributes"`
	} `json:"data"`
}

// EventUpdate holds fields to update on an event
type EventUpdate struct {
	Title            *string
	Description      *string
	ShortDescription *string
	Format           *string
	StartsAt         *time.Time
	EndsAt           *time.Time
	Timezone         *string
	MeetingURL       *string
	Capacity         *int
	VenueID          *string
}

func (c *Client) UpdateEventDescription(id, description string) (*Event, error) {
	update := EventUpdate{Description: &description}
	return c.UpdateEvent(id, update)
}

func (c *Client) UpdateEvent(id string, update EventUpdate) (*Event, error) {
	req := UpdateEventRequest{}
	req.Data.Type = "event"
	req.Data.ID = id
	req.Data.Attributes.Title = update.Title
	req.Data.Attributes.Description = update.Description
	req.Data.Attributes.ShortDescription = update.ShortDescription
	req.Data.Attributes.Format = update.Format
	req.Data.Attributes.Timezone = update.Timezone
	req.Data.Attributes.MeetingURL = update.MeetingURL
	req.Data.Attributes.Capacity = update.Capacity
	req.Data.Attributes.VenueID = update.VenueID

	if update.StartsAt != nil {
		s := update.StartsAt.Format(time.RFC3339)
		req.Data.Attributes.StartsAt = &s
	}
	if update.EndsAt != nil {
		s := update.EndsAt.Format(time.RFC3339)
		req.Data.Attributes.EndsAt = &s
	}

	resp, err := c.Patch(fmt.Sprintf("/events/%s", id), req)
	if err != nil {
		return nil, err
	}

	var resource Resource
	if err := json.Unmarshal(resp.Data, &resource); err != nil {
		return nil, err
	}

	var attrs EventAttributes
	if err := json.Unmarshal(resource.Attributes, &attrs); err != nil {
		return nil, err
	}

	return &Event{
		ID:               resource.ID,
		Title:            attrs.Title,
		Description:      attrs.Description,
		ShortDescription: attrs.ShortDescription,
		Status:           attrs.Status,
		Format:           attrs.Format,
		StartsAt:         attrs.StartsAt,
		EndsAt:           attrs.EndsAt,
		Timezone:         attrs.Timezone,
		MeetingURL:       attrs.MeetingURL,
		Capacity:         attrs.Capacity,
		VenueID:          attrs.VenueID,
	}, nil
}
