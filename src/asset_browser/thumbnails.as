namespace UiNavKit {
    namespace AssetBrowser {

        void _MlBrowserCacheThumbTexture(const string &in url, UI::Texture@ tex) {
            if (url.Length == 0 || tex is null) return;
            bool existed = g_MlBrowserThumbTextureCache.Exists(url);
            g_MlBrowserThumbTextureCache.Set(url, @tex);
            g_MlBrowserThumbErrorCache.Delete(url);
            if (!existed) {
                g_MlBrowserThumbCacheKeys.InsertLast(url);
                const uint kMaxThumbCache = 192;
                if (g_MlBrowserThumbCacheKeys.Length > kMaxThumbCache) {
                    string victim = g_MlBrowserThumbCacheKeys[0];
                    g_MlBrowserThumbCacheKeys.RemoveAt(0);
                    g_MlBrowserThumbTextureCache.Delete(victim);
                    g_MlBrowserThumbErrorCache.Delete(victim);
                }
            }
        }

        bool _MlBrowserTryGetThumbTexture(
            const string &in rawUrl,
            UI::Texture@&out texture,
            string &out errorDetails,
            bool &out loading
        ) {
            @texture = null;
            errorDetails = "";
            loading = false;

            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (url.Length == 0) return false;

            UI::Texture@ cached = null;
            if (g_MlBrowserThumbTextureCache.Get(url, @cached) && cached !is null) {
                vec2 texSize = vec2();
                if (_MlBrowserTextureHasValidSize(cached, texSize)) {
                    @texture = cached;
                    return true;
                }
                g_MlBrowserThumbTextureCache.Delete(url);
            }

            if (g_MlBrowserPreviewTextureUrl == url && g_MlBrowserPreviewTexture !is null) {
                vec2 texSize = vec2();
                if (_MlBrowserTextureHasValidSize(g_MlBrowserPreviewTexture, texSize)) {
                    _MlBrowserCacheThumbTexture(url, g_MlBrowserPreviewTexture);
                    @texture = g_MlBrowserPreviewTexture;
                    return true;
                }
            }

            string cachedErr = "";
            if (g_MlBrowserThumbErrorCache.Get(url, cachedErr) && cachedErr.Length > 0) {
                string convertedPath = "";
                bool hasNewConverted = g_MlBrowserConvertedPathCache.Get(url, convertedPath)
                    && convertedPath.Length > 0
                    && IO::FileExists(convertedPath);
                if (!hasNewConverted) {
                    if (g_MlBrowserConvertJobRunning && g_MlBrowserConvertJobUrl == url) {
                        loading = true;
                        errorDetails = "Preparing DDS preview fallback...";
                    } else {
                        errorDetails = cachedErr;
                    }
                    return false;
                }
                g_MlBrowserThumbErrorCache.Delete(url);
            }

            if (!_MlBrowserTryConsumeThumbBudget()) {
                loading = true;
                return false;
            }

            array<string> candidates;
            _MlBrowserBuildLoadCandidates(url, candidates);
            bool queuedDdsConversion = false;

            for (uint i = 0; i < candidates.Length; ++i) {
                string candidate = candidates[i];
                try {
                    auto tex = UI::LoadTexture(candidate);
                    if (tex !is null) {
                        vec2 texSize = vec2();
                        if (_MlBrowserTextureHasValidSize(tex, texSize)) {
                            _MlBrowserCacheThumbTexture(url, tex);
                            @texture = tex;
                            return true;
                        }
                    }
                } catch {
                    log(
                        "Error loading texture candidate: " + candidate,
                        LogLevel::Info,
                        93,
                        "UiNavKit::AssetBrowser::_MlBrowserCacheThumbTexture"
                    );
                }

                UI::Texture@ texFromBuf = null;
                if (_MlBrowserTryLoadTextureFromBuffer(candidate, texFromBuf) && texFromBuf !is null) {
                    vec2 texSize = vec2();
                    if (_MlBrowserTextureHasValidSize(texFromBuf, texSize)) {
                        _MlBrowserCacheThumbTexture(url, texFromBuf);
                        @texture = texFromBuf;
                        return true;
                    }
                }

                if (candidate.ToLower().EndsWith(".dds")) {
                    _MlBrowserQueueDdsConversion(url, candidate);
                    queuedDdsConversion = true;
                }
            }

            if (queuedDdsConversion) {
                string convertErr = "";
                if (g_MlBrowserConvertedErrorCache.Get(url, convertErr) && convertErr.Length > 0) {
                    errorDetails = "DDS conversion failed: " + convertErr;
                    g_MlBrowserThumbErrorCache.Set(url, errorDetails);
                } else {
                    loading = true;
                    errorDetails = "Preparing DDS preview fallback...";
                }
                return false;
            }

            errorDetails = "Could not load preview.";
            g_MlBrowserThumbErrorCache.Set(url, errorDetails);
            return false;
        }

    }
}
