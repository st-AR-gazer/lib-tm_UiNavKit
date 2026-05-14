namespace UiNavKit {
    namespace AssetBrowser {

        bool _MlBrowserEntryMatches(const MlBrowserEntry@ e, const string &in filterLower) {
            if (e is null) return false;
            if (filterLower.Length == 0) return true;
            return e.url.ToLower().IndexOf(filterLower) >= 0
                || e.source.ToLower().IndexOf(filterLower) >= 0
                || e.kind.ToLower().IndexOf(filterLower) >= 0;
        }

        bool _MlBrowserTryGetNadeoRelPath(const string &in rawUrl, string &out relPath) {
            relPath = "";
            string url = _MlBrowserNormalizeUrl(rawUrl);
            const string kPrefixA = "file://Media/Manialinks/Nadeo/";
            if (!url.StartsWith(kPrefixA)) return false;
            relPath = url.SubStr(kPrefixA.Length);

            relPath = _MlBrowserCollapseSlashes(relPath.Trim());
            while (relPath.StartsWith("/")) relPath = relPath.SubStr(1);
            while (relPath.EndsWith("/")) relPath = relPath.SubStr(0, relPath.Length - 1);
            return relPath.Length > 0;
        }

        void _MlBrowserSplitRelPath(const string &in relPath, array<string> &out parts) {
            parts.Resize(0);
            int start = 0;
            int len = int(relPath.Length);
            for (int i = 0; i <= len; ++i) {
                bool atSep = i == len || relPath.SubStr(i, 1) == "/";
                if (!atSep) continue;
                if (i > start) parts.InsertLast(relPath.SubStr(start, i - start));
                start = i + 1;
            }
        }

        bool _MlBrowserTreeComesBefore(const MlBrowserTreeNode@ a, const MlBrowserTreeNode@ b) {
            if (a is null) return false;
            if (b is null) return true;
            if (a.isFile != b.isFile) return !a.isFile;
            string an = a.name.ToLower();
            string bn = b.name.ToLower();
            if (an == bn) return a.name < b.name;
            return an < bn;
        }

        MlBrowserTreeNode@ _MlBrowserTreeGetOrCreateChild(
            MlBrowserTreeNode@ parent,
            const string &in name,
            bool isFile,
            const string &in key
        ) {
            if (parent is null) return null;
            for (uint i = 0; i < parent.children.Length; ++i) {
                auto c = parent.children[i];
                if (c is null) continue;
                if (c.name == name && c.isFile == isFile) return c;
            }

            if (g_MlBrowserBuildNodeCount >= g_MlBrowserBuildMaxNodes) {
                g_MlBrowserBuildTruncated = true;
                return null;
            }

            auto node = MlBrowserTreeNode();
            node.name = name;
            node.key = key;
            node.isFile = isFile;

            uint insertIx = parent.children.Length;
            for (uint i = 0; i < parent.children.Length; ++i) {
                if (_MlBrowserTreeComesBefore(node, parent.children[i])) {
                    insertIx = i;
                    break;
                }
            }
            parent.children.InsertAt(insertIx, node);
            g_MlBrowserBuildNodeCount++;
            return node;
        }

        MlBrowserTreeNode@ _MlBrowserBuildNadeoTree(
            const string &in filterLower,
            int &out shownFiles,
            int &out totalFiles,
            bool &out truncated
        ) {
            shownFiles = 0;
            totalFiles = 0;
            truncated = false;
            const uint kBuildBudgetMs = 40;
            uint startedAt = Time::Now;
            g_MlBrowserBuildMaxNodes = 35000;
            g_MlBrowserBuildNodeCount = 1;
            g_MlBrowserBuildTruncated = false;
            auto root = MlBrowserTreeNode();
            root.name = "Nadeo";
            root.key = "Nadeo";
            root.isFile = false;

            for (uint i = 0; i < g_MlBrowserEntries.Length; ++i) {
                if (Time::Now - startedAt > kBuildBudgetMs) {
                    truncated = true;
                    break;
                }
                auto e = g_MlBrowserEntries[i];
                if (e is null) continue;
                string relPath = "";
                if (!_MlBrowserTryGetNadeoRelPath(e.url, relPath)) continue;
                totalFiles++;
                if (!_MlBrowserEntryMatches(e, filterLower)) continue;
                shownFiles++;

                array<string> parts;
                _MlBrowserSplitRelPath(relPath, parts);
                if (parts.Length == 0) continue;

                MlBrowserTreeNode@ cur = root;
                string keyAcc = "";
                for (uint p = 0; p < parts.Length; ++p) {
                    if (keyAcc.Length > 0) keyAcc += "/";
                    keyAcc += parts[p];
                    bool isLeaf = p + 1 >= parts.Length;
                    auto child = _MlBrowserTreeGetOrCreateChild(cur, parts[p], isLeaf, keyAcc);
                    if (child is null) break;
                    if (isLeaf) @child.entry = e;
                    @cur = child;
                }
                if (g_MlBrowserBuildTruncated) {
                    truncated = true;
                    break;
                }
            }
            if (g_MlBrowserBuildTruncated) truncated = true;

            return root;
        }

        void _MlBrowserInvalidateTreeCache() {
            @g_MlBrowserTreeCacheRoot = null;
            g_MlBrowserTreeCacheFilter = "";
            g_MlBrowserTreeCacheEntryCount = 0;
            g_MlBrowserTreeCacheShownFiles = 0;
            g_MlBrowserTreeCacheTotalFiles = 0;
            g_MlBrowserTreeCacheTruncated = false;
            g_MlBrowserTreeCacheDirty = true;
        }

        void _MlBrowserInvalidateThumbCache() {
            g_MlBrowserThumbTextureCache.DeleteAll();
            g_MlBrowserThumbErrorCache.DeleteAll();
            g_MlBrowserThumbCacheKeys.Resize(0);
        }

        bool _MlBrowserTryConsumeThumbBudget() {
            const uint kWindowMs = 16;
            const uint kBudgetPerWindow = 2;
            uint now = Time::Now;
            if (g_MlBrowserThumbBudgetWindowStartedMs == 0 || (now - g_MlBrowserThumbBudgetWindowStartedMs) >= kWindowMs) {
                g_MlBrowserThumbBudgetWindowStartedMs = now;
                g_MlBrowserThumbBudgetConsumed = 0;
            }
            if (g_MlBrowserThumbBudgetConsumed >= kBudgetPerWindow) return false;
            g_MlBrowserThumbBudgetConsumed++;
            return true;
        }

        int _MlBrowserFindQueuedConversionIx(const string &in url, const string &in rawPath = "") {
            string u = _MlBrowserNormalizeUrl(url);
            string raw = rawPath.Trim();
            if (u.Length == 0) return -1;
            for (uint i = 0; i < g_MlBrowserConvertQueueUrls.Length; ++i) {
                if (g_MlBrowserConvertQueueUrls[i] != u) continue;
                if (raw.Length == 0 || g_MlBrowserConvertQueueRawPaths[i] == raw) return int(i);
            }
            return -1;
        }

        void _MlBrowserEnqueueConversion(const string &in url, const string &in rawPath) {
            if (url.Length == 0 || rawPath.Length == 0) return;
            if (_MlBrowserFindQueuedConversionIx(url, rawPath) >= 0) return;
            const uint kMaxQueue = 16;
            if (g_MlBrowserConvertQueueUrls.Length >= kMaxQueue) return;
            g_MlBrowserConvertQueueUrls.InsertLast(url);
            g_MlBrowserConvertQueueRawPaths.InsertLast(rawPath);
            g_MlBrowserConvertQueueQueuedAtMs.InsertLast(Time::Now);
        }

        bool _MlBrowserPopNextQueuedConversion(string &out url, string &out rawPath, uint &out queuedAtMs) {
            url = "";
            rawPath = "";
            queuedAtMs = 0;
            if (g_MlBrowserConvertQueueUrls.Length == 0) return false;

            url = g_MlBrowserConvertQueueUrls[0];
            rawPath = g_MlBrowserConvertQueueRawPaths[0];
            queuedAtMs = g_MlBrowserConvertQueueQueuedAtMs[0];
            g_MlBrowserConvertQueueUrls.RemoveAt(0);
            g_MlBrowserConvertQueueRawPaths.RemoveAt(0);
            g_MlBrowserConvertQueueQueuedAtMs.RemoveAt(0);
            return true;
        }

        void _MlBrowserClearActiveConversion() {
            g_MlBrowserConvertJobRunning = false;
            g_MlBrowserConvertJobUrl = "";
            g_MlBrowserConvertJobRawPath = "";
            g_MlBrowserConvertJobQueuedAtMs = 0;
            g_MlBrowserConvertJobStartedMs = 0;
        }

        void _MlBrowserStartActiveConversion(const string &in url, const string &in rawPath, uint queuedAtMs) {
            g_MlBrowserConvertJobRunning = true;
            g_MlBrowserConvertJobUrl = url;
            g_MlBrowserConvertJobRawPath = rawPath;
            g_MlBrowserConvertJobQueuedAtMs = queuedAtMs;
            g_MlBrowserConvertJobStartedMs = Time::Now;
        }

        int _MlBrowserConversionQueuePosition(const string &in rawUrl) {
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return -1;
            if (g_MlBrowserConvertJobRunning && g_MlBrowserConvertJobUrl == url) return 0;
            int queuedIx = _MlBrowserFindQueuedConversionIx(url);
            if (queuedIx < 0) return -1;
            return queuedIx + 1;
        }

        uint _MlBrowserConversionQueuedMs(const string &in rawUrl) {
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return 0;
            if (g_MlBrowserConvertJobRunning && g_MlBrowserConvertJobUrl == url) {
                if (g_MlBrowserConvertJobStartedMs >= g_MlBrowserConvertJobQueuedAtMs) {
                    return g_MlBrowserConvertJobStartedMs - g_MlBrowserConvertJobQueuedAtMs;
                }
                return 0;
            }
            int queuedIx = _MlBrowserFindQueuedConversionIx(url);
            if (queuedIx < 0) return 0;
            return Time::Now - g_MlBrowserConvertQueueQueuedAtMs[uint(queuedIx)];
        }

        uint _MlBrowserConversionDecodeMs(const string &in rawUrl) {
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return 0;
            if (!(g_MlBrowserConvertJobRunning && g_MlBrowserConvertJobUrl == url)) return 0;
            return Time::Now - g_MlBrowserConvertJobStartedMs;
        }

        string _MlBrowserShortElapsed(uint elapsedMs) {
            if (elapsedMs < 1000) return elapsedMs + "ms";
            uint sec = elapsedMs / 1000;
            return sec + "s";
        }

        bool _MlBrowserGetLoadingInfo(const string &in rawUrl, string &out line1, string &out line2) {
            line1 = "";
            line2 = "";

            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return false;

            int queuePos = _MlBrowserConversionQueuePosition(url);
            if (queuePos < 0) return false;

            line1 = "Loading preview " + _MlBrowserPreviewLoadingFrame();
            if (queuePos == 0) {
                uint decodeMs = _MlBrowserConversionDecodeMs(url);
                uint queuedMs = _MlBrowserConversionQueuedMs(url);
                line2 = "Dec " + _MlBrowserShortElapsed(decodeMs);
                if (queuedMs > 0) line2 += " | Q " + _MlBrowserShortElapsed(queuedMs);
            } else {
                uint queuedMs = _MlBrowserConversionQueuedMs(url);
                line2 = "Q #" + queuePos + " | " + _MlBrowserShortElapsed(queuedMs);
            }
            return true;
        }

        void _MlBrowserEnsureTreeCache(const string &in filterLower) {
            bool needsRebuild = g_MlBrowserTreeCacheDirty
                || g_MlBrowserTreeCacheRoot is null
                || g_MlBrowserTreeCacheFilter != filterLower
                || g_MlBrowserTreeCacheEntryCount != g_MlBrowserEntries.Length;
            if (!needsRebuild) return;

            uint now = Time::Now;
            if (g_MlBrowserTreeCacheRoot !is null && (now - g_MlBrowserTreeLastBuildMs) < 120 && g_MlBrowserTreeCacheFilter != filterLower) {
                return;
            }

            bool truncated = false;
            int shown = 0;
            int total = 0;
            auto root = _MlBrowserBuildNadeoTree(filterLower, shown, total, truncated);
            @g_MlBrowserTreeCacheRoot = root;
            g_MlBrowserTreeCacheFilter = filterLower;
            g_MlBrowserTreeCacheEntryCount = g_MlBrowserEntries.Length;
            g_MlBrowserTreeCacheShownFiles = shown;
            g_MlBrowserTreeCacheTotalFiles = total;
            g_MlBrowserTreeCacheTruncated = truncated;
            g_MlBrowserTreeCacheDirty = false;
            g_MlBrowserTreeLastBuildMs = now;
        }

    }
}
