using log4net;

namespace Contoso.Labels.Code
{
    public static class LogManager
    {
        public static ILog GetLogger(string name) { return null; }
    }

    public class OwnLogging
    {
        public void Run()
        {
            ILog log = LogManager.GetLogger("own");
            if (log == null)
            {
                System.Console.WriteLine("no log");
            }
        }
    }
}
