namespace UiNavKit {
    namespace AssetBrowser {

        void _MlBrowserAddLoadCandidate(array<string> &inout outPaths, const string &in rawPath) {
            string p = rawPath.Trim();
            if (p.Length == 0) return;
            for (uint i = 0; i < outPaths.Length; ++i) {
                if (outPaths[i] == p) return;
            }
            outPaths.InsertLast(p);
        }

        string _MlBrowserExtFromPath(const string &in rawPath) {
            string path = rawPath.Trim().ToLower();
            int slash = path.LastIndexOf("/");
            int dot = path.LastIndexOf(".");
            if (dot >= 0 && dot > slash) return path.SubStr(dot);
            return ".dds";
        }

        string _MlBrowserStorageRoot() {
            return IO::FromStorageFolder("Media/Manialinks");
        }

        bool _MlBrowserIsAbsolutePath(const string &in rawPath) {
            string p = rawPath.Trim();
            if (p.Length < 1) return false;
            if (p.StartsWith("/") || p.StartsWith("\\")) return true;
            if (p.Length >= 3 && p.SubStr(1, 1) == ":" && (p.SubStr(2, 1) == "/" || p.SubStr(2, 1) == "\\")) return true;
            return false;
        }

        string _MlBrowserOpenplanetRoot() {
            string storageRoot = IO::FromStorageFolder("").Replace("\\", "/");
            while (storageRoot.EndsWith("/")) storageRoot = storageRoot.SubStr(0, storageRoot.Length - 1);
            if (storageRoot.Length == 0) return "";
            string pluginStorage = Path::GetDirectoryName(storageRoot).Replace("\\", "/");
            if (pluginStorage.Length == 0) return "";
            string opRoot = Path::GetDirectoryName(pluginStorage).Replace("\\", "/");
            return opRoot;
        }

        string _MlBrowserBaseName(const string &in rawPath) {
            string p = rawPath.Replace("\\", "/");
            int slash = p.LastIndexOf("/");
            if (slash < 0 || slash + 1 >= int(p.Length)) return p;
            return p.SubStr(slash + 1);
        }

        void _MlBrowserAddRelativeCandidates(array<string> &inout outPaths, const string &in relPath) {
            string rel = relPath.Trim().Replace("\\", "/");
            if (rel.Length == 0) return;
            _MlBrowserAddUniquePath(outPaths, rel);
            _MlBrowserAddUniquePath(outPaths, IO::FromAppFolder(rel));
            _MlBrowserAddUniquePath(outPaths, IO::FromUserGameFolder(rel));

            string opRoot = _MlBrowserOpenplanetRoot();
            if (opRoot.Length > 0) {
                _MlBrowserAddUniquePath(outPaths, opRoot + "/" + rel);
                string leaf = _MlBrowserBaseName(rel);
                if (leaf.Length > 0) _MlBrowserAddUniquePath(outPaths, opRoot + "/" + leaf);
            }
        }

        void _MlBrowserAddCandidateAnyPath(array<string> &inout outPaths, const string &in rawPath) {
            string p = rawPath.Trim().Replace("\\", "/");
            if (p.Length == 0) return;
            if (_MlBrowserIsAbsolutePath(p)) {
                _MlBrowserAddUniquePath(outPaths, p);
                return;
            }
            _MlBrowserAddRelativeCandidates(outPaths, p);
        }

        string _MlBrowserNormalizeExtractKey(const string &in rawKey, const string &in url) {
            string key = _MlBrowserCollapseSlashes(rawKey.Trim().Replace("\\", "/"));
            while (key.StartsWith("/")) key = key.SubStr(1);
            if (key.StartsWith("GameData/")) key = key.SubStr(9);
            if (key.StartsWith("Media/")) key = "Titles/Trackmania/" + key;
            if (!_MlBrowserPathHasExt(key)) key += _MlBrowserExtFromPath(url);
            return key;
        }

