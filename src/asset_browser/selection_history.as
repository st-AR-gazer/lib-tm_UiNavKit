namespace UiNavKit {
    namespace AssetBrowser {

        void _MlBrowserResetVisibleUrls() {
            g_MlBrowserVisibleUrls.Resize(0);
        }

        void _MlBrowserMoveSelection(int delta) {
            if (delta == 0 || g_MlBrowserVisibleUrls.Length == 0) return;

            string selected = _MlBrowserNormalizeUrl(g_MlBrowserSelectedUrl);
            int selectedIx = -1;
            for (uint i = 0; i < g_MlBrowserVisibleUrls.Length; ++i) {
                if (g_MlBrowserVisibleUrls[i] == selected) {
                    selectedIx = int(i);
                    break;
                }
            }

            int nextIx = selectedIx;
            if (nextIx < 0) {
                nextIx = delta > 0 ? 0 : int(g_MlBrowserVisibleUrls.Length) - 1;
            } else {
                nextIx += delta;
                if (nextIx < 0) nextIx = 0;
                if (nextIx >= int(g_MlBrowserVisibleUrls.Length)) nextIx = int(g_MlBrowserVisibleUrls.Length) - 1;
            }

            if (nextIx < 0 || nextIx >= int(g_MlBrowserVisibleUrls.Length)) return;
            string nextUrl = g_MlBrowserVisibleUrls[uint(nextIx)];
            if (nextUrl.Length == 0) return;

            g_MlBrowserScrollToSelection = true;
            _MlBrowserSelectUrl(nextUrl);
        }

        void _MlBrowserHandleListKeyboardNavigation() {
            if (!UI::IsWindowFocused()) return;
            if (g_MlBrowserVisibleUrls.Length == 0) return;

            if (UI::IsKeyPressed(UI::Key::DownArrow)) {
                _MlBrowserMoveSelection(1);
            } else if (UI::IsKeyPressed(UI::Key::UpArrow)) {
                _MlBrowserMoveSelection(-1);
            }
        }

        void _MlBrowserClearFolderSelection() {
            g_MlBrowserSelectedFolderKey = "";
            g_MlBrowserSelectedFolderName = "";
        }

        void _MlBrowserPushHistory() {
            MlBrowserHistoryEntry@ entry = MlBrowserHistoryEntry();
            entry.url = g_MlBrowserSelectedUrl;
            entry.folderKey = g_MlBrowserSelectedFolderKey;
            entry.folderName = g_MlBrowserSelectedFolderName;
            g_MlBrowserHistory.InsertLast(entry);
            const uint kMaxHistory = 64;
            if (g_MlBrowserHistory.Length > kMaxHistory) g_MlBrowserHistory.RemoveAt(0);
        }

        bool _MlBrowserCanGoBack() {
            return g_MlBrowserHistory.Length > 0;
        }

        bool _MlBrowserGoBack() {
            if (g_MlBrowserHistory.Length == 0) return false;
            auto entry = g_MlBrowserHistory[g_MlBrowserHistory.Length - 1];
            g_MlBrowserHistory.RemoveAt(g_MlBrowserHistory.Length - 1);
            if (entry is null) return false;

            g_MlBrowserSelectedUrl = entry.url;
            g_MlBrowserSelectedFolderKey = entry.folderKey;
            g_MlBrowserSelectedFolderName = entry.folderName;
            _MlBrowserResetPreview();
            if (g_MlBrowserSelectedUrl.Length > 0) {
                g_MlBrowserLoadPreviewRequested = S_MlBrowserAutoPreview;
            }
            return true;
        }

        void _MlBrowserSelectFolder(const string &in key, const string &in name) {
            string folderKey = key.Trim();
            if (folderKey.Length == 0) return;
            if (g_MlBrowserSelectedFolderKey == folderKey) return;
            _MlBrowserPushHistory();
            g_MlBrowserSelectedFolderKey = folderKey;
            g_MlBrowserSelectedFolderName = name;
            g_MlBrowserSelectedUrl = "";
            _MlBrowserResetPreview();
        }

        MlBrowserTreeNode@ _MlBrowserFindTreeNodeByKey(MlBrowserTreeNode@ node, const string &in key) {
            if (node is null || key.Length == 0) return null;
            if (node.key == key) return node;
            for (uint i = 0; i < node.children.Length; ++i) {
                auto found = _MlBrowserFindTreeNodeByKey(node.children[i], key);
                if (found !is null) return found;
            }
            return null;
        }

        void _MlBrowserCollectFolderEntriesRec(MlBrowserTreeNode@ node, array<MlBrowserEntry@> &out entries) {
            if (node is null) return;
            if (node.isFile) {
                if (node.entry !is null) entries.InsertLast(node.entry);
                return;
            }
            for (uint i = 0; i < node.children.Length; ++i) {
                _MlBrowserCollectFolderEntriesRec(node.children[i], entries);
            }
        }

        void _MlBrowserCollectEntriesForFolderKey(const string &in folderKeyRaw, array<MlBrowserEntry@> &out entries) {
            entries.Resize(0);
            string folderKey = _MlBrowserCollapseSlashes(folderKeyRaw.Trim());
            while (folderKey.StartsWith("/")) folderKey = folderKey.SubStr(1);
            while (folderKey.EndsWith("/")) folderKey = folderKey.SubStr(0, folderKey.Length - 1);
            if (folderKey.Length == 0) return;

            string folderPrefix = folderKey + "/";
            for (uint i = 0; i < g_MlBrowserEntries.Length; ++i) {
                auto entry = g_MlBrowserEntries[i];
                if (entry is null) continue;
                string relPath = "";
                if (!_MlBrowserTryGetNadeoRelPath(entry.url, relPath)) continue;
                if (relPath == folderKey || relPath.StartsWith(folderPrefix)) {
                    entries.InsertLast(entry);
                }
            }
        }

        string _MlBrowserEntryLabel(const MlBrowserEntry@ entry) {
            if (entry is null) return "(null)";
            string url = entry.url;
            if (url.StartsWith("file://")) url = url.SubStr(7);
            url = url.Replace("\\", "/");
            int slash = url.LastIndexOf("/");
            if (slash >= 0 && slash + 1 < int(url.Length)) return url.SubStr(slash + 1);
            return url;
        }

    }
}
