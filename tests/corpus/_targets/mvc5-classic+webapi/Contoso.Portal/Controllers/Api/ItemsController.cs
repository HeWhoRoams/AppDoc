using System.Web.Http;

namespace Contoso.Portal.Controllers.Api
{
    [Authorize]
    public class ItemsController : ApiController
    {
        public string[] GetItems()
        {
            return new string[0];
        }

        public void PostItem(string name)
        {
        }

        [AllowAnonymous]
        public string GetHealth()
        {
            return "ok";
        }
    }
}
