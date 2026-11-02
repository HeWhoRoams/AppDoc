<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="search.aspx.cs" Inherits="HelpDesk.Pages.SearchPage" %>

<!DOCTYPE html>
<html>
<head><title>Ticket Lookup</title></head>
<body>
  <h1>Look Up a Ticket</h1>
  <form id="searchForm" runat="server">
    <input type="text" name="TicketId" id="TicketIdBox" />
    <input type="submit" name="lookup" value="Look up" />
  </form>
  <p id="Result"></p>
</body>
</html>
