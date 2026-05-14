namespace UiNavKit {
    namespace AssetBrowser {

        bool _MlBrowserPrepareStoragePreviewPath(
            const string &in rawUrl,
            string &out previewPath,
            string &out errorDetails
        ) {
            previewPath = "";
            errorDetails = "";
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) {
                errorDetails = "Empty URL.";
                return false;
            }

            string stagedRaw = "";
            if (_MlBrowserIsMediaManialinksUrl(url)) {
                if (!_MlBrowserExtractMediaUrlToStorageRaw(url, stagedRaw, errorDetails)) return false;
            } else {
                string path = url.StartsWith("file://") ? url.SubStr(7) : url;
                string staged = _MlBrowserStageFileForPreview(path, url);
                if (staged.Length == 0) {
                    errorDetails = "Could not stage non-media URL into storage.";
                    return false;
                }
                stagedRaw = staged;
            }

            if (!stagedRaw.ToLower().EndsWith(".dds")) {
                previewPath = stagedRaw;
                return true;
            }

            string convertedPath = "";
            if (g_MlBrowserConvertedPathCache.Get(url, convertedPath) && convertedPath.Length > 0 && IO::FileExists(convertedPath)) {
                previewPath = convertedPath;
                return true;
            }

            previewPath = stagedRaw;
            return true;
        }

        void _MlBrowserBuildLoadCandidates(const string &in rawUrl, array<string> &inout outPaths) {
            outPaths.Resize(0);
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return;
            string previewPath = "";
            string prepErr = "";
            if (_MlBrowserPrepareStoragePreviewPath(url, previewPath, prepErr) && previewPath.Length > 0) {
                _MlBrowserAddLoadCandidate(outPaths, previewPath);
            } else {
                string fallback = _MlBrowserStoragePathForUrl(url, url);
                _MlBrowserAddLoadCandidate(outPaths, fallback);
                if (prepErr.Length > 0) _MlBrowserWarn(prepErr + " | " + url);
            }

            _MlBrowserLog("Load candidates for " + url + ": " + outPaths.Length);
            if (S_MlBrowserVerboseLogs) {
                for (uint i = 0; i < outPaths.Length; ++i) {
                    _MlBrowserLog("  candidate[" + i + "] = " + outPaths[i]);
                }
            }
        }

        void _MlBrowserEnsurePreviewLoaded() {
            if (!g_MlBrowserLoadPreviewRequested) return;
            string url = g_MlBrowserSelectedUrl.Trim();
            if (url.Length == 0) {
                _MlBrowserResetPreview();
                return;
            }
            if (g_MlBrowserPreviewTextureUrl == url && g_MlBrowserPreviewTexture !is null) {
                vec2 texSize = vec2();
                if (_MlBrowserTextureHasValidSize(g_MlBrowserPreviewTexture, texSize)) return;
                if (g_MlBrowserPreviewLoadStartedMs > 0 && int(Time::Now - g_MlBrowserPreviewLoadStartedMs) < 1500) return;
            }
            if (g_MlBrowserPreviewTextureUrl == url && g_MlBrowserPreviewError.Length > 0) {
                string convertedPath = "";
                bool hasNewConverted = g_MlBrowserConvertedPathCache.Get(
                    url,
                    convertedPath
                ) && convertedPath.Length > 0 && IO::FileExists(convertedPath);
                if (!hasNewConverted) {
                    string convertErr = "";
                    if (g_MlBrowserConvertedErrorCache.Get(url, convertErr) && convertErr.Length > 0) {
                        g_MlBrowserPreviewError = "Could not load this image as a UI texture. DDS conversion failed: " + convertErr;
                    }
                    return;
                }
            }
            if (g_MlBrowserPreviewTextureUrl == url) {
                if (g_MlBrowserPreviewLastAttemptMs > 0 && int(Time::Now - g_MlBrowserPreviewLastAttemptMs) < 250) return;
                if (g_MlBrowserConvertJobRunning && g_MlBrowserConvertJobUrl == url) {
                    if (g_MlBrowserPreviewLastAttemptMs > 0 && int(Time::Now - g_MlBrowserPreviewLastAttemptMs) < 750) return;
                }
            }

            @g_MlBrowserPreviewTexture = null;
            g_MlBrowserPreviewTextureUrl = url;
            g_MlBrowserPreviewError = "";
            g_MlBrowserPreviewLastAttemptMs = Time::Now;
            g_MlBrowserPreviewLoadStartedMs = g_MlBrowserPreviewLastAttemptMs;

            array<string> candidates;
            _MlBrowserBuildLoadCandidates(url, candidates);
            bool queuedDdsConversion = false;
            UI::Texture@ pendingTexture = null;
            string pendingTextureSource = "";
            for (uint i = 0; i < candidates.Length; ++i) {
                string candidate = candidates[i];
                try {
                    auto tex = UI::LoadTexture(candidate);
                    if (tex !is null) {
                        vec2 texSize = vec2();
                        if (_MlBrowserTextureHasValidSize(tex, texSize)) {
                            _MlBrowserLog("Loaded texture from path candidate: " + candidate + " (" + texSize.x + "x" + texSize.y + ")");
                            @g_MlBrowserPreviewTexture = tex;
                            return;
                        }
                        if (pendingTexture is null) {
                            @pendingTexture = tex;
                            pendingTextureSource = candidate;
                        }
                        _MlBrowserWarn("Loaded path texture had invalid size: " + candidate);
                    }
                    _MlBrowserWarn("UI::LoadTexture(path) returned null for candidate: " + candidate);
                } catch {
                    _MlBrowserWarn("Exception in UI::LoadTexture(path) for candidate: " + candidate + " | " + getExceptionInfo());
                }

                UI::Texture@ texFromBuf = null;
                if (_MlBrowserTryLoadTextureFromBuffer(candidate, texFromBuf) && texFromBuf !is null) {
                    vec2 texSize = vec2();
                    if (_MlBrowserTextureHasValidSize(texFromBuf, texSize)) {
                        _MlBrowserLog("Using buffer-loaded texture: " + candidate + " (" + texSize.x + "x" + texSize.y + ")");
                        @g_MlBrowserPreviewTexture = texFromBuf;
                        return;
                    }
                    if (pendingTexture is null) {
                        @pendingTexture = texFromBuf;
                        pendingTextureSource = candidate + " (buffer)";
                    }
                    _MlBrowserWarn("Loaded buffer texture had invalid size: " + candidate);
                }

                if (candidate.ToLower().EndsWith(".dds")) {
                    _MlBrowserQueueDdsConversion(url, candidate);
                    queuedDdsConversion = true;
                }
            }

            if (queuedDdsConversion) {
                string convertErr = "";
                if (g_MlBrowserConvertedErrorCache.Get(url, convertErr) && convertErr.Length > 0) {
                    g_MlBrowserPreviewError = "Could not load this image as a UI texture. DDS conversion failed: " + convertErr;
                } else {
                    g_MlBrowserPreviewError = "Preparing DDS preview fallback...";
                }
                return;
            }

            if (pendingTexture !is null) {
                @g_MlBrowserPreviewTexture = pendingTexture;
                g_MlBrowserPreviewError = "Texture loaded but reported invalid size (best effort).";
                _MlBrowserWarn("Using pending-size texture: " + pendingTextureSource);
                return;
            }

            g_MlBrowserPreviewError = "Could not load this image as a UI texture.";
            _MlBrowserWarn("All preview load methods failed for URL: " + url);
        }

        void _MlBrowserSelectUrl(const string &in url) {
            string normalized = _MlBrowserNormalizeUrl(url);
            if (g_MlBrowserSelectedUrl == normalized) return;
            _MlBrowserPushHistory();
            _MlBrowserClearFolderSelection();
            g_MlBrowserSelectedUrl = normalized;
            @g_MlBrowserPreviewTexture = null;
            g_MlBrowserPreviewTextureUrl = "";
            g_MlBrowserPreviewError = "";
            g_MlBrowserLoadPreviewRequested = S_MlBrowserAutoPreview;
            g_MlBrowserPreviewLoadStartedMs = 0;
            g_MlBrowserPreviewLastAttemptMs = 0;
        }

        MlBrowserEntry@ _MlBrowserGetSelectedEntry() {
            string selected = g_MlBrowserSelectedUrl;
            if (selected.Length == 0) return null;
            for (uint i = 0; i < g_MlBrowserEntries.Length; ++i) {
                auto e = g_MlBrowserEntries[i];
                if (e is null) continue;
                if (e.url == selected) return e;
            }
            return null;
        }

        string _MlBrowserPreviewLoadingFrame() {
            uint frame = (Time::Now / 120) % 4;
            if (frame == 0) return "|";
            if (frame == 1) return "/";
            if (frame == 2) return "-";
            return "\\";
        }

        bool _MlBrowserIsPreviewLoading(const string &in rawUrl) {
            if (!g_MlBrowserLoadPreviewRequested) return false;
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return false;
            if (g_MlBrowserConvertJobRunning && g_MlBrowserConvertJobUrl == url) return true;
            if (g_MlBrowserPreviewTextureUrl != url) return false;
            if (g_MlBrowserPreviewTexture is null) return true;

            vec2 texSize = vec2();
            if (!_MlBrowserTextureHasValidSize(g_MlBrowserPreviewTexture, texSize)) return true;
            return false;
        }

        void _MlBrowserRenderPreviewLoadingUi(const string &in rawUrl) {
            string url = _MlBrowserNormalizeUrl(rawUrl);
            int elapsedSec = 0;
            if (g_MlBrowserPreviewLoadStartedMs > 0) {
                elapsedSec = int(Time::Now - g_MlBrowserPreviewLoadStartedMs) / 1000;
            }
            string msg = "Loading preview " + _MlBrowserPreviewLoadingFrame();
            if (g_MlBrowserConvertJobRunning && g_MlBrowserConvertJobUrl == url) msg += " (DDS decode)";
            if (elapsedSec > 0) msg += " " + elapsedSec + "s";
            UI::Text("\\$ff0" + msg + "\\$z");
            UI::TextDisabled("Large assets can take a few seconds to stage/decode.");
        }

    }
}
