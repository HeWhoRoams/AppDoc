using System;
using System.Windows.Forms;

namespace HelpDesk.Desktop
{
    public partial class MainForm : Form
    {
        private void RunButton_Click(object sender, EventArgs e)
        {
        }
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.Run(new MainForm());
        }
    }
}
