using System.Web.Mvc;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Contoso.Portal.Tests
{
    [TestClass]
    public class HomeControllerTests
    {
        [TestMethod]
        public void Index_ReturnsView()
        {
            var result = new Contoso.Portal.Controllers.HomeController().Index();
            Assert.IsInstanceOfType(result, typeof(ViewResult));
        }
    }
}
