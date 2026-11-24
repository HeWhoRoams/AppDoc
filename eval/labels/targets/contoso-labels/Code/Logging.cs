using log4net;

namespace Contoso.Labels.Code
{
    public class Logging
    {
        public void A()
        {
            ILog log = LogManager.GetLogger(typeof(Logging));
            if (log == null)
            {
                System.Console.WriteLine("no log");
            }
        }

        public void B()
        {
            ILog log = LogManager.GetLogger("b");
            if (log == null)
            {
                System.Console.WriteLine("no log");
            }
        }

        public void C()
        {
            ILog log = LogManager.GetLogger("c");
            if (null == log)
            {
                System.Console.WriteLine("no log");
            }
        }

        public void D()
        {
            ILog log = LogManager.GetLogger("d");
            if (log is null)
            {
                System.Console.WriteLine("no log");
            }
        }

        public void E()
        {
            ILog log = LogManager.GetLogger("e");
            if (log == null)
            {
                System.Console.WriteLine("no log");
            }
        }

        public void Untyped()
        {
            var log = LogManager.GetLogger("u");
            if (log == null)
            {
                System.Console.WriteLine("no log");
            }
        }

        public void Reassigned(ILog other)
        {
            ILog log = LogManager.GetLogger("r");
            log = other;
            if (log == null)
            {
                System.Console.WriteLine("no log");
            }
        }

        public void OtherVariable(ILog other)
        {
            ILog log = LogManager.GetLogger("o");
            if (other == null)
            {
                System.Console.WriteLine("no log");
            }
        }
    }
}
