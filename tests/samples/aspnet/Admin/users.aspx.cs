using System;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI;

namespace HelpDesk.Admin
{
    public partial class UsersPage : System.Web.UI.Page
    {
        private string adminPassword = "fakepass";

        protected void Page_Load(object sender, EventArgs e)
        {
            if (Session["AdminUser"] == null)
            {
                Response.Redirect("~/login.aspx");
            }
        }

        protected void SaveBtn_Click(object sender, EventArgs e)
        {
            try
            {
                using (var conn = new SqlConnection("Server=FIXTURE;Database=HelpDesk;User Id=svc;Password=fakepass;"))
                using (var cmd = new SqlCommand("UPDATE HelpDesk.Users SET LastSeen = GETDATE() WHERE UserName = @n", conn))
                {
                    conn.Open();
                    cmd.ExecuteNonQuery();
                }
                var audit = new SqlCommand("HelpDesk.usp_AuditSave", GetConnection()) { CommandType = CommandType.StoredProcedure };
                lblStatus.Text = "User saved.";
            }
            catch (Exception ex)
            {
                lblError.Text = "Could not save the user.";
                Response.Write("<p>Save failed</p>");
            }
        }

        // protected void Old_Click(object sender, EventArgs e) { lblError.Text = "Dead code."; }
    }
}
