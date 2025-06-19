package handlers

import (
	"github.com/labstack/echo/v4"
	"github.com/mikestefanello/pagoda/pkg/routenames"
	"github.com/mikestefanello/pagoda/pkg/services"
)

type Health struct {
}

func init() {
	Register(new(Health))
}

func (h *Health) Init(c *services.Container) error {
	return nil
}

func (h *Health) Routes(g *echo.Group) {
	g.GET("/health", h.Check).Name = routenames.Health
}

func (h *Health) Check(ctx echo.Context) error {
	return ctx.JSON(200, map[string]string{"status": "ok"})
}
