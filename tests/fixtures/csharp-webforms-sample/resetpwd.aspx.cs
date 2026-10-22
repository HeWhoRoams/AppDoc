using System;
using System.Data;
using System.Data.SqlClient;
using System.Net.Http;

namespace HelpDesk.Pages
{
    public partial class ResetPwdPage : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
        }

        private void DoReset(string email)
        {
            using (SqlConnection conn = DataAccess.GetConnection())
            using (SqlCommand cmd = new SqlCommand("HelpDesk.usp_ResetPassword", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@Email", SqlDbType.NVarChar, 100) { Value = email });
                cmd.Parameters.Add(new SqlParameter("@NewPassword", SqlDbType.NVarChar, 50, ParameterDirection.Output));
                conn.Open();
                cmd.ExecuteNonQuery();
                NotifyItsm(email);
                Response.Write("<p>Reset link sent to " + email + ".</p>");
            }
        }

        private void NotifyItsm(string to)
        {
            // Outbound ITSM ticket notification (destination only; no credential is emitted).
            HttpClient client = new HttpClient();
            client.PostAsync("https://fixture.internal/itsm/api/ticket", new StringContent("reset:" + to)).Wait();
        }
    }
}
