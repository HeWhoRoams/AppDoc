using System;
using System.Windows.Forms;

namespace Contoso.Portal.Harness
{
    internal static class Program
    {
        // Hard-coded production mode in a harness that runs on a desktop.
        public static string RunMode = "Production";

        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.Run(new HarnessForm());
        }
    }
}
