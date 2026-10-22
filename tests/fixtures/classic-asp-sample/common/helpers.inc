<%
' helpers.inc - shared helper functions for the HelpDesk classic-ASP app.
Function Get-Connection()
    Dim c
    Set c = Server.CreateObject("ADODB.Connection")
    c.ConnectionString = "Provider=SQLOLEDB;Data Source=FIXTURE-SERVER;Initial Catalog=FIXTURE_DB;User Id=fakeuser;Password=fakepass"
    c.Open
    Set Get-Connection = c
End Function

Function FormatTicketDate(ByVal v)
    If IsNull(v) Or v = "" Then
        FormatTicketDate = "—"
    Else
        FormatTicketDate = CStr(v)
    End If
End Function

Sub LogEvent(ByVal msg)
    Response.Write "<!-- LOG: " & msg & " -->"
End Sub
%>
