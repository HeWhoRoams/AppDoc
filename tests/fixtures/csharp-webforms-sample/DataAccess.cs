using System.Configuration;
using System.Data.SqlClient;

namespace HelpDesk
{
    public static class DataAccess
    {
        public static SqlConnection GetConnection()
        {
            string cs = ConfigurationManager.ConnectionStrings["HelpDeskMain"].ConnectionString;
            return new SqlConnection(cs);
        }
    }
}
