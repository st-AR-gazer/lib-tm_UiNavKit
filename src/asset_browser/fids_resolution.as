namespace UiNavKit {
    namespace AssetBrowser {

        bool _MlBrowserIsMediaManialinksUrl(const string &in rawUrl) {
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return false;
            return url.StartsWith("file://Media/Manialinks/");
        }

        string _MlBrowserStorageBmpPathForRaw(const string &in rawPath) {
            string p = rawPath.Trim();
            if (p.Length > 4 && p.ToLower().EndsWith(".dds")) return p.SubStr(0, p.Length - 4) + ".bmp";
            return p + ".bmp";
        }

        bool _MlBrowserIsValidFid(CSystemFidFile@ fid) {
            if (fid is null) return false;
            try {
                return string(fid.TimeWrite) != "?";
            } catch {
                _MlBrowserLog("Fid.TimeWrite unavailable; falling back to ByteSize.");
            }
            try {
                return fid.ByteSize > 0;
            } catch {
                return true;
            }
        }

        string _MlBrowserFidDebugMeta(CSystemFidFile@ fid) {
            if (fid is null) return "fid=null";
            string tw = "?";
            uint size = 0;
            string fn = "";
            try {
                tw = string(fid.TimeWrite);
            } catch {
                tw = "?";
            }
            try {
                size = fid.ByteSize;
            } catch {
                size = 0;
            }
            try {
                fn = string(fid.FileName);
            } catch {
                fn = "";
            }
            return "TimeWrite=" + tw + ", ByteSize=" + size + ", FileName=" + fn;
        }

        bool _MlBrowserCanUseFidExtract() {
            bool canExtract = false;
            try {
                canExtract = OpenplanetHasFullPermissions();
            } catch {
                canExtract = false;
            }
            return canExtract;
        }

        string _MlBrowserDataExtractRelPathForUrl(const string &in url) {
            string rel = _MlBrowserStorageRelPathForUrl(url);
            if (!_MlBrowserPathHasExt(rel)) rel += _MlBrowserExtFromPath(url);
            return "Extract/Titles/Trackmania/Media/Manialinks/" + rel;
        }

        void _MlBrowserAddFidSourceCandidates(
            array<string> &inout srcCandidates,
            CSystemFidFile@ fid,
            const string &in fidKey
        ) {
            if (fid is null) return;

            string full = "";
            try {
                full = Fids::GetFullPath(fid);
            } catch {
                full = "";
            }
            if (full.Length > 0) _MlBrowserAddCandidateAnyPath(srcCandidates, full);

            string fullFileName = "";
            try {
                fullFileName = string(fid.FullFileName);
            } catch {
                fullFileName = "";
            }
            fullFileName = fullFileName.Replace("\\", "/").Trim();
            if (fullFileName.StartsWith("file://")) fullFileName = fullFileName.SubStr(7);
            if (fullFileName.Length > 0) _MlBrowserAddCandidateAnyPath(srcCandidates, fullFileName);

            string fileName = "";
            try {
                fileName = string(fid.FileName);
            } catch {
                fileName = "";
            }
            fileName = fileName.Replace("\\", "/").Trim();
            if (fileName.StartsWith("file://")) fileName = fileName.SubStr(7);
            if (fileName.Length > 0) {
                _MlBrowserAddCandidateAnyPath(srcCandidates, fileName);
                _MlBrowserAddCandidateAnyPath(srcCandidates, "GameData/" + fileName);
            }

            _MlBrowserAddCandidateAnyPath(srcCandidates, fidKey);
            if (!fidKey.StartsWith("GameData/")) _MlBrowserAddCandidateAnyPath(srcCandidates, "GameData/" + fidKey);
        }

        bool _MlBrowserTryStageFromFid(
            CSystemFidFile@ fid,
            const string &in fidKey,
            const string &in url,
            string &out stagedRawPath
        ) {
            stagedRawPath = "";
            if (fid is null) return false;
            array<string> srcCandidates;
            _MlBrowserAddFidSourceCandidates(srcCandidates, fid, fidKey);
            _MlBrowserAddExtractPathCandidates(srcCandidates, fidKey, url);

            array<string> relExtractAttempts;
            array<string> absExtractAttempts;
            _MlBrowserBuildExtractPathAttempts(fidKey, url, relExtractAttempts, absExtractAttempts);
            for (uint i = 0; i < relExtractAttempts.Length; ++i) {
                string relExtract = relExtractAttempts[i];
                string absExtract = i < absExtractAttempts.Length ? absExtractAttempts[i] : IO::FromDataFolder(relExtract);
                bool copiedRel = false;
                try {
                    string outFolder = Path::GetDirectoryName(absExtract);
                    if (outFolder.Length > 0 && !IO::FolderExists(outFolder)) IO::CreateFolder(outFolder, true);
                    fid.CopyToFileRelative(relExtract, false);
                    copiedRel = IO::FileExists(absExtract) && IO::FileSize(absExtract) > 0;
                } catch {
                    copiedRel = false;
                }
                _MlBrowserLog("fid.CopyToFileRelative(" + relExtract + ") => " + (copiedRel ? "true" : "false"));
                if (!copiedRel) continue;

                string staged = _MlBrowserStageFileForPreview(absExtract, url);
                if (staged.Length > 0 && IO::FileExists(staged)) {
                    stagedRawPath = staged;
                    _MlBrowserLog("Staged media URL to storage via CopyToFileRelative: " + stagedRawPath);
                    return true;
                }
                _MlBrowserAddUniquePath(srcCandidates, absExtract);
            }

            bool extracted = false;
            bool validFid = _MlBrowserIsValidFid(fid);
            if (!validFid) {
                _MlBrowserLog("Skipping Fids::Extract on invalid fid: " + fidKey + " | " + _MlBrowserFidDebugMeta(fid));
            } else if (!_MlBrowserCanUseFidExtract()) {
                _MlBrowserLog("Skipping Fids::Extract (OpenplanetHasFullPermissions=false): " + fidKey);
            } else {
                try {
                    extracted = Fids::Extract(fid, false);
                } catch {
                    extracted = false;
                }
                _MlBrowserLog("Fids::Extract(" + fidKey + ", false) => " + (extracted ? "true" : "false"));
            }
            if (extracted) {
                _MlBrowserAddFidSourceCandidates(srcCandidates, fid, fidKey);
                _MlBrowserAddExtractPathCandidates(srcCandidates, fidKey, url);
            }

            for (uint i = 0; i < srcCandidates.Length; ++i) {
                string src = srcCandidates[i];
                if (src.Length == 0 || !IO::FileExists(src)) continue;
                string staged = _MlBrowserStageFileForPreview(src, url);
                if (staged.Length == 0 || !IO::FileExists(staged)) continue;
                stagedRawPath = staged;
                _MlBrowserLog("Staged media URL to storage: " + stagedRawPath);
                return true;
            }
            if (extracted) {
                _MlBrowserWarn("Extract succeeded but no readable source candidate was found: " + fidKey);
                if (S_MlBrowserVerboseLogs) {
                    uint maxDump = Math::Min(srcCandidates.Length, 12);
                    for (uint i = 0; i < maxDump; ++i) {
                        string src = srcCandidates[i];
                        bool exists = src.Length > 0 && IO::FileExists(src);
                        _MlBrowserLog("  post-extract candidate[" + i + "] exists=" + (exists ? "true" : "false") + " :: " + src);
                    }
                }
            }
            return false;
        }

        bool _MlBrowserTryStageMediaWithGetFlow(const string &in key, const string &in url, string &out stagedRawPath) {
            stagedRawPath = "";
            string path = key.Trim().Replace("\\", "/");
            while (path.StartsWith("/")) path = path.SubStr(1);
            if (path.Length == 0) return false;

            array<string> gameKeys;
            if (!path.StartsWith("GameData/")) gameKeys.InsertLast("GameData/" + path);
            gameKeys.InsertLast(path);

            for (uint i = 0; i < gameKeys.Length; ++i) {
                string gameKey = gameKeys[i];
                CSystemFidFile@ fid = null;
                try {
                    @fid = Fids::GetGame(gameKey);
                } catch {
                    @fid = null;
                }
                if (fid is null) {
                    _MlBrowserLog("GetGame miss: " + gameKey);
                    continue;
                }
                _MlBrowserLog("GetGame hit: " + gameKey + " | valid=" + (_MlBrowserIsValidFid(fid) ? "true" : "false") + " | " + _MlBrowserFidDebugMeta(fid));
                if (_MlBrowserTryStageFromFid(fid, gameKey, url, stagedRawPath)) return true;
            }
            {
                array<string> fakeKeys;
                if (!path.StartsWith("Titles/Trackmania/")) fakeKeys.InsertLast("Titles/Trackmania/" + path);
                fakeKeys.InsertLast(path);
                for (uint i = 0; i < fakeKeys.Length; ++i) {
                    string fakeKey = fakeKeys[i];
                    CSystemFidFile@ fid = null;
                    try {
                        @fid = Fids::GetFake(fakeKey);
                    } catch {
                        @fid = null;
                    }
                    if (fid is null) {
                        _MlBrowserLog("GetFake miss: " + fakeKey);
                        continue;
                    }
                    _MlBrowserLog("GetFake hit: " + fakeKey + " | valid=" + (_MlBrowserIsValidFid(fid) ? "true" : "false") + " | " + _MlBrowserFidDebugMeta(fid));
                    if (_MlBrowserTryStageFromFid(fid, fakeKey, url, stagedRawPath)) return true;
                }
            }
            {
                CSystemFidFile@ fid = null;
                try {
                    @fid = Fids::GetProgramData(path);
                } catch {
                    @fid = null;
                }
                if (fid !is null) {
                    _MlBrowserLog("GetProgramData hit: " + path + " | valid=" + (_MlBrowserIsValidFid(fid) ? "true" : "false") + " | " + _MlBrowserFidDebugMeta(fid));
                    if (_MlBrowserTryStageFromFid(fid, path, url, stagedRawPath)) return true;
                } else {
                    _MlBrowserLog("GetProgramData miss: " + path);
                }
            }
            {
                CSystemFidFile@ fid = null;
                try {
                    @fid = Fids::GetResource(path);
                } catch {
                    @fid = null;
                }
                if (fid !is null) {
                    _MlBrowserLog("GetResource hit: " + path + " | valid=" + (_MlBrowserIsValidFid(fid) ? "true" : "false") + " | " + _MlBrowserFidDebugMeta(fid));
                    if (_MlBrowserTryStageFromFid(fid, path, url, stagedRawPath)) return true;
                } else {
                    _MlBrowserLog("GetResource miss: " + path);
                }
            }
            {
                CSystemFidFile@ fid = null;
                try {
                    @fid = Fids::GetUser(path);
                } catch {
                    @fid = null;
                }
                if (fid !is null) {
                    _MlBrowserLog("GetUser hit: " + path + " | valid=" + (_MlBrowserIsValidFid(fid) ? "true" : "false") + " | " + _MlBrowserFidDebugMeta(fid));
                    if (_MlBrowserTryStageFromFid(fid, path, url, stagedRawPath)) return true;
                } else {
                    _MlBrowserLog("GetUser miss: " + path);
                }
            }

            return false;
        }

    }
}
