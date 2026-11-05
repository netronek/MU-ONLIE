<%@ Page Language="C#" ResponseEncoding="utf-8" EnableSessionState="false" %>
<%@ Import Namespace="AternixWeb" %>
<script runat="server">
protected string FormToken = "";
protected bool InvalidRequest;
protected void Page_Load(object sender, EventArgs e)
{
    WebAuth.PrepareResponse(Context);
    if (!Request.IsSecureConnection)
    {
        if (Request.HttpMethod == "POST") { InvalidRequest = true; Response.StatusCode = 400; return; }
        Response.Redirect("https://aternixmu.eu/logout.aspx", true); return;
    }
    FormToken = WebAuth.GetCsrf(Context);
    if (Request.HttpMethod == "GET") return;
    if (Request.HttpMethod != "POST") { InvalidRequest = true; Response.StatusCode = 405; return; }
    if (Request.ContentLength > 8192 || !WebAuth.CheckCsrf(Context, Request.Form["csrf"]))
    { InvalidRequest = true; Response.StatusCode = 400; return; }
    WebAuth.SignOut(Context);
    Response.Redirect("login.aspx", true);
}
</script>
<!doctype html><html lang="cs"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex, nofollow"><title>Odhlášení · AternixMU</title><link rel="icon" href="assets/favicon.ico"><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="account.css"></head><body><main class="logout-main"><p class="eyebrow">ATERNIXMU / HRÁČSKÝ ÚČET</p><% if (InvalidRequest) { %><h1>Požadavek <em>vypršel.</em></h1><p>Vrať se do účtu a odhlas se znovu.</p><a class="button secondary" href="account.aspx">Zpět do účtu →</a><% } else { %><h1>Chceš se <em>odhlásit?</em></h1><p>Odhlášení z webu neukončí běžící hru.</p><form method="post" action="logout.aspx"><input type="hidden" name="csrf" value="<%= WebAuth.Safe(FormToken) %>"><button class="button primary" type="submit">Odhlásit se →</button></form><a class="ranking-back" href="account.aspx">Zpět do účtu</a><% } %></main></body></html>
