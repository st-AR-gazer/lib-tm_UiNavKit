namespace UiNavKit {
    namespace AssetBrowser {

        bool _MlBrowserTryGetSelectedPreviewTextureSize(vec2 &out texSize) {
            texSize = vec2();
            string url = _MlBrowserNormalizeUrl(g_MlBrowserSelectedUrl);
            if (url.Length == 0) return false;
            _MlBrowserEnsurePreviewLoaded();
            if (g_MlBrowserPreviewTextureUrl != url || g_MlBrowserPreviewTexture is null) return false;
            return _MlBrowserTextureHasValidSize(g_MlBrowserPreviewTexture, texSize);
        }

        void _MlBrowserResetPreview() {
            @g_MlBrowserPreviewTexture = null;
            g_MlBrowserPreviewTextureUrl = "";
            g_MlBrowserPreviewError = "";
            g_MlBrowserLoadPreviewRequested = false;
            g_MlBrowserPreviewLoadStartedMs = 0;
            g_MlBrowserPreviewLastAttemptMs = 0;
        }

        void _MlBrowserQueueDdsConversion(const string &in url, const string &in stagedRawPath) {
            string u = _MlBrowserNormalizeUrl(url);
            string raw = stagedRawPath.Trim();
            if (u.Length == 0 || raw.Length == 0) return;
            if (!raw.ToLower().EndsWith(".dds")) return;

            string converted = "";
            if (g_MlBrowserConvertedPathCache.Get(u, converted) && converted.Length > 0 && IO::FileExists(converted)) return;
            if (g_MlBrowserConvertJobRunning && g_MlBrowserConvertJobUrl == u && g_MlBrowserConvertJobRawPath == raw) return;
            if (_MlBrowserFindQueuedConversionIx(u, raw) >= 0) return;

            if (g_MlBrowserConvertJobRunning) {
                if (g_MlBrowserConvertJobStartedMs > 0 && int(Time::Now - g_MlBrowserConvertJobStartedMs) > 15000) {
                    _MlBrowserWarn("DDS conversion worker looked stale; resetting queue state.");
                    _MlBrowserClearActiveConversion();
                }
            }

            if (g_MlBrowserConvertJobRunning) {
                _MlBrowserEnqueueConversion(u, raw);
                return;
            }

            _MlBrowserStartActiveConversion(u, raw, Time::Now);
            startnew(_MlBrowserRunDdsConversionWorker);
        }

        void _MlBrowserRunDdsConversionWorker() {
            while (g_MlBrowserConvertJobRunning) {
                string url = g_MlBrowserConvertJobUrl;
                string rawPath = g_MlBrowserConvertJobRawPath;
                string outPath = "";
                string err = "";
                bool ok = false;
                try {
                    ok = _MlBrowserConvertStagedDdsToLoadable(rawPath, outPath, err);
                } catch {
                    err = "DDS conversion worker exception: " + getExceptionInfo();
                    ok = false;
                }
                if (ok && outPath.Length > 0 && IO::FileExists(outPath)) {
                    g_MlBrowserConvertedPathCache.Set(url, outPath);
                    g_MlBrowserConvertedErrorCache.Delete(url);
                    _MlBrowserLog("DDS conversion ready: " + outPath);
                } else {
                    if (err.Length == 0) err = "Unknown DDS conversion failure.";
                    g_MlBrowserConvertedErrorCache.Set(url, err);
                    _MlBrowserWarn("DDS conversion failed: " + err + " | " + url);
                }

                _MlBrowserClearActiveConversion();

                string nextUrl = "";
                string nextRaw = "";
                uint nextQueuedAtMs = 0;
                if (_MlBrowserPopNextQueuedConversion(nextUrl, nextRaw, nextQueuedAtMs)) {
                    _MlBrowserStartActiveConversion(nextUrl, nextRaw, nextQueuedAtMs);
                    yield();
                    continue;
                }
                break;
            }
        }

    }
}
