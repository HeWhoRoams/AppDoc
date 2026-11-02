<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="users.aspx.cs" Inherits="HelpDesk.Admin.UsersPage" MasterPageFile="~/Site.master" %>

<asp:Content ID="Main" ContentPlaceHolderID="body" runat="server">
  <asp:TextBox ID="UserName" runat="server" />
  <asp:RequiredFieldValidator ID="rfvName" ControlToValidate="UserName"
      ErrorMessage="User name is required." runat="server" />
  <asp:Button ID="SaveBtn" Text="Save" OnClick="SaveBtn_Click" runat="server" />
  <asp:Label ID="lblError" runat="server" />
  <!-- <asp:RequiredFieldValidator ErrorMessage="Commented out validator message." runat="server" /> -->
</asp:Content>
<script runat="server">
  protected void Cancel_Click(object sender, EventArgs e)
  {
      Response.Redirect("~/index.aspx");
  }
</script>
