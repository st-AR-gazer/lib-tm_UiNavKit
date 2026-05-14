namespace UiNavKit {
    namespace AssetBrowser {

        bool _MlBrowserExtractMediaUrlToStorageRaw(
            const string &in rawUrl,
            string &out stagedRawPath,
            string &out errorDetails
        ) {
            stagedRawPath = "";
            errorDetails = "";
            string url = _MlBrowserNormalizeUrl(rawUrl);
            if (!_MlBrowserIsMediaManialinksUrl(url)) {
                errorDetails = "URL is not under file://Media/Manialinks/";
                return false;
            }

            string rel = _MlBrowserStorageRelPathForUrl(url);
            string mediaKey = "Media/Manialinks/" + rel;
            string alreadyStaged = _MlBrowserStoragePathForUrl(url, mediaKey);
            if (IO::FileExists(alreadyStaged)) {
                stagedRawPath = alreadyStaged;
                return true;
            }

            array<string> fidKeys = {mediaKey};

            for (uint k = 0; k < fidKeys.Length; ++k) {
                string key = fidKeys[k];
                _MlBrowserLog("Trying media fid key: " + key);
                if (_MlBrowserTryStageMediaWithGetFlow(key, url, stagedRawPath)) return true;
            }

            errorDetails = "Failed to extract Media/Manialinks fid to storage path.";
            if (!_MlBrowserCanUseFidExtract()) errorDetails += " Openplanet full permissions are required for Fids::Extract.";
            return false;
        }

        MemoryBuffer@ _MlBrowserRawImageToBmpBuffer(IMG::RawImage@ raw, string &out errorDetails) {
            errorDetails = "";
            if (raw is null) {
                errorDetails = "Decoded image was null.";
                return null;
            }

            int srcW = raw.Width;
            int srcH = raw.Height;
            if (srcW <= 0 || srcH <= 0) {
                errorDetails = "Decoded image has invalid dimensions.";
                return null;
            }

            int expectedBytes = srcW * srcH * 4;
            if (expectedBytes <= 0 || raw.Data.Length < expectedBytes) {
                errorDetails = "Decoded image buffer is invalid.";
                return null;
            }

            int dstW = srcW;
            int dstH = srcH;
            const int kMaxPreviewDim = 1024;
            if (srcW > kMaxPreviewDim || srcH > kMaxPreviewDim) {
                float sx = float(kMaxPreviewDim) / float(srcW);
                float sy = float(kMaxPreviewDim) / float(srcH);
                float scale = Math::Min(sx, sy);
                dstW = Math::Max(1, int(Math::Round(float(srcW) * scale)));
                dstH = Math::Max(1, int(Math::Round(float(srcH) * scale)));
                _MlBrowserLog("Downscaling decoded DDS preview " + srcW + "x" + srcH + " -> " + dstW + "x" + dstH);
            }

            MemoryBuffer@ target = MemoryBuffer();

            target.Write("BM");
            uint bmpBytes = uint(14 + 40 + 2 + dstW * dstH * 4);
            target.Write(bmpBytes);
            target.Write(uint(0));
            target.Write(14 + 40 + 2);

            target.Write(uint(40));
            target.Write(dstW);
            target.Write(-dstH);
            target.Write(uint16(1));
            target.Write(uint16(32));
            target.Write(uint(0));
            target.Write(uint(dstW * dstH * 4));
            target.Write(0);
            target.Write(0);
            target.Write(uint(0));
            target.Write(uint(0));
            target.Write(uint16(0));

            const int kYieldEveryRows = 16;

            if (dstW == srcW && dstH == srcH) {
                for (int y = 0; y < dstH; ++y) {
                    int rowBase = y * srcW * 4;
                    for (int x = 0; x < dstW; ++x) {
                        int si = rowBase + x * 4;
                        target.Write(raw.Data[si + 2]);
                        target.Write(raw.Data[si + 1]);
                        target.Write(raw.Data[si + 0]);
                        target.Write(raw.Data[si + 3]);
                    }
                    if ((y & (kYieldEveryRows - 1)) == (kYieldEveryRows - 1)) yield();
                }
            } else {
                for (int y = 0; y < dstH; ++y) {
                    int sy = (y * srcH) / dstH;
                    int srcRow = sy * srcW * 4;
                    for (int x = 0; x < dstW; ++x) {
                        int sxPx = (x * srcW) / dstW;
                        int si = srcRow + sxPx * 4;
                        target.Write(raw.Data[si + 2]);
                        target.Write(raw.Data[si + 1]);
                        target.Write(raw.Data[si + 0]);
                        target.Write(raw.Data[si + 3]);
                    }
                    if ((y & (kYieldEveryRows - 1)) == (kYieldEveryRows - 1)) yield();
                }
            }

            return target;
        }

        bool _MlBrowserConvertStagedDdsToLoadable(
            const string &in stagedRawPath,
            string &out loadPath,
            string &out errorDetails
        ) {
            loadPath = stagedRawPath.Trim();
            errorDetails = "";
            if (loadPath.Length == 0 || !IO::FileExists(loadPath)) {
                errorDetails = "Staged raw path missing.";
                return false;
            }
            if (!loadPath.ToLower().EndsWith(".dds")) return true;

            uint64 ddsSize = 0;
            try {
                ddsSize = IO::FileSize(loadPath);
            } catch {
                ddsSize = 0;
            }
            if (ddsSize == 0) {
                errorDetails = "DDS file is empty.";
                return false;
            }
            const uint64 kMaxDecodeSize = 96 * 1024 * 1024;
            if (ddsSize > kMaxDecodeSize) {
                errorDetails = "DDS file too large to decode safely (" + ddsSize + " bytes).";
                return false;
            }

            bool isDds = false;
            try {
                isDds = IMG::IsDds(loadPath);
            } catch {
                isDds = false;
            }
            if (!isDds) {
                errorDetails = "Staged file is not recognized as DDS.";
                return false;
            }

            string bmpPath = _MlBrowserStorageBmpPathForRaw(loadPath);
            if (IO::FileExists(bmpPath) && IO::FileSize(bmpPath) > 0) {
                loadPath = bmpPath;
                return true;
            }

            try {
                IMG::_lastTextureLoadError = "";
                auto dds = IMG::LoadDdsContainer(loadPath);
                if (dds is null || dds.Images.Length == 0) {
                    errorDetails = "DDS parse failed: " + IMG::_lastTextureLoadError;
                    return false;
                }

                auto decoded = dds.Images[0].DecompressSize(1024, 1024);
                if (decoded is null) {
                    errorDetails = "DDS decode failed: " + IMG::_lastTextureLoadError;
                    return false;
                }

                auto bmp = _MlBrowserRawImageToBmpBuffer(decoded, errorDetails);
                if (bmp is null || bmp.GetSize() == 0) {
                    if (errorDetails.Length == 0) errorDetails = "DDS decode produced empty bitmap.";
                    return false;
                }

                if (!_MlBrowserWriteBufferToFile(bmpPath, bmp)) {
                    errorDetails = "Failed to write decoded BMP to storage.";
                    return false;
                }
            } catch {
                errorDetails = "DDS conversion exception: " + getExceptionInfo();
                return false;
            }

            loadPath = bmpPath;
            _MlBrowserLog("Decoded DDS and wrote loadable preview: " + loadPath);
            return true;
        }

    }
}
