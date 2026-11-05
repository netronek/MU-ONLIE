<%@ Page Language="C#" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Globalization" %>
<script runat="server">
protected DataTable Ranking;
protected bool RankingUnavailable;

protected void Page_Load(object sender, EventArgs e)
{
    Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
    Response.Cache.SetNoStore();
    Response.TrySkipIisCustomErrors = true;
    const string cacheKey = "AternixMU.WebRanking.v1";
    Ranking = System.Web.HttpRuntime.Cache[cacheKey] as DataTable;
    if (Ranking != null) return;

    try
    {
        DataTable result = new DataTable();
        using (SqlConnection connection = new SqlConnection(
            "Data Source=lpc:localhost;Initial Catalog=MuOnlineS6;Integrated Security=True;Connect Timeout=5;Application Name=AternixWebRanking;"))
        using (SqlCommand command = new SqlCommand(
            "SELECT TOP (100) CharacterName, ClassCode, CharacterLevel, Resets, MasterResets " +
            "FROM dbo.WebRanking ORDER BY MasterResets DESC, Resets DESC, CharacterLevel DESC, CharacterName ASC", connection))
        {
            command.CommandTimeout = 5;
            connection.Open();
            using (SqlDataReader reader = command.ExecuteReader()) result.Load(reader);
        }
        Ranking = result;
        System.Web.HttpRuntime.Cache.Insert(cacheKey, result, null,
            DateTime.UtcNow.AddSeconds(30), System.Web.Caching.Cache.NoSlidingExpiration);
    }
    catch (Exception error)
    {
        RankingUnavailable = true;
        Response.StatusCode = 503;
        System.Diagnostics.Trace.TraceError("AternixMU ranking: " + error.GetType().Name);
    }
}

protected string CharacterClass(object value)
{
    if (value == null || value == DBNull.Value) return "Neznámá třída";
    int code = Convert.ToInt32(value, CultureInfo.InvariantCulture);
    switch (code)
    {
        case 0: return "Dark Wizard";
        case 1: return "Soul Master";
        case 2: return "Grand Master";
        case 16: return "Dark Knight";
        case 17: return "Blade Knight";
        case 18: return "Blade Master";
        case 32: return "Fairy Elf";
        case 33: return "Muse Elf";
        case 34: return "High Elf";
        case 48: return "Magic Gladiator";
        case 49: case 50: return "Duel Master";
        case 64: return "Dark Lord";
        case 65: case 66: return "Lord Emperor";
        case 80: return "Summoner";
        case 81: return "Bloody Summoner";
        case 82: return "Dimension Master";
        case 96: return "Rage Fighter";
        case 97: case 98: return "Fist Master";
        default: return "Neznámá třída";
    }
}

protected string Text(object value)
{
    return Server.HtmlEncode(Convert.ToString(value, CultureInfo.InvariantCulture));
}

protected string Number(object value)
{
    if (value == null || value == DBNull.Value) return "0";
    return Convert.ToInt32(value, CultureInfo.InvariantCulture).ToString("N0", CultureInfo.GetCultureInfo("cs-CZ"));
}
</script>
<!doctype html>
<html lang="cs">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="Žebříček postav AternixMU Season 6 podle master resetů, resetů a levelu.">
<meta name="theme-color" content="#0b1015">
<meta name="robots" content="noindex, nofollow">
<title>Žebříček postav · AternixMU</title>
<link rel="icon" href="assets/favicon.ico">
<link rel="stylesheet" href="style.css">
<link rel="stylesheet" href="ranking.css">
</head>
<body>
<a class="skip" href="#obsah">Přejít na obsah</a>
<header class="header">
<a class="brand" href="index.html" aria-label="AternixMU — úvod"><span class="brand-symbol" aria-hidden="true">A</span><span>ATERNIX<span class="gold">MU</span><small>MU ONLINE · SEASON 6</small></span></a>
<nav aria-label="Hlavní navigace"><a href="index.html#projekt">O serveru</a><a href="ranking.aspx" aria-current="page">Žebříček</a><a href="register.aspx">Registrace</a><a href="account.aspx">Můj účet</a><a href="index.html#stazeni">Ke stažení</a><a href="index.html#komunita">Komunita</a></nav>
<a class="nav-button" href="index.html#stazeni">Získat launcher <span aria-hidden="true">→</span></a>
</header>
<main id="obsah" class="ranking-main">
<div class="ranking-heading"><p class="eyebrow">ATERNIXMU / SEASON 6</p><h1>Hrdinové <em>Aternixu.</em></h1><p>Žebříček nejlepších 100 postav. Každý reset píše další kapitolu.</p><div class="ranking-meta"><span class="pill">TESTOVACÍ PROVOZ</span><span>Řazení: master resety → resety → level</span></div></div>
<% if (RankingUnavailable) { %>
<section class="ranking-message" role="status"><h2>Žebříček je dočasně nedostupný.</h2><p>Zkuste stránku načíst znovu za chvíli.</p><a class="button secondary" href="ranking.aspx">Načíst znovu →</a></section>
<% } else if (Ranking.Rows.Count == 0) { %>
<section class="ranking-message"><h2>Příběh teprve začíná.</h2><p>V žebříčku zatím nejsou žádné postavy.</p></section>
<% } else { %>
<div class="ranking-scroll" role="region" aria-label="Žebříček postav, tabulku lze posouvat vodorovně" tabindex="0">
<table class="ranking-table"><caption>Pořadí postav podle master resetů, resetů a levelu</caption><thead><tr><th scope="col">#</th><th scope="col">Postava</th><th scope="col">Třída</th><th scope="col" class="numeric">Level</th><th scope="col" class="numeric">Resety</th><th scope="col" class="numeric">Master resety</th></tr></thead><tbody>
<% for (int i = 0; i < Ranking.Rows.Count; i++) { DataRow row = Ranking.Rows[i]; %>
<tr<%= i < 3 ? " class=\"ranking-top\"" : "" %>><td class="place"><%= i + 1 %></td><th scope="row"><%= Text(row["CharacterName"]) %></th><td class="class-name"><%= Text(CharacterClass(row["ClassCode"])) %></td><td class="numeric"><%= Number(row["CharacterLevel"]) %></td><td class="numeric"><%= Number(row["Resets"]) %></td><td class="numeric masters"><%= Number(row["MasterResets"]) %></td></tr>
<% } %>
</tbody></table></div>
<% } %>
<p class="ranking-note">Údaje se obnovují přibližně každých 30 sekund. Postavy s nenulovým administrátorským či blokovacím příznakem nejsou zahrnuté.</p>
<a class="ranking-back" href="index.html">← Zpět na hlavní stránku</a>
</main>
<footer class="footer"><a class="footer-brand" href="index.html">ATERNIXMU<span>SEASON 6</span></a><p>Komunitní projekt MU Online · Testovací provoz</p><a href="https://discord.gg/tMENCSJJZE" target="_blank" rel="noopener noreferrer">Discord →</a></footer>
</body>
</html>
