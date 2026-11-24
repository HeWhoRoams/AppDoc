using System;

namespace Contoso.Labels.Code
{
    public class NullChecksBranch
    {
        public void LogId(Customer c)
        {
            if (c == null)
            {
                Console.WriteLine(c.Id);
            }
        }

        public void LogName(Customer c)
        {
            if (c == null)
            {
                var n = c.Name;
            }
        }

        public void LogScores(Customer c)
        {
            if (null == c)
            {
                var s = c.Scores[0];
            }
        }

        public void LogText(Customer c)
        {
            if (c is null)
            {
                Console.WriteLine(c.ToString());
            }
        }

        public void LogKind(Customer c)
        {
            if (c == null)
                Console.WriteLine(c.GetType());
        }

        public void BlankExtension(Customer c)
        {
            if (c == null)
            {
                var blank = c.IsBlank();
            }
        }

        public void AssignedFirst(Customer c)
        {
            if (c == null)
            {
                c = new Customer();
                Console.WriteLine(c.Id);
            }
        }

        public void InnerBlock(Customer c, bool flag)
        {
            if (c == null)
            {
                if (flag)
                {
                    Console.WriteLine(c.Id);
                }
            }
        }

        public void ConditionalAccess(Customer c)
        {
            if (c == null)
            {
                Console.WriteLine(c?.Id);
            }
        }
    }
}
