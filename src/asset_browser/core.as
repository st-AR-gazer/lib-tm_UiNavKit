namespace UiNavKit {
    namespace AssetBrowser {

        void _MlBrowserFavoritesLoad() {
            g_MlBrowserFavorites.Resize(0);
            string raw = S_MlBrowserFavorites;
            if (raw.Length == 0) return;

            auto lines = raw.Split("\n");
            for (uint i = 0; i < lines.Length; ++i) {
                string ln = lines[i];
                if (ln.EndsWith("\r")) ln = ln.SubStr(0, ln.Length - 1);
                ln = _MlNoteUnesc(ln.Trim());
                if (ln.Length == 0) continue;
                bool dupe = false;
                for (uint j = 0; j < g_MlBrowserFavorites.Length; ++j) {
                    if (g_MlBrowserFavorites[j] == ln) {
                        dupe = true;
                        break;
                    }
                }
                if (!dupe) g_MlBrowserFavorites.InsertLast(ln);
            }
        }

        void _MlBrowserFavoritesSave() {
            array<string> lines;
            for (uint i = 0; i < g_MlBrowserFavorites.Length; ++i) {
                string u = g_MlBrowserFavorites[i].Trim();
                if (u.Length == 0) continue;
                lines.InsertLast(_MlNoteEsc(u));
            }
            S_MlBrowserFavorites = _JoinParts(lines, "\n");
        }

        void _MlBrowserFavoritesEnsureLoaded() {
            if (g_MlBrowserFavoritesLoaded) return;
            g_MlBrowserFavoritesLoaded = true;
            _MlBrowserFavoritesLoad();
        }

        int _MlBrowserFavoriteIx(const string &in rawUrl) {
            _MlBrowserFavoritesEnsureLoaded();
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return -1;
            for (uint i = 0; i < g_MlBrowserFavorites.Length; ++i) {
                if (g_MlBrowserFavorites[i] == url) return int(i);
            }
            return -1;
        }

        bool _MlBrowserIsFavorite(const string &in rawUrl) {
            return _MlBrowserFavoriteIx(rawUrl) >= 0;
        }

        void _MlBrowserToggleFavorite(const string &in rawUrl) {
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return;
            int ix = _MlBrowserFavoriteIx(url);
            if (ix >= 0) {
                g_MlBrowserFavorites.RemoveAt(uint(ix));
                _MlBrowserFavoritesSave();
                g_MlBrowserStatus = "Removed favorite: " + url;
                return;
            }
            g_MlBrowserFavorites.InsertLast(url);
            _MlBrowserFavoritesSave();
            g_MlBrowserStatus = "Added favorite: " + url;
        }

        string _MlBrowserFavoriteLabel(const string &in rawUrl) {
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return "(empty)";
            if (url.StartsWith("file://")) url = url.SubStr(7);
            int slash = url.LastIndexOf("/");
            if (slash >= 0 && slash + 1 < int(url.Length)) return url.SubStr(slash + 1);
            return url;
        }

        void _MlBrowserLog(const string &in msg) {
            if (!S_MlBrowserVerboseLogs) return;
            log(msg, LogLevel::Custom, 82, "UiNavKit::AssetBrowser::_MlBrowserLog", "BROWSER", "\\$7cf");
        }

        void _MlBrowserWarn(const string &in msg) {
            if (!S_MlBrowserVerboseLogs) return;
            log(msg, LogLevel::Warning, 87, "UiNavKit::AssetBrowser::_MlBrowserWarn");
        }

        string _MlBrowserNormalizeUrl(const string &in rawUrl) {
            string url = rawUrl.Trim();
            if (url.Length == 0) return "";
            url = url.Replace("\\", "/");
            if (url.StartsWith("file://")) return url;
            if (url.StartsWith("Media/")) return "file://" + url;
            return url;
        }

        bool _MlBrowserHasAllowedExt(const string &in pathLower) {
            return pathLower.EndsWith(".dds")
                || pathLower.EndsWith(".png")
                || pathLower.EndsWith(".jpg")
                || pathLower.EndsWith(".jpeg")
                || pathLower.EndsWith(".webp")
                || pathLower.EndsWith(".bmp")
                || pathLower.EndsWith(".tga")
                || pathLower.EndsWith(".svg");
        }

        void _MlBrowserAddEntry(
            dictionary &inout seen,
            const string &in rawUrl,
            const string &in source,
            const string &in kind
        ) {
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return;
            string key = url.ToLower();
            bool exists = false;
            if (seen.Get(key, exists)) return;
            seen.Set(key, true);

            auto e = MlBrowserEntry();
            e.url = url;
            e.source = source;
            e.kind = kind;
            g_MlBrowserEntries.InsertLast(e);
        }

        void _MlBrowserExtractXmlAttrUrls(
            const string &in xml,
            const string &in attr,
            const string &in source,
            dictionary &inout seen
        ) {
            if (xml.Length == 0 || attr.Length == 0) return;
            string needle = attr + "=\"";
            int scan = 0;
            while (scan >= 0 && scan < int(xml.Length)) {
                int idx = _IndexOfFrom(xml, needle, scan);
                if (idx < 0) break;
                int start = idx + int(needle.Length);
                int end = _IndexOfFrom(xml, "\"", start);
                if (end < 0 || end <= start) break;
                string value = xml.SubStr(start, end - start).Trim();
                if (value.Length > 0) _MlBrowserAddEntry(seen, value, source, attr);
                scan = end + 1;
            }
        }

    }
}
