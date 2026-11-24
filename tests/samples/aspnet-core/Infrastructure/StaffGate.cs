using Microsoft.AspNetCore.Mvc.Filters;

namespace HelpDesk.TicketApi.Infrastructure
{
    public static class Rolenames
    {
        public const string Support = "Support";
        public const string Supervisor = "Supervisor";
    }

    // An in-Target authorization filter; it overrides OnAuthorization, so it says nothing about who is admitted.
    public class StaffGateAttribute : System.Attribute, IAuthorizationFilter
    {
        public void OnAuthorization(AuthorizationFilterContext context)
        {
        }
    }
}
