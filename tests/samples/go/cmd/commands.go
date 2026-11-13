package cmd

import (
	"github.com/spf13/cobra"
	"github.com/urfave/cli/v3"
)

func newWebCommand() *cli.Command {
	return &cli.Command{
		Name:   "web",
		Usage:  "Start the web server",
		Action: runWeb,
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:  "port",
				Usage: "listen port",
			},
		},
	}
}

func newAdminCommand() *cli.Command {
	return &cli.Command{
		Name: "admin",
		Commands: []*cli.Command{
			newWebCommand(),
			{
				Name:   "sync",
				Action: runSync,
			},
		},
	}
}

var migrateCmd = &cobra.Command{
	Use:   "migrate [flags]",
	Short: "Run database migrations",
	RunE:  runMigrate,
}