        void _MlBrowserBuildExtractPathAttempts(
            const string &in fidKey,
            const string &in url,
            array<string> &out relAttempts,
            array<string> &out absAttempts
        ) {
            relAttempts.Resize(0);
            absAttempts.Resize(0);

            string canonical = _MlBrowserNormalizeExtractKey(fidKey, url);
            if (canonical.Length > 0) {
                _MlBrowserAddUniquePath(relAttempts, "Extract/" + canonical);
                const string kTitlePrefix = "Titles/Trackmania/";
                if (canonical.StartsWith(kTitlePrefix)) {
                    _MlBrowserAddUniquePath(relAttempts, "Extract/" + canonical.SubStr(kTitlePrefix.Length));
                }
            }

            string relFromUrl = _MlBrowserStorageRelPathForUrl(url);
            if (relFromUrl.Length > 0) {
                if (!_MlBrowserPathHasExt(relFromUrl)) relFromUrl += _MlBrowserExtFromPath(url);
                _MlBrowserAddUniquePath(relAttempts, "Extract/Titles/Trackmania/Media/Manialinks/" + relFromUrl);
            }

            string leaf = _MlBrowserBaseName(fidKey);
            if (leaf.Length > 0) _MlBrowserAddUniquePath(relAttempts, "Extract/" + leaf);

            for (uint i = 0; i < relAttempts.Length; ++i) {
                _MlBrowserAddUniquePath(absAttempts, IO::FromDataFolder(relAttempts[i]));
            }
        }

        void _MlBrowserAddExtractPathCandidates(
            array<string> &inout srcCandidates,
            const string &in fidKey,
            const string &in url
        ) {
            array<string> relAttempts;
            array<string> absAttempts;
            _MlBrowserBuildExtractPathAttempts(fidKey, url, relAttempts, absAttempts);
            for (uint i = 0; i < absAttempts.Length; ++i) {
                _MlBrowserAddUniquePath(srcCandidates, absAttempts[i]);
            }
        }

        string _MlBrowserCollapseSlashes(const string &in rawPath) {
            string p = rawPath.Replace("\\", "/");
            while (p.IndexOf("//") >= 0) p = p.Replace("//", "/");
            return p;
        }

        bool _MlBrowserPathHasExt(const string &in rawPath) {
            string p = rawPath.Trim();
            int slash = p.LastIndexOf("/");
            int dot = p.LastIndexOf(".");
            return dot >= 0 && dot > slash;
        }

        string _MlBrowserStorageRelPathForUrl(const string &in rawUrl) {
            string url = _MlBrowserNormalizeUrl(rawUrl);
            string p = url;
            if (p.StartsWith("file://")) p = p.SubStr(7);
            p = _MlBrowserCollapseSlashes(p.Trim());
            while (p.StartsWith("/")) p = p.SubStr(1);
            if (p.StartsWith("Media/Manialinks/")) p = p.SubStr(17);
            if (p.Length == 0) p = "_unknown/" + Crypto::MD5(url);
            return p;
        }

        string _MlBrowserStoragePathForUrl(const string &in rawUrl, const string &in extHintPath = "") {
            string rel = _MlBrowserStorageRelPathForUrl(rawUrl);
            if (!_MlBrowserPathHasExt(rel)) {
                string ext = _MlBrowserExtFromPath(extHintPath.Length > 0 ? extHintPath : rawUrl);
                rel += ext;
            }
            return _MlBrowserStorageRoot() + "/" + rel;
        }

        string _MlBrowserDecodedBmpCachePath(const string &in key) {
            string hash = Crypto::MD5(key);
            return _MlBrowserStorageRoot() + "/_decoded/" + hash + ".bmp";
        }

        bool _MlBrowserWriteBufferToFile(const string &in outPath, MemoryBuffer@ buffer) {
            if (buffer is null || buffer.GetSize() == 0) return false;
            string path = outPath.Trim();
            if (path.Length == 0) return false;
            try {
                string folder = Path::GetDirectoryName(path);
                if (folder.Length > 0 && !IO::FolderExists(folder)) IO::CreateFolder(folder, true);
                IO::File f;
                f.Open(path, IO::FileMode::Write);
                f.Write(buffer);
                f.Close();
                return IO::FileExists(path) && IO::FileSize(path) > 0;
            } catch {
                return false;
            }
        }

