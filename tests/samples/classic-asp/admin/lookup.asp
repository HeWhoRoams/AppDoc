<!-- #include file="../common/helpers.inc" -->
<!-- #include file="missing-but-listed.inc" -->
<%
' lookup.asp - stored procedure through ADODB.Command with a literal connection string.
Dim cn, cmd, strConn
strConn = "Provider=SQLOLEDB;Data Source=FIXTURE-SERVER;Initial Catalog=FIXTURE_DB;Uid=fakeuser;Pwd=fakepass2"
Set cn = Server.CreateObject("ADODB.Connection")
cn.Open strConn
cn.Open "DSN=HelpDeskDsn;Pwd=fakepass3"
Set cmd = Server.CreateObject("ADODB.Command")
cmd.CommandText = "HelpDesk.usp_LookupUser"
cmd.CommandType = adCmdStoredProc
%>
