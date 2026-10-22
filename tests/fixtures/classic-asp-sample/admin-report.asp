<%
' admin-report.asp - runs a stored procedure directly via EXEC and streams the result.
Dim conn, sql
On Error Resume Next
Set conn = Get-Connection()
sql = "EXEC HelpDesk.usp_GetMonthlyMetrics"
rs = Server.CreateObject("ADODB.Recordset")
rs.Open sql, conn, 1, 1
If Err.Number <> 0 Then
    Response.Write "<!-- report error: " & Err.Description & " -->"
Else
    Response.Write "<h1>Monthly Metrics</h1>"
    Do While Not rs.EOF
        Response.Write "<p>" & rs.Fields(0) & ": " & rs.Fields(1) & "</p>"
        rs.MoveNext
    Loop
    rs.Close
End If
conn.Close
%>
