using System.Web.Mvc;
using System.Web.Routing;

namespace HelpDesk
{
    public class RouteConfig
    {
        public static void RegisterRoutes(RouteCollection routes)
        {
            routes.MapRoute(
                name: "TicketDetail",
                url: "tickets/view/{id}",
                defaults: new { controller = "Tickets", action = "Details" }
            );
            routes.MapRoute(
                name: "Default",
                url: "{controller}/{action}/{id}",
                defaults: new { controller = "Home", action = "Index", id = UrlParameter.Optional }
            );
            routes.MapPageRoute("LegacySearch", "legacy/search", "~/search.aspx");
            // routes.MapRoute("Retired", "retired/{id}", new { controller = "Old", action = "Gone" });
        }
    }
}
