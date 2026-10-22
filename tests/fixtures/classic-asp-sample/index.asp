<%
' index.asp - Home page: lists open tickets from the help desk.
<!-- #include file="common/helpers.inc" -->
Dim conn, rs, sql
On Error Resume Next
Set conn = Get-Connection()
Set rs = Server.CreateObject("ADODB.Recordset")
sql = "SELECT TicketId, CustomerName, Subject, Status FROM HelpDesk.Tickets WHERE Status = 'Open'"
rs.Open sql, conn, 1, 1
Response.Write "<html><head><title>HelpDesk</title></head><body>"
Response.Write "<h1>Open Tickets</h1><table border=""1"">"
Response.Write "<tr><th>TicketId</th><th>Customer</th><th>Subject</th><th>Status</th></tr>"
Do While Not rs.EOF
  Response.Write "<tr><td>" & rs("TicketId") & "</td><td>" & rs("CustomerName") & "</td><td>" & rs("Subject") & "</td><td>" & rs("Status") & "</td></tr>"
  rs.MoveNext
Loop
Response.Write "</table></body></html>"
rs.Close
conn.Close
If Err.Number <> 0 Then
  Response.Write "<!-- query error: " & Err.Description & " -->"
End If
%>
