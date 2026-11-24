using System.Web;
using System.Web.Mvc;
using System.Web.Routing;

namespace Contoso.Aliases
{
    public class MvcApplication : HttpApplication
    {
        protected void Application_Start()
        {
            AreaRegistration.RegisterAllAreas();
            RouteTable.Routes.IgnoreRoute("{resource}.axd/{*pathInfo}");
            RouteTable.Routes.MapRoute("CatchAll", "{culture}/docs/{id}", new { controller = "Docs", action = "Show", id = UrlParameter.Optional });
            RouteTable.Routes.MapRoute("Default", "{controller}/{action}/{id}",
                new { controller = "Home", action = "Index", id = UrlParameter.Optional });
        }
    }
}
