namespace UiNavKit {
    namespace AssetBrowser {

        int _MlBrowserCollectFromLayerXml(dictionary &inout seen) {
            int addedBefore = int(g_MlBrowserEntries.Length);
            const int kTimeBudgetMs = 120;
            const int kMaxCharsPerLayer = 350000;
            uint startMs = Time::Now;
            bool timeBudgetHit = false;
            bool xmlCapped = false;

            for (int appKind = 0; appKind <= 2; ++appKind) {
                uint len = _GetMlLayerCount(appKind);
                for (uint i = 0; i < len; ++i) {
                    if (int(Time::Now - startMs) > kTimeBudgetMs) {
                        timeBudgetHit = true;
                        break;
                    }
                    auto layer = _GetMlLayerByIx(appKind, int(i));
                    if (layer is null) continue;
                    string xml = "";
                    try {
                        xml = layer.ManialinkPageUtf8;
                    } catch {
                        xml = "";
                    }
                    if (xml.Length == 0) {
                        try {
                            xml = "" + layer.ManialinkPage;
                        } catch {
                            xml = "";
                        }
                    }
                    if (xml.Length == 0) continue;
                    if (xml.Length > uint(kMaxCharsPerLayer)) {
                        xml = xml.SubStr(0, kMaxCharsPerLayer);
                        xmlCapped = true;
                    }

                    string source = _MlAppNameByKind(appKind) + " L[" + i + "]";
                    _MlBrowserExtractXmlAttrUrls(xml, "image", source, seen);
                    _MlBrowserExtractXmlAttrUrls(xml, "imagefocus", source, seen);
                    _MlBrowserExtractXmlAttrUrls(xml, "alphamask", source, seen);
                }
                if (timeBudgetHit) break;
            }

            if (timeBudgetHit || xmlCapped) {
                string suffix = "";
                if (timeBudgetHit) suffix += " live scan budget hit";
                if (xmlCapped) {
                    if (suffix.Length > 0) suffix += ";";
                    suffix += " XML clipped per layer";
                }
                if (suffix.Length > 0) g_MlBrowserStatus = suffix + ".";
            }

            return int(g_MlBrowserEntries.Length) - addedBefore;
        }

        string _MlBrowserFsPathToUrl(const string &in fsPath) {
            string p = fsPath.Replace("\\", "/");
            string lower = p.ToLower();
            int mediaIx = lower.IndexOf("media/manialinks/");
            if (mediaIx >= 0) {
                string tail = p.SubStr(mediaIx + 17);
                return "file://Media/Manialinks/" + tail;
            }
            return "file://" + p;
        }

        int _MlBrowserCollectFromFilesystem(
            const string &in rootPath,
            bool recursive,
            int maxFiles,
            dictionary &inout seen
        ) {
            string root = rootPath.Trim();
            if (root.Length == 0 || !IO::FolderExists(root)) return 0;
            if (maxFiles < 1) maxFiles = 1;

            array<string> @files = IO::IndexFolder(root, recursive);
            if (files is null || files.Length == 0) return 0;

            int addedBefore = int(g_MlBrowserEntries.Length);
            int scanned = 0;
            for (uint i = 0; i < files.Length; ++i) {
                if (scanned >= maxFiles) break;
                string path = files[i];
                string lower = path.ToLower();
                if (!_MlBrowserHasAllowedExt(lower)) continue;
                scanned++;
                _MlBrowserAddEntry(seen, _MlBrowserFsPathToUrl(path), "Filesystem", "file");
            }
            return int(g_MlBrowserEntries.Length) - addedBefore;
        }

        bool _MlBrowserFidsScanShouldStop(MlBrowserFidsScanState@ state) {
            if (state is null) return true;
            if (state.remaining <= 0) {
                state.capped = true;
                return true;
            }
            if (state.timeBudgetMs > 0 && (Time::Now - state.startedAtMs) > state.timeBudgetMs) {
                state.timedOut = true;
                return true;
            }
            return false;
        }

