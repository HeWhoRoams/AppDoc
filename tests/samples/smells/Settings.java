package smells;

class Settings {
	public static final String ADMIN_PASSWORD = "changeit";
	static final String API_KEY = "k-123";
	private static final String PASSWORD_PARAM = "password";
	private static final String TOKEN_URL = "https://example.test/token";
	private static final String FROM_ENV = "${APP_PASSWORD}";
	private static final String EMPTY_SECRET = "";
	private final String instancePassword = "not-static";
	// private static final String COMMENTED_PASSWORD = "x1";
}
