using System.Web;
using System.Web.Mvc;
using System.Web.Routing;

namespace HelpDesk
{
    public class MvcApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            RouteConfig.RegisterRoutes(RouteTable.Routes);
        }

        protected void Application_Error(object sender, EventArgs e)
        {
        }
    }
}
