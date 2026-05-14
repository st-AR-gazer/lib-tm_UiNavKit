namespace UiNavKit {
    namespace Builder {

        CGameManiaApp@ _GetAppByKind(int appKind) {
            if (appKind == 0) return UiNavKit::Runtime::GetManiaAppPlayground();
            if (appKind == 1) return UiNavKit::Runtime::GetManiaAppMenu();
            return UiNavKit::Runtime::GetManiaApp();
        }

        CGameUILayer@ _GetLayerByKindIx(int appKind, int layerIx) {
            if (layerIx < 0) return null;
            auto app = _GetAppByKind(appKind);
            if (app is null) return null;
            auto layers = app.UILayers;
            if (layerIx < 0 || layerIx >= int(layers.Length)) return null;
            return layers[uint(layerIx)];
        }

        string _GetLayerXml(CGameUILayer@ layer) {
            if (layer is null) return "";
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
            return xml;
        }

        void _UpdateDirtyState() {
            _EnsureDoc();
            string nowXml = ExportToXml(g_Doc);
            g_Doc.dirty = nowXml != g_BaselineXml;
            g_LastExportXml = nowXml;
        }

        void _QueueAutoPreview() {
            if (!S_AutoLivePreview) return;
            g_AutoPreviewPending = true;
            g_AutoPreviewQueuedMs = Time::Now;
        }

        void TickAutoPreview() {
            if (!S_AutoLivePreview) return;
            if (!g_AutoPreviewPending) return;

            uint now = Time::Now;
            uint debounce = S_AutoLivePreviewDebounceMs;
            if (now - g_AutoPreviewQueuedMs < debounce) return;

            bool ok = _ApplyPreviewLayerInternal(false);
            if (ok) {
                g_AutoPreviewPending = false;
            } else {
                g_AutoPreviewQueuedMs = now;
            }
        }

    }
}
