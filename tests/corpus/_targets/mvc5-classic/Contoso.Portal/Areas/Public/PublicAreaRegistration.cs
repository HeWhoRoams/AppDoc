using System.Web.Mvc;

namespace Contoso.Portal.Areas.Public
{
    public class PublicAreaRegistration : AreaRegistration
    {
        public override string AreaName { get { return "Public"; } }

        public override void RegisterArea(AreaRegistrationContext context)
        {
            // The URL prefix is this literal, not the folder name.
            context.MapRoute(
                "Public_default",
                "info/{controller}/{action}/{id}",
                new { action = "Index", id = UrlParameter.Optional });
        }
    }
}
