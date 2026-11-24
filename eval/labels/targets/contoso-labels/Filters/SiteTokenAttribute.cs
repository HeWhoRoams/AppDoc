using System.Web.Helpers;
using System.Web.Mvc;

namespace Contoso.Labels.Filters
{
    public class SiteTokenAttribute : FilterAttribute, IAuthorizationFilter
    {
        public void OnAuthorization(AuthorizationContext filterContext)
        {
            AntiForgery.Validate();
        }
    }
}
