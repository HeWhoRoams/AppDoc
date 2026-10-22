using System;
using System.Data.SqlClient;
using System.Web;

namespace HelpDesk.Pages
{
    public partial class IndexPage : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            OpenTickets();
        }

        private void OpenTickets()
        {
            string sql = "SELECT TicketId, CustomerName, Subject, Status FROM HelpDesk.Tickets WHERE Status = 'Open'";
            using (SqlConnection conn = DataAccess.GetConnection())
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                conn.Open();
                SqlDataReader rs = cmd.ExecuteReader();
                Response.Write("<table>");
                while (rs.Read())
                {
                    Response.Write("<tr><td>" + rs["TicketId"] + "</td><td>" + rs["CustomerName"] + "</td><td>" + rs["Subject"] + "</td></tr>");
                }
                rs.Close();
                Response.Write("</table>");
            }
        }
    }
}
