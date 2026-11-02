<%
' search-ticket.asp - look up a single ticket; redirect to index on failure.
Dim ticketId, conn, rs
ticketId = Request.QueryString("id")
If ticketId = "" Then
    Response.Redirect "index.asp"
End If
On Error Resume Next
Set conn = Server.CreateObject("ADODB.Connection")
conn.ConnectionString = "Provider=SQLOLEDB;Data Source=FIXTURE-SERVER;Initial Catalog=FIXTURE_DB;User Id=fakeuser;Password=fakepass"
conn.Open
Set rs = Server.CreateObject("ADODB.Recordset")
rs.Open "SELECT TicketId, CustomerName, Subject FROM HelpDesk.Tickets WHERE TicketId = '" & Replace(ticketId, "'", "''") & "'", conn
If Err.Number <> 0 Then
    Response.Redirect "index.asp"
Else
    Response.Write "<h1>#" & rs("TicketId") & "</h1>"
    Response.Write "<p>Subject: " & rs("Subject") & "</p>"
    rs.Close
End If
conn.Close
%>
