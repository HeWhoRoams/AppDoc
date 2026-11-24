using System.Web.Mvc;

namespace Contoso.Portal.Areas.Billing
{
    public class BillingAreaRegistration : AreaRegistration
    {
        public override string AreaName { get { return "Billing"; } }

        public override void RegisterArea(AreaRegistrationContext context)
        {
        }
    }
}
