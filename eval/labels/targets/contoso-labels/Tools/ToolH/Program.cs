using System;

namespace Contoso.Labels.ToolH
{
    internal static class Program
    {
        static void Main()
        {
            if (Settings.Mode == AppMode.Production)
            {
                Console.WriteLine(1);
            }
        }
    }
}
