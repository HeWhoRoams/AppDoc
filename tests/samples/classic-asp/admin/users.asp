<!-- #include virtual="/common/helpers.inc" -->
<%
' admin/users.asp - admin-only user maintenance.
If Session("Authenticated") <> True Then
    Response.Redirect "../index.asp"
End If
If Session("UserRole") <> "Admin" And Session("UserRole") <> "Supervisor" Then Response.End
REM old code: Server.CreateObject("Fake.Commented")
' Response.Write "commented error text"
Dim conn, rs, cmd, userName, sql
userName = Request.Form("UserName")
If userName = "" Then
    Response.Write "<p>User name must be supplied.</p>"
End If
Set conn = Get-Connection()
sql = "UPDATE HelpDesk.Users " & _
      "SET LastSeen = GETDATE() " & _
      "WHERE UserName = '" & Replace(userName, "'", "''") & "'"
conn.Execute sql
conn.Execute "{call HelpDesk.usp_AuditLogin('" & userName & "')}"
conn.Execute "DELETE FROM HelpDesk.SessionCache WHERE Expired = 1"
Set rs = conn.Execute("INSERT INTO HelpDesk.UserLog (UserName) VALUES ('x')")
Dim page
page = Request.QueryString("page") & Request.ServerVariables("REMOTE_USER")
%>
<h1>Users</h1>
<% If Request.QueryString("debug") = "1" Then %>
<p>Debug on <%= Request.QueryString("level") %></p>
<% End If %>
<%
Set fso = Server.CreateObject("Scripting.FileSystemObject")
Set mail = Server.CreateObject("CDO.Message")
Set http = Server.CreateObject("MSXML2.ServerXMLHTTP.6.0")
Set legacy = CreateObject("HelpDesk.LegacyCom")
If Err.Number <> 0 Then
    Response.Write "<p class=""err"">Access denied for user: " & userName & "</p>"
Else
    Response.Write "<p>Saved.</p>"
End If
%>
