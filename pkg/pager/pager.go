package pager

import (
	"math"
	"strconv"

	"github.com/labstack/echo/v4"
)

// QueryKey stores the query key used to indicate the current page.
const QueryKey = "page"

// Pager provides a mechanism to allow a user to page results via a query parameter.
type Pager struct {
	// Items stores the total amount of items in the result set.
	Items int

	// Page stores the current page number.
	Page int

	// ItemsPerPage stores the amount of items to display per page.
	ItemsPerPage int

	// Pages stores the total amount of pages in the result set.
	Pages int
}

// NewPager creates a new Pager.
func NewPager(ctx echo.Context, itemsPerPage int) Pager {
	p := Pager{
		ItemsPerPage: itemsPerPage,
		Pages:        1,
		Page:         1,
	}

	if page := ctx.QueryParam(QueryKey); page != "" {
		if pageInt, err := strconv.Atoi(page); err == nil {
			if pageInt > 0 {
				p.Page = pageInt
			}
		}
	}

	return p
}

// SetItems sets the amount of items in total for the pager and calculate the amount
// of total pages based off on the item per page.
// This should be used rather than setting either items or pages directly.
func (p *Pager) SetItems(items int) {
	p.Items = items

	if items > 0 {
		p.Pages = int(math.Ceil(float64(items) / float64(p.ItemsPerPage)))
	} else {
		p.Pages = 1
	}

	if p.Page > p.Pages {
		p.Page = p.Pages
	}
}

// IsBeginning determines if the pager is at the beginning of the pages
func (p *Pager) IsBeginning() bool {
	return p.Page == 1
}

// IsEnd determines if the pager is at the end of the pages
func (p *Pager) IsEnd() bool {
	return p.Page >= p.Pages
}

// GetOffset determines the offset of the results in order to get the items for
// the current page
func (p *Pager) GetOffset() int {
	if p.Page == 0 {
		p.Page = 1
	}
	return (p.Page - 1) * p.ItemsPerPage
}
