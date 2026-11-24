using System.Web;
using System.Web.Mvc;

namespace HelpDesk.Infrastructure
{
    public static class Rolenames
    {
        public const string Support = "Support";
        public const string Supervisor = "Supervisor";
    }

    // An in-Target guard: an authorization filter that is a role guard only while AuthorizeCore is not overridden.
    public class StaffOnlyAttribute : AuthorizeAttribute
    {
    }
}
