namespace Contoso.Portal.Harness
{
    // Named like an MVC controller, but a plain class: it must not become a web entry point.
    public class HarnessController
    {
        public void Run(string mode)
        {
        }

        public string Index()
        {
            return "harness";
        }
    }
}
