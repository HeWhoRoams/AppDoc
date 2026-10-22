<%
' new-ticket.asp - form that creates a ticket by calling a stored procedure.
Dim conn, cmd
If Request.Form("action") = "submit" Then
    Dim ticketId, customer, subject, status
    ticketId = Request.Form("TicketId")
    customer = Request.Form("CustomerName")
    subject  = Request.Form("Subject")
    status   = Request.Form("Status")
    Set conn = Server.CreateObject("ADODB.Connection")
    conn.ConnectionString = "Provider=SQLOLEDB;Data Source=FIXTURE-SERVER;Initial Catalog=FIXTURE_DB;User Id=fakeuser;Password=fakepass"
    On Error Resume Next
    conn.Open
    Set cmd = Server.CreateObject("ADODB.Command")
    cmd.ActiveConnection = conn
    cmd.CommandType = 4
    cmd.CommandText = "HelpDesk.usp_CreateTicket"
    cmd.Parameters.Append cmd.CreateParameter("@TicketId", 20, 1, 10, ticketId)
    cmd.Parameters.Append cmd.CreateParameter("@CustomerName", 200, 1, 50, customer)
    cmd.Parameters.Append cmd.CreateParameter("@Subject", 200, 1, 50, subject)
    cmd.Parameters.Append cmd.CreateParameter("@Status", 20, 1, 10, status)
    cmd.Execute
    If Err.Number <> 0 Then
        Response.Write "<p>ERROR creating ticket: " & Err.Description & "</p>"
        Response.Redirect "index.asp"
    Else
        Response.Write "<p>Ticket " & ticketId & " created.</p>"
    End If
    conn.Close
Else
%>
<form action="new-ticket.asp" method="post">
  <input type="hidden" name="action" value="submit" />
  <input type="text" name="TicketId" size="10" />
  <input type="text" name="CustomerName" size="40" />
  <input type="text" name="Subject" size="60" />
  <input type="text" name="Status" value="Open" size="10" />
  <input type="submit" value="Create Ticket" />
</form>
<%
End If
%>
