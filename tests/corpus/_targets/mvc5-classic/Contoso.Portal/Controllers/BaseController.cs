using System.Security.Principal;
using System.Web.Mvc;
using Contoso.Shared.Web;

namespace Contoso.Portal.Controllers
{
    public abstract class BaseController : SharedControllerBase
    {
        protected bool HasRole(IPrincipal user, string roleA, string groupB)
        {
            return user.IsInRole(roleA) || user.IsInRole(groupB);
        }

        protected override void OnActionExecuting(ActionExecutingContext filterContext)
        {
            if (Request.Url != null && Request.Url.Scheme == "http")
            {
                filterContext.Result = Redirect("https://portal.contoso.test/");
            }
        }
    }
}
