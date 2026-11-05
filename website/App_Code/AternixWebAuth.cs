using System;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Caching;

namespace AternixWeb
{
    public sealed class PlayerSession
    {
        public readonly int AccountId;
        public readonly string Login;
        public readonly DateTime ExpiresUtc;
        public readonly int CredentialVersion;
        public PlayerSession(int id, string login, DateTime expires, int version)
        { AccountId = id; Login = login; ExpiresUtc = expires; CredentialVersion = version; }
    }

    public static class WebAuth
    {
        private const string SessionCookie = "__Host-AternixSession";
        private const string CsrfCookie = "__Host-AternixWebCsrf";
        private const string SessionPrefix = "Aternix.Auth.Session.v1.";
        private static readonly object AttemptLock = new object();
        private static readonly object CredentialLock = new object();
        private sealed class Attempts { public int Count; }
        public const string ConnectionString = "Data Source=lpc:localhost;Initial Catalog=MuOnlineS6;Integrated Security=True;Connect Timeout=5;Application Name=AternixWebAccount;";

        public static string Safe(object value)
        { return HttpUtility.HtmlEncode(Convert.ToString(value, CultureInfo.InvariantCulture)); }
        public static string Number(object value)
        { return value == null || value == DBNull.Value ? "0" : Convert.ToInt32(value, CultureInfo.InvariantCulture).ToString("N0", CultureInfo.GetCultureInfo("cs-CZ")); }
        private static bool ValidToken(string value)
        { return Regex.IsMatch(value ?? "", @"\A[A-Za-z0-9_-]{43}\z", RegexOptions.CultureInvariant); }
        private static string RandomToken()
        {
            byte[] bytes = new byte[32];
            using (RandomNumberGenerator random = RandomNumberGenerator.Create()) random.GetBytes(bytes);
            return Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        }
        private static string ReadCookie(HttpContext context, string name)
        { HttpCookie cookie = context.Request.Cookies[name]; return cookie == null ? "" : cookie.Value; }
        private static void WriteCookie(HttpContext context, string name, string value, DateTime? expires)
        {
            HttpCookie cookie = new HttpCookie(name, value);
            cookie.Path = "/"; cookie.Secure = true; cookie.HttpOnly = true; cookie.SameSite = SameSiteMode.Strict;
            if (expires.HasValue) cookie.Expires = expires.Value;
            context.Response.Cookies.Set(cookie);
        }
        public static void PrepareResponse(HttpContext context)
        {
            context.Response.ContentEncoding = Encoding.UTF8;
            context.Response.Cache.SetCacheability(HttpCacheability.NoCache);
            context.Response.Cache.SetNoStore();
            context.Response.TrySkipIisCustomErrors = true;
            context.Response.Headers["X-Frame-Options"] = "DENY";
            context.Response.Headers["X-Content-Type-Options"] = "nosniff";
            context.Response.Headers["Referrer-Policy"] = "same-origin";
        }
        public static string GetCsrf(HttpContext context)
        {
            string token = ReadCookie(context, CsrfCookie);
            if (!ValidToken(token)) { token = RandomToken(); WriteCookie(context, CsrfCookie, token, null); }
            return token;
        }
        public static bool CheckCsrf(HttpContext context, string supplied)
        {
            string expected = ReadCookie(context, CsrfCookie);
            if (!ValidToken(expected) || !ValidToken(supplied)) return false;
            int difference = 0;
            for (int i = 0; i < expected.Length; i++) difference |= expected[i] ^ supplied[i];
            return difference == 0;
        }
        public static bool AllowLoginAttempt(string address)
        {
            lock (AttemptLock)
            {
                string[] keys = { "Aternix.Login.Global.v1", "Aternix.Login.IP.v1." + address };
                int[] limits = { 100, 10 };
                for (int i = 0; i < keys.Length; i++)
                {
                    Attempts counter = HttpRuntime.Cache[keys[i]] as Attempts;
                    if (counter == null)
                    {
                        counter = new Attempts();
                        HttpRuntime.Cache.Insert(keys[i], counter, null, DateTime.UtcNow.AddMinutes(15),
                            Cache.NoSlidingExpiration, CacheItemPriority.NotRemovable, null);
                    }
                    if (counter.Count >= limits[i]) return false;
                    counter.Count++;
                }
                return true;
            }
        }
        private static string VersionKey(int id, string login)
        { return "Aternix.Auth.CredentialVersion.v1." + id.ToString(CultureInfo.InvariantCulture) + ":" + login.ToUpperInvariant(); }
        private static int CredentialVersion(int id, string login)
        {
            object version = HttpRuntime.Cache[VersionKey(id, login)];
            return version == null ? 0 : (int)version;
        }
        private static void RevokeAccountSessions(PlayerSession session)
        {
            int next = CredentialVersion(session.AccountId, session.Login) + 1;
            // Keep this marker longer than every existing 30-minute session.
            HttpRuntime.Cache.Insert(VersionKey(session.AccountId, session.Login), next, null,
                DateTime.UtcNow.AddHours(1), Cache.NoSlidingExpiration, CacheItemPriority.NotRemovable, null);
        }
        public static bool AllowPasswordAttempt(string address, PlayerSession session)
        {
            lock (AttemptLock)
            {
                string[] keys = { "Aternix.Password.Global.v1", "Aternix.Password.IP.v1." + address,
                    "Aternix.Password.Account.v1." + VersionKey(session.AccountId, session.Login) };
                int[] limits = { 100, 10, 5 };
                for (int i = 0; i < keys.Length; i++)
                {
                    Attempts counter = HttpRuntime.Cache[keys[i]] as Attempts;
                    if (counter == null)
                    {
                        counter = new Attempts();
                        HttpRuntime.Cache.Insert(keys[i], counter, null, DateTime.UtcNow.AddMinutes(15),
                            Cache.NoSlidingExpiration, CacheItemPriority.NotRemovable, null);
                    }
                    if (counter.Count >= limits[i]) return false;
                    counter.Count++;
                }
                return true;
            }
        }
        public static PlayerSession Authenticate(string login, string password)
        {
            lock (CredentialLock)
            {
            using (SqlConnection connection = new SqlConnection(ConnectionString))
            using (SqlCommand command = new SqlCommand("dbo.WebAuthenticate", connection))
            {
                command.CommandType = CommandType.StoredProcedure; command.CommandTimeout = 5;
                command.Parameters.Add("@Login", SqlDbType.NVarChar, 64).Value = login;
                command.Parameters.Add("@Password", SqlDbType.NVarChar, 128).Value = password;
                connection.Open();
                using (SqlDataReader reader = command.ExecuteReader())
                {
                    if (!reader.Read()) return null;
                    int id = Convert.ToInt32(reader["AccountId"], CultureInfo.InvariantCulture);
                    string canonical = Convert.ToString(reader["LoginName"], CultureInfo.InvariantCulture);
                    return new PlayerSession(id, canonical, DateTime.UtcNow.AddMinutes(30), CredentialVersion(id, canonical));
                }
            }
                    }
        }
        public static PlayerSession GetSession(HttpContext context)
        {
            lock (CredentialLock)
            {
            if (!context.Request.IsSecureConnection) return null;
            string token = ReadCookie(context, SessionCookie);
            if (!ValidToken(token)) return null;
            PlayerSession session = HttpRuntime.Cache[SessionPrefix + token] as PlayerSession;
            if (session == null || session.ExpiresUtc <= DateTime.UtcNow ||
                session.CredentialVersion != CredentialVersion(session.AccountId, session.Login)) return null;
            return session;
                    }
        }
        public static void SignIn(HttpContext context, PlayerSession session)
        {
            lock (CredentialLock)
            {
            if (!context.Request.IsSecureConnection) throw new InvalidOperationException("HTTPS required");
            if (session.CredentialVersion != CredentialVersion(session.AccountId, session.Login))
                throw new InvalidOperationException("Credentials changed; authenticate again");
            SignOut(context);
            string token = RandomToken();
            HttpRuntime.Cache.Insert(SessionPrefix + token, session, null, session.ExpiresUtc, Cache.NoSlidingExpiration);
            WriteCookie(context, SessionCookie, token, null);
            WriteCookie(context, CsrfCookie, RandomToken(), null);
                    }
        }
        public static void SignOut(HttpContext context)
        {
            string token = ReadCookie(context, SessionCookie);
            if (ValidToken(token)) HttpRuntime.Cache.Remove(SessionPrefix + token);
            WriteCookie(context, SessionCookie, "", DateTime.UtcNow.AddDays(-1));
        }
        public static int ChangePassword(HttpContext context, PlayerSession session, string oldPassword, string newPassword)
        {
            lock (CredentialLock)
            {
                if (!Object.ReferenceEquals(GetSession(context), session)) return 3;
                try
                {
                    using (SqlConnection connection = new SqlConnection(ConnectionString))
                    using (SqlCommand command = new SqlCommand("dbo.WebChangePassword", connection))
                    {
                        command.CommandType = CommandType.StoredProcedure; command.CommandTimeout = 5;
                        command.Parameters.Add("@AccountId", SqlDbType.Int).Value = session.AccountId;
                        command.Parameters.Add("@Login", SqlDbType.NVarChar, 64).Value = session.Login;
                        command.Parameters.Add("@OldPassword", SqlDbType.NVarChar, 128).Value = oldPassword;
                        command.Parameters.Add("@NewPassword", SqlDbType.NVarChar, 128).Value = newPassword;
                        SqlParameter result = command.Parameters.Add("@Result", SqlDbType.Int);
                        result.Direction = ParameterDirection.ReturnValue;
                        connection.Open(); command.ExecuteNonQuery();
                        int status = Convert.ToInt32(result.Value, CultureInfo.InvariantCulture);
                        if (status == 0)
                        {
                            RevokeAccountSessions(session);
                            SignOut(context);
                            WriteCookie(context, CsrfCookie, RandomToken(), null);
                        }
                        return status;
                    }
                }
                catch
                {
                    // A timeout may happen after SQL committed. Revoke sessions even when outcome is uncertain.
                    RevokeAccountSessions(session); SignOut(context); throw;
                }
            }
        }
        public static DataTable LoadCharacters(PlayerSession session)
        {
            using (SqlConnection connection = new SqlConnection(ConnectionString))
            using (SqlCommand command = new SqlCommand("dbo.WebGetAccountCharacters", connection))
            {
                command.CommandType = CommandType.StoredProcedure; command.CommandTimeout = 5;
                command.Parameters.Add("@AccountId", SqlDbType.Int).Value = session.AccountId;
                command.Parameters.Add("@Login", SqlDbType.NVarChar, 64).Value = session.Login;
                connection.Open();
                using (SqlDataReader reader = command.ExecuteReader())
                {
                    if (!reader.Read()) return null;
                    if (Convert.ToInt32(reader["AccountId"], CultureInfo.InvariantCulture) != session.AccountId ||
                        !String.Equals(Convert.ToString(reader["LoginName"], CultureInfo.InvariantCulture), session.Login, StringComparison.OrdinalIgnoreCase)) return null;
                    if (!reader.NextResult()) throw new InvalidOperationException("Missing character result set");
                    DataTable characters = new DataTable(); characters.Load(reader); return characters;
                }
            }
        }
        public static string CharacterClass(object value)
        {
            if (value == null || value == DBNull.Value) return "Neznámá třída";
            switch (Convert.ToInt32(value, CultureInfo.InvariantCulture))
            {
                case 0: return "Dark Wizard"; case 1: return "Soul Master"; case 2: return "Grand Master";
                case 16: return "Dark Knight"; case 17: return "Blade Knight"; case 18: return "Blade Master";
                case 32: return "Fairy Elf"; case 33: return "Muse Elf"; case 34: return "High Elf";
                case 48: return "Magic Gladiator"; case 49: case 50: return "Duel Master";
                case 64: return "Dark Lord"; case 65: case 66: return "Lord Emperor";
                case 80: return "Summoner"; case 81: return "Bloody Summoner"; case 82: return "Dimension Master";
                case 96: return "Rage Fighter"; case 97: case 98: return "Fist Master";
                default: return "Neznámá třída";
            }
        }
    }
}
