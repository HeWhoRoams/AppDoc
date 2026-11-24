using System;
using System.Windows.Forms;

namespace Contoso.Portal.Harness
{
    public class HarnessForm : Form
    {
        private readonly Button run = new Button();

        public HarnessForm()
        {
            run.Click += RunButton_Click;
            Controls.Add(run);
        }

        private void RunButton_Click(object sender, EventArgs e)
        {
            new HarnessController().Run(Program.RunMode);
        }

        protected void Page_Load(object sender, EventArgs e)
        {
        }
    }
}
