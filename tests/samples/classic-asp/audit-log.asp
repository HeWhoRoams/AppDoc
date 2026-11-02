<%
' audit-log.asp - reads the audit trail table.
Dim conn, rs
On Error Resume Next
Set conn = Get-Connection()
Set rs = Server.CreateObject("ADODB.Recordset")
rs.Open "SELECT Action, ChangedBy, ChangedAt FROM HelpDesk.AuditTrail", conn, 1, 1
If Err.Number <> 0 Then
    Response.Write "<p>Failed to load audit trail: " & Err.Description & "</p>"
Else
    Response.Write "<h1>Audit Trail</h1><table border=""1"">"
    Do While Not rs.EOF
        Response.Write "<tr><td>" & rs("Action") & "</td><td>" & rs("ChangedBy") & "</td><td>" & FormatTicketDate(rs("ChangedAt")) & "</td></tr>"
        rs.MoveNext
    Loop
    Response.Write "</table>"
    rs.Close
End If
conn.Close
%>
