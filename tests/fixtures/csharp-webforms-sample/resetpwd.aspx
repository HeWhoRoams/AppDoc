<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="resetpwd.aspx.cs" Inherits="HelpDesk.Pages.ResetPwdPage" %>

<!DOCTYPE html>
<html>
<head><title>Reset Password</title></head>
<body>
  <h1>Reset Password</h1>
  <form id="resetForm" runat="server">
    <input type="text" name="Email" id="EmailBox" />
    <input type="submit" name="reset" value="Reset" />
  </form>
  <p id="Status"></p>
</body>
</html>
