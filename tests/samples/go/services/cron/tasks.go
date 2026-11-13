package cron

import "context"

func registerCleanup() {
	RegisterTaskFatal("cleanup_sessions", &OlderThanConfig{
		BaseConfig: BaseConfig{
			Enabled:  true,
			Schedule: "@every 24h",
		},
		OlderThan: 24 * time.Hour,
	}, func(ctx context.Context, cfg *OlderThanConfig) error {
		return session.DeleteOld(ctx, cfg.OlderThan)
	})
}

func registerReindex() {
	RegisterTaskFatal("rebuild_index", &BaseConfig{
		Enabled:    false,
		RunAtStart: false,
		Schedule:   "@annually",
	}, func(ctx context.Context, _ *BaseConfig) error {
		return search.Rebuild(ctx)
	})
}

func registerReport() {
	RegisterTask("weekly_report", &BaseConfig{Enabled: true, Schedule: "0 6 * * 1"}, runReport)
}

// RegisterTask is the wrapper itself: its name argument is not a literal.
func RegisterTask[T Config](name string, config T, fun func(context.Context, T) error) error {
	return register(name, config, fun)
}

func initCron(c *cron.Cron) {
	c.AddFunc("@every 5m", syncMirrors)
}
