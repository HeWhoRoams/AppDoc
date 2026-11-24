using System.Web.Mvc;

namespace Contoso.Labels.Controllers
{
    [ValidateAntiForgeryToken]
    public abstract class TokenBaseController : Controller
    {
    }
}