        string _MlBrowserFidsFolderName(CSystemFidsFolder@ folder) {
            if (folder is null) return "";
            string name = "";
            try {
                name = string(folder.DirName);
            } catch {
                name = "";
            }
            if (name.Length == 0) {
                try {
                    name = string(folder.FullDirName);
                } catch {
                    name = "";
                }
            }
            name = _MlBrowserCollapseSlashes(name.Replace("\\", "/").Trim());
            while (name.EndsWith("/")) name = name.SubStr(0, name.Length - 1);
            int slash = name.LastIndexOf("/");
            if (slash >= 0 && slash + 1 < int(name.Length)) name = name.SubStr(slash + 1);
            return name.Trim();
        }

        void _MlBrowserCollectFidsNadeoFolderRec(
            CSystemFidsFolder@ folder,
            const string &in relPrefix,
            const string &in source,
            dictionary &inout seen,
            MlBrowserFidsScanState@ state
        ) {
            if (folder is null || _MlBrowserFidsScanShouldStop(state)) return;

            uint leafLen = 0;
            try {
                leafLen = folder.Leaves.Length;
            } catch {
                leafLen = 0;
            }
            for (uint i = 0; i < leafLen; ++i) {
                if (_MlBrowserFidsScanShouldStop(state)) return;
                CSystemFidFile@ leaf = null;
                try {
                    @leaf = folder.Leaves[i];
                } catch {
                    @leaf = null;
                }
                if (leaf is null) continue;

                string fileName = "";
                try {
                    fileName = string(leaf.FileName);
                } catch {
                    fileName = "";
                }
                if (fileName.Length == 0) continue;
                string lower = fileName.ToLower();
                if (!_MlBrowserHasAllowedExt(lower)) continue;

                string rel = relPrefix.Length > 0 ? relPrefix + "/" + fileName : fileName;
                rel = _MlBrowserCollapseSlashes(rel);
                while (rel.StartsWith("/")) rel = rel.SubStr(1);
                if (rel.Length == 0) continue;

                _MlBrowserAddEntry(seen, "file://Media/Manialinks/Nadeo/" + rel, source, "fid-tree");
                state.remaining--;
            }

            uint treeLen = 0;
            try {
                treeLen = folder.Trees.Length;
            } catch {
                treeLen = 0;
            }
            for (uint i = 0; i < treeLen; ++i) {
                if (_MlBrowserFidsScanShouldStop(state)) return;
                CSystemFidsFolder@ child = null;
                try {
                    @child = folder.Trees[i];
                } catch {
                    @child = null;
                }
                if (child is null) continue;

                string childName = _MlBrowserFidsFolderName(child);
                if (childName.Length == 0) continue;
                string childRel = relPrefix.Length > 0 ? relPrefix + "/" + childName : childName;
                childRel = _MlBrowserCollapseSlashes(childRel);
                _MlBrowserCollectFidsNadeoFolderRec(child, childRel, source, seen, state);
            }
        }

        bool _MlBrowserCollectNadeoFidsRoot(
            CSystemFidsFolder@ root,
            const string &in source,
            dictionary &inout seen,
            MlBrowserFidsScanState@ state
        ) {
            if (root is null || state is null) return false;
            try {
                Fids::UpdateTree(root, true);
            } catch {
                _MlBrowserLog("Fids::UpdateTree failed for source: " + source);
            }
            _MlBrowserCollectFidsNadeoFolderRec(root, "", source, seen, state);
            return true;
        }