        string _MlBrowserStageFileForPreview(const string &in sourcePath, const string &in url) {
            string src = sourcePath.Trim();
            if (src.Length == 0) return "";
            if (!IO::FileExists(src)) return "";
            string dst = _MlBrowserStoragePathForUrl(url, src);
            try {
                string folder = Path::GetDirectoryName(dst);
                if (folder.Length > 0 && !IO::FolderExists(folder)) IO::CreateFolder(folder, true);
            } catch {
                _MlBrowserWarn("Could not ensure staging folder for: " + dst);
            }
            bool sameSize = false;
            try {
                if (IO::FileExists(dst)) sameSize = IO::FileSize(dst) == IO::FileSize(src);
            } catch {
                sameSize = false;
            }
            if (sameSize) return dst;
            try {
                if (IO::FileExists(dst)) IO::Delete(dst);
                IO::Copy(src, dst);
            } catch {
                _MlBrowserWarn("Could not stage image into storage: " + src + " -> " + dst);
            }
            if (IO::FileExists(dst)) return dst;
            return "";
        }

        bool _MlBrowserTrySetResolvedPath(const string &in candidate, const string &in url, string &out diskPath) {
            string c = candidate.Trim();
            if (c.Length == 0) return false;
            if (!IO::FileExists(c)) return false;
            string stagedPath = _MlBrowserStageFileForPreview(c, url);
            if (stagedPath.Length == 0) return false;
            g_MlBrowserResolvedPathCache.Set(url, stagedPath);
            diskPath = stagedPath;
            _MlBrowserLog("Resolved internal URL to file: " + diskPath);
            return true;
        }

        void _MlBrowserAddUniquePath(array<string> &inout paths, const string &in rawPath) {
            string p = rawPath.Trim();
            if (p.Length == 0) return;
            for (uint i = 0; i < paths.Length; ++i) {
                if (paths[i] == p) return;
            }
            paths.InsertLast(p);
        }

        void _MlBrowserAddFidKeyVariants(array<string> &inout keys, const string &in rawPath) {
            string p = rawPath.Trim().Replace("\\", "/");
            while (p.StartsWith("/")) p = p.SubStr(1);
            if (p.Length == 0) return;

            _MlBrowserAddUniquePath(keys, p);
            _MlBrowserAddUniquePath(keys, p.Replace("/", "\\"));

            if (!p.StartsWith("GameData/")) {
                string gd = "GameData/" + p;
                _MlBrowserAddUniquePath(keys, gd);
                _MlBrowserAddUniquePath(keys, gd.Replace("/", "\\"));
            } else if (p.Length > 9) {
                string noGd = p.SubStr(9);
                _MlBrowserAddUniquePath(keys, noGd);
                _MlBrowserAddUniquePath(keys, noGd.Replace("/", "\\"));
            }
        }

        bool _MlBrowserTryExtractFidToDisk(
            CSystemFidFile@ fid,
            const string &in fidKey,
            const string &in url,
            string &out diskPath
        ) {
            if (fid is null) return false;
            bool extracted = false;
            try {
                extracted = Fids::Extract(fid, false);
            } catch {
                extracted = false;
            }
            _MlBrowserLog("Fids::Extract(" + fidKey + ", false) => " + (extracted ? "true" : "false"));
            if (!extracted) return false;

            string full = "";
            try {
                full = Fids::GetFullPath(fid);
            } catch {
                full = "";
            }
            full = full.Trim().Replace("\\", "/");
            if (_MlBrowserTrySetResolvedPath(full, url, diskPath)) return true;

            if (_MlBrowserTrySetResolvedPath(IO::FromAppFolder(fidKey), url, diskPath)) return true;
            if (!fidKey.StartsWith("GameData/")) {
                if (_MlBrowserTrySetResolvedPath(IO::FromAppFolder("GameData/" + fidKey), url, diskPath)) return true;
            }
            if (_MlBrowserTrySetResolvedPath(IO::FromUserGameFolder(fidKey), url, diskPath)) return true;

            return false;
        }

