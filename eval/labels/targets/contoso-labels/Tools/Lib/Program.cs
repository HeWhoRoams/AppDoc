using System;

namespace Contoso.Labels.Lib
{
    internal static class Program
    {
        static void Main()
        {
            Settings.Mode = AppMode.Production;
            Console.WriteLine(1);
        }
    }
}
