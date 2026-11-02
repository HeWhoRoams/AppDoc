<%@ page contentType="text/html" %>
<%-- <% request.getParameter("hidden") %> --%>
<html><body>
<% String q = request.getParameter("query"); %>
<sec:authorize access="hasRole('ADMIN')">admin</sec:authorize>
</body></html>
