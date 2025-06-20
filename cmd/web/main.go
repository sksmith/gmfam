package main

import (
	"crypto/tls"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"

	"github.com/mikestefanello/pagoda/pkg/handlers"
	"github.com/mikestefanello/pagoda/pkg/log"
	"github.com/mikestefanello/pagoda/pkg/services"
)

func init() {
	fmt.Println("INIT FUNCTION RUNNING - IF YOU SEE THIS, INIT FUNCTIONS WORK")
}

func main() {
	fmt.Println("SEAN ADDED MANUAL LOG")

	// Log startup information
	log.Default().Info("Application starting",
		"environment", os.Getenv("PAGODA_APP_ENVIRONMENT"),
		"version", os.Getenv("APP_VERSION"),
		"go_version", os.Getenv("GO_VERSION"),
	)

	// Catch any panics during initialization
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("PANIC OCCURRED: %v\n", r)
			log.Default().Error("Application panic during startup",
				"panic", r,
			)
			os.Exit(1)
		}
	}()

	// Start a new container.
	fmt.Println("ABOUT TO INITIALIZE SERVICES CONTAINER")
	log.Default().Info("Initializing services container...")
	c := services.NewContainer()
	fmt.Println("SERVICES CONTAINER INITIALIZED SUCCESSFULLY")
	log.Default().Info("Services container initialized successfully")
	defer func() {
		// Gracefully shutdown all services.
		fatal("shutdown failed", c.Shutdown())
	}()

	// Log configuration details
	log.Default().Info("Container initialized",
		"app_environment", c.Config.App.Environment,
		"http_hostname", c.Config.HTTP.Hostname,
		"http_port", c.Config.HTTP.Port,
		"database_type", "postgres",
	)

	// Build the router.
	if err := handlers.BuildRouter(c); err != nil {
		fatal("failed to build the router", err)
	}

	// Temporarily disable task queues due to PostgreSQL 17 compatibility issues
	// TODO: Fix backlite compatibility with PostgreSQL 17
	// tasks.Register(c)
	// c.Tasks.Start(context.Background())

	// Start the server.
	go func() {
		srv := http.Server{
			Addr:         fmt.Sprintf("%s:%d", c.Config.HTTP.Hostname, c.Config.HTTP.Port),
			Handler:      c.Web,
			ReadTimeout:  c.Config.HTTP.ReadTimeout,
			WriteTimeout: c.Config.HTTP.WriteTimeout,
			IdleTimeout:  c.Config.HTTP.IdleTimeout,
		}

		if c.Config.HTTP.TLS.Enabled {
			certs, err := tls.LoadX509KeyPair(c.Config.HTTP.TLS.Certificate, c.Config.HTTP.TLS.Key)
			fatal("cannot load TLS certificate", err)

			srv.TLSConfig = &tls.Config{
				Certificates: []tls.Certificate{certs},
			}
		}

		log.Default().Info("Server starting",
			"address", srv.Addr,
			"tls_enabled", c.Config.HTTP.TLS.Enabled,
		)

		if err := c.Web.StartServer(&srv); errors.Is(err, http.ErrServerClosed) {
			fatal("shutting down the server", err)
		}
	}()

	// Wait for interrupt signal to gracefully shut down the web server and task runner.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt)
	signal.Notify(quit, os.Kill)
	<-quit
}

// fatal logs an error and terminates the application, if the error is not nil.
func fatal(msg string, err error) {
	if err != nil {
		log.Default().Error(msg, "error", err)
		os.Exit(1)
	}
}