        bool _MlBrowserTryResolveFromFid(
            CSystemFidFile@ fid,
            const string &in fidKey,
            const string &in url,
            string &out diskPath
        ) {
            if (fid is null) return false;

            string full = "";
            try {
                full = Fids::GetFullPath(fid);
            } catch {
                full = "";
            }
            full = full.Trim().Replace("\\", "/");
            if (_MlBrowserTrySetResolvedPath(full, url, diskPath)) return true;

            bool exists = false;
            try {
                exists = fid.OSCheckIfExists();
            } catch {
                exists = false;
            }
            _MlBrowserLog("Fid OSCheckIfExists(" + fidKey + ") => " + (exists ? "true" : "false"));

            if (_MlBrowserTryExtractFidToDisk(fid, fidKey, url, diskPath)) return true;

            if (_MlBrowserTrySetResolvedPath(IO::FromAppFolder(fidKey), url, diskPath)) return true;
            if (!fidKey.StartsWith("GameData/")) {
                if (_MlBrowserTrySetResolvedPath(IO::FromAppFolder("GameData/" + fidKey), url, diskPath)) return true;
            }
            if (_MlBrowserTrySetResolvedPath(IO::FromUserGameFolder(fidKey), url, diskPath)) return true;

            return false;
        }

        bool _MlBrowserTryResolveViaFidKeys(
            const array<string> &in fidKeys,
            const string &in url,
            string &out diskPath
        ) {
            for (uint k = 0; k < fidKeys.Length; ++k) {
                string key = fidKeys[k];
                _MlBrowserLog("Trying fid key: " + key);

                CSystemFidFile@ gameFid = null;
                CSystemFidFile@ resourceFid = null;
                CSystemFidFile@ userFid = null;
                try {
                    @gameFid = Fids::GetGame(key);
                } catch {
                    @gameFid = null;
                }
                try {
                    @resourceFid = Fids::GetResource(key);
                } catch {
                    @resourceFid = null;
                }
                try {
                    @userFid = Fids::GetUser(key);
                } catch {
                    @userFid = null;
                }

                if (gameFid !is null) {
                    _MlBrowserLog("  found fid on Game drive");
                    if (_MlBrowserTryResolveFromFid(gameFid, key, url, diskPath)) return true;
                }
                if (resourceFid !is null) {
                    _MlBrowserLog("  found fid on Resource drive");
                    if (_MlBrowserTryResolveFromFid(resourceFid, key, url, diskPath)) return true;
                }
                if (userFid !is null) {
                    _MlBrowserLog("  found fid on User drive");
                    if (_MlBrowserTryResolveFromFid(userFid, key, url, diskPath)) return true;
                }
            }
            return false;
        }

        bool _MlBrowserTryResolveInternalToDisk(const string &in rawUrl, string &out diskPath) {
            diskPath = "";
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return false;

            string cached = "";
            if (g_MlBrowserResolvedPathCache.Get(url, cached)) {
                if (cached.Length > 0 && IO::FileExists(cached)) {
                    diskPath = cached;
                    _MlBrowserLog("Using cached resolved file: " + diskPath);
                    return true;
                }
            }

            string path = url;
            if (path.StartsWith("file://")) path = path.SubStr(7);
            path = path.Trim().Replace("\\", "/");
            if (path.Length == 0) return false;

            if (_MlBrowserTrySetResolvedPath(path, url, diskPath)) return true;
            if (_MlBrowserTrySetResolvedPath(IO::FromAppFolder(path), url, diskPath)) return true;
            if (_MlBrowserTrySetResolvedPath(IO::FromAppFolder("GameData/" + path), url, diskPath)) return true;
            if (_MlBrowserTrySetResolvedPath(IO::FromUserGameFolder(path), url, diskPath)) return true;

            if (S_MlBrowserUseFidsResolution) {
                array<string> fidKeys;
                _MlBrowserAddFidKeyVariants(fidKeys, path);
                if (_MlBrowserTryResolveViaFidKeys(fidKeys, url, diskPath)) return true;
            } else {
                _MlBrowserLog("Fids resolution disabled; skipping Fids drive lookup.");
            }

            _MlBrowserWarn("Failed to resolve URL to disk path: " + url);
            g_MlBrowserResolvedPathCache.Set(url, "");
            return false;
        }

