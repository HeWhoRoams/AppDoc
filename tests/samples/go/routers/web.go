package routers

func registerRoutes(m *web.Router) {
	reqSignIn := verifyAuth(true)

	m.Get("/", Home)
	m.Group("/user", func() {
		m.Get("/login", auth.SignIn)
		m.Post("/login", web.Bind[*forms.SignInForm](), auth.SignInPost)
		m.Group("/settings", func() {
			m.Get("", settings.Profile)
			m.Post("/avatar", web.Bind[*forms.AvatarForm](), settings.AvatarPost)
			m.Combo("/account").Get(settings.Account).
				Post(settings.AccountPost)
		}, reqSignIn)
		m.Group("", func() {
			m.Get("/logout", auth.SignOut)
		}, optSignIn, reqToken())
	})
	m.Methods("GET, HEAD", "/assets/*", public.Files)
	m.Any("/ping", Ping)
	m.Get("/redirect", func(ctx *Context) {
		ctx.Redirect("http://example.com/docs") // external, not a comment
	})
	// m.Get("/disabled", Disabled)
}

func addBoardRoutes(m *web.Router) {
	m.Post("/move", board.Move)
}
