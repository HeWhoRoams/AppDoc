using System.Web;
using System.Web.Mvc;
using System.Web.Routing;
using Contoso.Portal.App_Start;

namespace Contoso.Portal
{
    public class MvcApplication : HttpApplication
    {
        // The compile-time mode, selected per build configuration, is also passed to the guard attribute.
#if DEBUG
        public const string Mode = "Debug";
#elif STAGING
        public const string Mode = "Staging";
#else
        public const string Mode = "Production";
#endif

        protected void Application_Start()
        {
            AreaRegistration.RegisterAllAreas();
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
        }

        protected void Application_BeginRequest()
        {
            Response.AppendHeader("X-Portal-Mode", Mode);
        }
    }
}
