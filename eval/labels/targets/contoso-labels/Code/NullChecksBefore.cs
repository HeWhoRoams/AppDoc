using System;

namespace Contoso.Labels.Code
{
    public class Customer { public string Name; public string Id { get; set; } public int[] Scores; }

    public static class StringExtras
    {
        public static bool IsBlank(this Customer c) { return c == null || c.Name == ""; }
    }

    public class NullChecksBefore
    {
        public string FirstName(Customer c)
        {
            var n = c.Name;
            if (c == null)
            {
                return "";
            }
            return n;
        }

        public string FirstId(Customer c)
        {
            string id = c.Id;
            if (null == c)
            {
                return "";
            }
            return id;
        }

        public int FirstScore(Customer c)
        {
            int s = c.Scores[0];
            if (c == null)
            {
                return 0;
            }
            return s;
        }

        public string Describe(Customer c)
        {
            var text = c.ToString();
            if (c is null)
            {
                return "";
            }
            return text;
        }

        public string Label(Customer c)
        {
            Console.WriteLine(c.Id);
            if (c == null)
            {
                return "none";
            }
            return "x";
        }

        public bool BlankExtension(Customer c)
        {
            var blank = c.IsBlank();
            if (c == null)
            {
                return true;
            }
            return blank;
        }

        public string InnerBlock(Customer c, bool flag)
        {
            if (flag)
            {
                var n = c.Name;
            }
            if (c == null)
            {
                return "";
            }
            return "x";
        }

        public string ShortCircuit(Customer c)
        {
            var ok = c == null || c.Name == "";
            if (c == null)
            {
                return "";
            }
            return ok ? "a" : "b";
        }

        public string Reassigned(Customer c)
        {
            var n = c.Name;
            c = new Customer();
            if (c == null)
            {
                return "";
            }
            return n;
        }

        public string Conditional(Customer c)
        {
            var n = c?.Name;
            if (c == null)
            {
                return "";
            }
            return n;
        }
    }
}
