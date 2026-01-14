package api

import (
	"encoding/json"
)

type Venue struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	AddressLine1 string `json:"address_line_1,omitempty"`
	AddressLine2 string `json:"address_line_2,omitempty"`
	City         string `json:"city,omitempty"`
	State        string `json:"state,omitempty"`
	PostalCode   string `json:"postal_code,omitempty"`
	Country      string `json:"country,omitempty"`
	Notes        string `json:"notes,omitempty"`
	WebsiteURL   string `json:"website_url,omitempty"`
}

type VenueAttributes struct {
	Name         string `json:"name"`
	AddressLine1 string `json:"address_line_1,omitempty"`
	AddressLine2 string `json:"address_line_2,omitempty"`
	City         string `json:"city,omitempty"`
	State        string `json:"state,omitempty"`
	PostalCode   string `json:"postal_code,omitempty"`
	Country      string `json:"country,omitempty"`
	Notes        string `json:"notes,omitempty"`
	WebsiteURL   string `json:"website_url,omitempty"`
}

func (c *Client) ListVenues() ([]Venue, error) {
	resp, err := c.Get("/venues")
	if err != nil {
		return nil, err
	}

	var resources []Resource
	if err := json.Unmarshal(resp.Data, &resources); err != nil {
		return nil, err
	}

	venues := make([]Venue, len(resources))
	for i, r := range resources {
		var attrs VenueAttributes
		if err := json.Unmarshal(r.Attributes, &attrs); err != nil {
			return nil, err
		}
		venues[i] = Venue{
			ID:           r.ID,
			Name:         attrs.Name,
			AddressLine1: attrs.AddressLine1,
			AddressLine2: attrs.AddressLine2,
			City:         attrs.City,
			State:        attrs.State,
			PostalCode:   attrs.PostalCode,
			Country:      attrs.Country,
			Notes:        attrs.Notes,
			WebsiteURL:   attrs.WebsiteURL,
		}
	}

	return venues, nil
}

func (c *Client) GetVenue(id string) (*Venue, error) {
	resp, err := c.Get("/venues/" + id)
	if err != nil {
		return nil, err
	}

	var resource Resource
	if err := json.Unmarshal(resp.Data, &resource); err != nil {
		return nil, err
	}

	var attrs VenueAttributes
	if err := json.Unmarshal(resource.Attributes, &attrs); err != nil {
		return nil, err
	}

	return &Venue{
		ID:           resource.ID,
		Name:         attrs.Name,
		AddressLine1: attrs.AddressLine1,
		AddressLine2: attrs.AddressLine2,
		City:         attrs.City,
		State:        attrs.State,
		PostalCode:   attrs.PostalCode,
		Country:      attrs.Country,
		Notes:        attrs.Notes,
		WebsiteURL:   attrs.WebsiteURL,
	}, nil
}

type CreateVenueRequest struct {
	Data struct {
		Type       string `json:"type"`
		Attributes struct {
			Name         string `json:"name"`
			AddressLine1 string `json:"address_line_1,omitempty"`
			AddressLine2 string `json:"address_line_2,omitempty"`
			City         string `json:"city,omitempty"`
			State        string `json:"state,omitempty"`
			PostalCode   string `json:"postal_code,omitempty"`
			Country      string `json:"country,omitempty"`
			Notes        string `json:"notes,omitempty"`
			WebsiteURL   string `json:"website_url,omitempty"`
		} `json:"attributes"`
	} `json:"data"`
}

func (c *Client) CreateVenue(v *Venue) (*Venue, error) {
	req := CreateVenueRequest{}
	req.Data.Type = "venue"
	req.Data.Attributes.Name = v.Name
	req.Data.Attributes.AddressLine1 = v.AddressLine1
	req.Data.Attributes.AddressLine2 = v.AddressLine2
	req.Data.Attributes.City = v.City
	req.Data.Attributes.State = v.State
	req.Data.Attributes.PostalCode = v.PostalCode
	req.Data.Attributes.Country = v.Country
	req.Data.Attributes.Notes = v.Notes
	req.Data.Attributes.WebsiteURL = v.WebsiteURL

	resp, err := c.Post("/venues", req)
	if err != nil {
		return nil, err
	}

	var resource Resource
	if err := json.Unmarshal(resp.Data, &resource); err != nil {
		return nil, err
	}

	var attrs VenueAttributes
	if err := json.Unmarshal(resource.Attributes, &attrs); err != nil {
		return nil, err
	}

	return &Venue{
		ID:           resource.ID,
		Name:         attrs.Name,
		AddressLine1: attrs.AddressLine1,
		AddressLine2: attrs.AddressLine2,
		City:         attrs.City,
		State:        attrs.State,
		PostalCode:   attrs.PostalCode,
		Country:      attrs.Country,
		Notes:        attrs.Notes,
		WebsiteURL:   attrs.WebsiteURL,
	}, nil
}

type UpdateVenueRequest struct {
	Data struct {
		Type       string `json:"type"`
		ID         string `json:"id"`
		Attributes struct {
			Name         *string `json:"name,omitempty"`
			AddressLine1 *string `json:"address_line_1,omitempty"`
			AddressLine2 *string `json:"address_line_2,omitempty"`
			City         *string `json:"city,omitempty"`
			State        *string `json:"state,omitempty"`
			PostalCode   *string `json:"postal_code,omitempty"`
			Country      *string `json:"country,omitempty"`
			Notes        *string `json:"notes,omitempty"`
			WebsiteURL   *string `json:"website_url,omitempty"`
		} `json:"attributes"`
	} `json:"data"`
}

func (c *Client) UpdateVenue(id string, v *Venue) (*Venue, error) {
	req := UpdateVenueRequest{}
	req.Data.Type = "venue"
	req.Data.ID = id
	req.Data.Attributes.Name = &v.Name
	req.Data.Attributes.AddressLine1 = &v.AddressLine1
	req.Data.Attributes.AddressLine2 = &v.AddressLine2
	req.Data.Attributes.City = &v.City
	req.Data.Attributes.State = &v.State
	req.Data.Attributes.PostalCode = &v.PostalCode
	req.Data.Attributes.Country = &v.Country
	req.Data.Attributes.Notes = &v.Notes
	req.Data.Attributes.WebsiteURL = &v.WebsiteURL

	resp, err := c.Patch("/venues/"+id, req)
	if err != nil {
		return nil, err
	}

	var resource Resource
	if err := json.Unmarshal(resp.Data, &resource); err != nil {
		return nil, err
	}

	var attrs VenueAttributes
	if err := json.Unmarshal(resource.Attributes, &attrs); err != nil {
		return nil, err
	}

	return &Venue{
		ID:           resource.ID,
		Name:         attrs.Name,
		AddressLine1: attrs.AddressLine1,
		AddressLine2: attrs.AddressLine2,
		City:         attrs.City,
		State:        attrs.State,
		PostalCode:   attrs.PostalCode,
		Country:      attrs.Country,
		Notes:        attrs.Notes,
		WebsiteURL:   attrs.WebsiteURL,
	}, nil
}

func (c *Client) DeleteVenue(id string) error {
	return c.Delete("/venues/" + id)
}