        bool _MlBrowserTryLoadTextureFromBuffer(const string &in filePath, UI::Texture@&out texture) {
            @texture = null;
            string path = filePath.Trim();
            if (path.Length == 0 || !IO::FileExists(path)) return false;
            try {
                IO::File f;
                f.Open(path, IO::FileMode::Read);
                uint64 size = f.Size();
                const uint64 kMaxBufferLoadBytes = 32 * 1024 * 1024;
                if (size == 0 || size > kMaxBufferLoadBytes) {
                    f.Close();
                    if (size > kMaxBufferLoadBytes) {
                        _MlBrowserWarn("Skipping buffer load for large file (" + size + " bytes): " + path);
                    }
                    return false;
                }
                MemoryBuffer@ buf = f.Read(size);
                f.Close();
                if (buf is null || buf.GetSize() == 0) return false;
                @texture = UI::LoadTexture(buf);
                if (texture !is null) {
                    _MlBrowserLog("Loaded texture from memory buffer: " + path);
                } else {
                    _MlBrowserWarn("UI::LoadTexture(buffer) returned null for: " + path + " (size=" + size + ")");
                }
                return texture !is null;
            } catch {
                _MlBrowserWarn("Exception in buffer texture load for: " + path + " | " + getExceptionInfo());
                @texture = null;
                return false;
            }
        }

        bool _MlBrowserTextureHasValidSize(UI::Texture@ tex, vec2 &out size) {
            size = vec2();
            if (tex is null) return false;
            try {
                size = tex.GetSize();
            } catch {
                size = vec2();
            }
            if (size.x <= 1.0f || size.y <= 1.0f) return false;
            if (size.x > 65536.0f || size.y > 65536.0f) return false;
            return true;
        }

        bool _MlBrowserTryLoadTextureViaDdsDecoder(
            const string &in filePath,
            UI::Texture@&out texture,
            string &out errorDetails
        ) {
            @texture = null;
            errorDetails = "";
            string path = filePath.Trim();
            if (path.Length == 0 || !IO::FileExists(path)) return false;

            bool maybeDds = path.ToLower().EndsWith(".dds");
            if (!maybeDds) {
                try {
                    maybeDds = IMG::IsDds(path);
                } catch {
                    maybeDds = false;
                }
            }
            if (!maybeDds) return false;

            try {
                _MlBrowserLog("Trying DDS decode fallback: " + path);
                IMG::_lastTextureLoadError = "";
                auto dds = IMG::LoadDdsContainer(path);
                if (dds is null || dds.Images.Length == 0) {
                    errorDetails = "DDS parse failed: " + IMG::_lastTextureLoadError;
                    _MlBrowserWarn(errorDetails + " | " + path);
                    return false;
                }
                auto decoded = dds.Images[0].DecompressSize(1024, 1024);
                if (decoded is null) {
                    errorDetails = "DDS decode failed: " + IMG::_lastTextureLoadError;
                    _MlBrowserWarn(errorDetails + " | " + path);
                    return false;
                }
                MemoryBuffer@ bmp = decoded.ToBitmap();
                if (bmp !is null && bmp.GetSize() > 0) {
                    string bmpPath = _MlBrowserDecodedBmpCachePath(path);
                    if (_MlBrowserWriteBufferToFile(bmpPath, bmp)) {
                        _MlBrowserLog("Wrote decoded DDS BMP cache: " + bmpPath);
                        try {
                            @texture = UI::LoadTexture(bmpPath);
                            if (texture !is null) {
                                _MlBrowserLog("Loaded DDS preview from cached BMP file: " + bmpPath);
                                return true;
                            }
                            _MlBrowserWarn("UI::LoadTexture(path) returned null for decoded BMP: " + bmpPath);
                        } catch {
                            _MlBrowserWarn("Exception loading decoded BMP file texture: " + bmpPath + " | " + getExceptionInfo());
                        }
                    }

                    try {
                        @texture = UI::LoadTexture(bmp);
                        if (texture !is null) {
                            _MlBrowserLog("Loaded DDS preview directly from decoded BMP buffer.");
                            return true;
                        }
                        _MlBrowserWarn("UI::LoadTexture(decoded BMP buffer) returned null: " + path);
                    } catch {
                        _MlBrowserWarn("Exception loading decoded BMP buffer: " + path + " | " + getExceptionInfo());
                    }
                }

                @texture = decoded.ToTexture();
                if (texture !is null) {
                    _MlBrowserLog("Loaded DDS preview via RawImage::ToTexture fallback.");
                    return true;
                }
                errorDetails = "DDS decode produced no loadable texture: " + IMG::_lastTextureLoadError;
                _MlBrowserWarn(errorDetails + " | " + path);
                return false;
            } catch {
                errorDetails = "DDS exception: " + getExceptionInfo();
                _MlBrowserWarn(errorDetails + " | " + path);
                @texture = null;
                return false;
            }
        }

    }
}