        int _MlBrowserCollectFromNadeoFidsTree(dictionary &inout seen, string &out note) {
            note = "";
            int addedBefore = int(g_MlBrowserEntries.Length);

            MlBrowserFidsScanState@ state = MlBrowserFidsScanState();
            state.remaining = S_MlBrowserMaxNadeoFidsFiles;
            if (state.remaining < 1) state.remaining = 1;
            state.timeBudgetMs = 650;
            state.startedAtMs = Time::Now;

            bool gotAnyRoot = false;
            {
                CSystemFidsFolder@ root = null;
                try {
                    @root = Fids::GetFakeFolder("Titles/Trackmania/Media/Manialinks/Nadeo");
                } catch {
                    @root = null;
                }
                gotAnyRoot = _MlBrowserCollectNadeoFidsRoot(
                    root,
                    "Fids Fake: Titles/Trackmania/Media/Manialinks/Nadeo",
                    seen,
                    state
                ) || gotAnyRoot;
            }
            {
                CSystemFidsFolder@ root = null;
                try {
                    @root = Fids::GetGameFolder("Media/Manialinks/Nadeo");
                } catch {
                    @root = null;
                }
                gotAnyRoot = _MlBrowserCollectNadeoFidsRoot(
                    root,
                    "Fids Game: Media/Manialinks/Nadeo",
                    seen,
                    state
                ) || gotAnyRoot;
            }
            {
                CSystemFidsFolder@ root = null;
                try {
                    @root = Fids::GetResourceFolder("Media/Manialinks/Nadeo");
                } catch {
                    @root = null;
                }
                gotAnyRoot = _MlBrowserCollectNadeoFidsRoot(
                    root,
                    "Fids Resource: Media/Manialinks/Nadeo",
                    seen,
                    state
                ) || gotAnyRoot;
            }
            {
                CSystemFidsFolder@ root = null;
                try {
                    @root = Fids::GetProgramDataFolder("Media/Manialinks/Nadeo");
                } catch {
                    @root = null;
                }
                gotAnyRoot = _MlBrowserCollectNadeoFidsRoot(
                    root,
                    "Fids ProgramData: Media/Manialinks/Nadeo",
                    seen,
                    state
                ) || gotAnyRoot;
            }
            {
                CSystemFidsFolder@ root = null;
                try {
                    @root = Fids::GetUserFolder("Media/Manialinks/Nadeo");
                } catch {
                    @root = null;
                }
                gotAnyRoot = _MlBrowserCollectNadeoFidsRoot(
                    root,
                    "Fids User: Media/Manialinks/Nadeo",
                    seen,
                    state
                ) || gotAnyRoot;
            }

            if (!gotAnyRoot) {
                note = "No Fids roots found for Media/Manialinks/Nadeo.";
            } else if (state.capped) {
                note = "Nadeo Fids scan hit max files cap (" + S_MlBrowserMaxNadeoFidsFiles + ").";
            } else if (state.timedOut) {
                note = "Nadeo Fids scan hit time budget; click Refresh again or narrow scope.";
            }

            return int(g_MlBrowserEntries.Length) - addedBefore;
        }

        void _MlBrowserRefresh() {
            g_MlBrowserEntries.Resize(0);
            g_MlBrowserStatus = "";
            dictionary seen;

            int addedLive = 0;
            int addedFs = 0;
            int addedNadeoFids = 0;
            string fidsNote = "";

            if (S_MlBrowserIncludeLiveLayers) addedLive = _MlBrowserCollectFromLayerXml(seen);
            if (S_MlBrowserIncludeNadeoFidsTree) addedNadeoFids = _MlBrowserCollectFromNadeoFidsTree(seen, fidsNote);
            if (S_MlBrowserIncludeFilesystem) addedFs = _MlBrowserCollectFromFilesystem(
                S_MlBrowserAssetsRoot,
                S_MlBrowserRecursive,
                S_MlBrowserMaxFiles,
                seen
            );

            g_MlBrowserLastRefreshMs = Time::Now;
            string suffix = g_MlBrowserStatus;
            if (fidsNote.Length > 0) {
                if (suffix.Length > 0) suffix += " ";
                suffix += fidsNote;
            }
            g_MlBrowserStatus = "Loaded " + g_MlBrowserEntries.Length + " URLs (live=" + addedLive + ", fids=" + addedNadeoFids + ", fs=" + addedFs + ").";
            if (suffix.Length > 0) g_MlBrowserStatus += " " + suffix;
            _MlBrowserInvalidateTreeCache();
            _MlBrowserInvalidateThumbCache();
            g_MlBrowserHistory.Resize(0);
            _MlBrowserClearFolderSelection();
            _MlBrowserResetPreview();
        }

    }
}
