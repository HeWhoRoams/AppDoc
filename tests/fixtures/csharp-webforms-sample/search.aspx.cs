using System;
using System.Data;
using System.Data.SqlClient;
using System.Web;

namespace HelpDesk.Pages
{
    public partial class SearchPage : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            string ticketId = Request.QueryString["id"];
            if (string.IsNullOrEmpty(ticketId)) { Response.Redirect("index.aspx"); return; }
            LookUp(ticketId);
        }

        private void LookUp(string ticketId)
        {
            using (SqlConnection conn = DataAccess.GetConnection())
            using (SqlCommand cmd = new SqlCommand("HelpDesk.usp_GetTicket", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@TicketId", SqlDbType.NVarChar, 50) { Value = ticketId });
                conn.Open();
                using (SqlDataReader rs = cmd.ExecuteReader())
                {
                    if (rs.Read())
                    {
                        Response.Write("<h1>#" + rs["TicketId"] + "</h1>");
                        Response.Write("<p>Subject: " + rs["Subject"] + "</p>");
                    }
                    else
                    {
                        Response.Write("<p>Ticket not found.</p>");
                    }
                }
            }
        }
    }
}
