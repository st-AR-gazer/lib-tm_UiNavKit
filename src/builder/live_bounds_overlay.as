namespace UiNavKit {
    namespace Builder {

        bool _ResolveLiveNodeByPath(
            CGameManialinkFrame@ root,
            const string &in pathRaw,
            CGameManialinkControl@&out node,
            bool &out hiddenAncestor,
            int &out clipDepth
        ) {
            @node = null;
            hiddenAncestor = false;
            clipDepth = 0;
            if (root is null) return false;

            CGameManialinkControl@ cur = cast<CGameManialinkControl@>(root);
            string path = pathRaw.Trim();
            if (path.Length == 0) {
                @node = cur;
                return true;
            }

            auto parts = path.Split("/");
            for (uint i = 0; i < parts.Length; ++i) {
                string part = parts[i].Trim();
                if (part.Length == 0) continue;

                int idx = Text::ParseInt(part);
                if (idx < 0) return false;

                bool vis = true;
                try {
                    vis = cur.Visible;
                } catch {
                    vis = true;
                }
                if (!vis) hiddenAncestor = true;

                auto f = cast<CGameManialinkFrame@>(cur);
                if (f is null) return false;

                bool clipActive = false;
                try {
                    clipActive = f.ClipWindowActive;
                } catch {
                    clipActive = false;
                }
                if (clipActive) clipDepth++;

                if (uint(idx) >= f.Controls.Length) return false;
                @cur = f.Controls[uint(idx)];
                if (cur is null) return false;
            }

            @node = cur;
            return true;
        }

        bool _ScanLiveLayerBoundsRow(CGameUILayer@ layer, int appKind, int layerIx, LiveLayerBoundsRow@&out row) {
            @row = null;
            if (layer is null || layerIx < 0) return false;

            auto outRow = LiveLayerBoundsRow();
            outRow.appKind = appKind;
            outRow.layerIx = layerIx;
            try {
                outRow.visible = layer.IsVisible;
            } catch {
                outRow.visible = false;
            }
            try {
                outRow.attachId = layer.AttachId;
            } catch {
                outRow.attachId = "";
            }

            string xml = _GetLayerXml(layer);
            outRow.manialinkName = UiNavKit::Runtime::ExtractManialinkName(xml);

            if (layer.LocalPage is null || layer.LocalPage.MainFrame is null) {
                outRow.note = "No LocalPage/MainFrame.";
                @row = outRow;
                return true;
            }

            auto st = _LiveBoundsState();
            _LiveBoundsVisit(layer.LocalPage.MainFrame, false, 0, st);

            outRow.nodes = st.nodes;
            outRow.clipActiveFrames = st.clipActiveFrames;
            outRow.hiddenSelf = st.hiddenSelf;
            outRow.hiddenByAncestor = st.hiddenByAncestor;
            outRow.underClipAncestor = st.underClipAncestor;

            outRow.hasAll = st.hasAll;
            if (st.hasAll) {
                outRow.minAll = st.minAll;
                outRow.maxAll = st.maxAll;
            }

            outRow.hasVisible = st.hasVisible;
            if (st.hasVisible) {
                outRow.minVisible = st.minVisible;
                outRow.maxVisible = st.maxVisible;
            }

            @row = outRow;
            return true;
        }

        bool _ScanLiveLayerBoundsPathRow(
            CGameUILayer@ layer,
            int appKind,
            int layerIx,
            const string &in path,
            LiveLayerBoundsRow@&out row
        ) {
            @row = null;
            if (layer is null || layerIx < 0) return false;

            auto outRow = LiveLayerBoundsRow();
            outRow.appKind = appKind;
            outRow.layerIx = layerIx;
            try {
                outRow.visible = layer.IsVisible;
            } catch {
                outRow.visible = false;
            }
            try {
                outRow.attachId = layer.AttachId;
            } catch {
                outRow.attachId = "";
            }

            string xml = _GetLayerXml(layer);
            outRow.manialinkName = UiNavKit::Runtime::ExtractManialinkName(xml);

            if (layer.LocalPage is null || layer.LocalPage.MainFrame is null) {
                outRow.note = "No LocalPage/MainFrame.";
                @row = outRow;
                return true;
            }

            CGameManialinkControl@ start = null;
            bool hiddenAncestor = false;
            int clipDepth = 0;
            if (!_ResolveLiveNodeByPath(layer.LocalPage.MainFrame, path, start, hiddenAncestor, clipDepth) || start is null) {
                outRow.note = "Selection path unavailable: " + path;
                @row = outRow;
                return true;
            }

            auto st = _LiveBoundsState();
            _LiveBoundsVisit(start, hiddenAncestor, clipDepth, st);

            outRow.nodes = st.nodes;
            outRow.clipActiveFrames = st.clipActiveFrames;
            outRow.hiddenSelf = st.hiddenSelf;
            outRow.hiddenByAncestor = st.hiddenByAncestor;
            outRow.underClipAncestor = st.underClipAncestor;

            outRow.hasAll = st.hasAll;
            if (st.hasAll) {
                outRow.minAll = st.minAll;
                outRow.maxAll = st.maxAll;
            }

            outRow.hasVisible = st.hasVisible;
            if (st.hasVisible) {
                outRow.minVisible = st.minVisible;
                outRow.maxVisible = st.maxVisible;
            }

            outRow.visible = outRow.visible && st.hasVisible;
            outRow.note = "path=" + (path.Length > 0 ? path : "<root>");

            @row = outRow;
            return true;
        }

        bool ScanLiveLayerBounds(int appKind) {
            g_LiveLayerBoundsRows.Resize(0);
            g_LiveLayerBoundsStatus = "";
            g_LiveLayerBoundsAtMs = Time::Now;
            g_LiveLayerBoundsAppKind = appKind;

            auto app = _GetAppByKind(appKind);
            if (app is null) {
                g_LiveLayerBoundsStatus = "Scan failed: app is null for appKind=" + appKind + ".";
                return false;
            }

            auto layers = app.UILayers;
            for (uint i = 0; i < layers.Length; ++i) {
                auto layer = layers[i];
                if (layer is null) continue;
                LiveLayerBoundsRow@ row = null;
                if (!_ScanLiveLayerBoundsRow(layer, appKind, int(i), row) || row is null) continue;
                g_LiveLayerBoundsRows.InsertLast(row);
            }

            g_LiveLayerBoundsStatus = "Scanned " + g_LiveLayerBoundsRows.Length + " layer(s) for appKind=" + appKind + ".";
            return true;
        }

        string LiveLayerBoundsTableText() {
            string outS = "";
            outS += "=== UiNav Live Layer Bounds ===\n";
            outS += "t_ms=" + Time::Now + "\n";
            outS += "appKind=" + g_LiveLayerBoundsAppKind + " layers=" + g_LiveLayerBoundsRows.Length + "\n";
            for (uint i = 0; i < g_LiveLayerBoundsRows.Length; ++i) {
                auto r = g_LiveLayerBoundsRows[i];
                if (r is null) continue;
                string name = r.manialinkName.Length > 0 ? r.manialinkName : "<no manialink name>";
                vec2 sz = r.hasAll ? (r.maxAll - r.minAll) : vec2();
                outS += "L[" + r.layerIx + "] vis=" + (r.visible ? "1" : "0")
                    + " attachId=\"" + r.attachId + "\""
                    + " name=\"" + name + "\""
                    + " nodes=" + r.nodes
                    + " boundsHas=" + (r.hasAll ? "1" : "0");
                if (r.hasAll) outS += " min=" + _FmtVec2(r.minAll) + " max=" + _FmtVec2(r.maxAll) + " size=" + _FmtVec2(sz);
                if (r.note.Length > 0) outS += " note=\"" + r.note + "\"";
                outS += "\n";
            }
            return outS;
        }

        string _LiveBoundsOverlayKey() {
            return "UiNav_BuilderLiveBoundsOverlay";
        }

        string _LiveBoundsParentPath(const string &in rawPath) {
            string path = rawPath.Trim();
            if (path.Length == 0) return "";
            auto parts = path.Split("/");
            string outPath = "";
            bool first = true;
            int lastNonEmpty = -1;
            for (uint i = 0; i < parts.Length; ++i) {
                if (parts[i].Trim().Length > 0) lastNonEmpty = int(i);
            }
            if (lastNonEmpty <= 0) return "";
            for (int i = 0; i < lastNonEmpty; ++i) {
                string part = parts[uint(i)].Trim();
                if (part.Length == 0) continue;
                if (!first) outPath += "/";
                outPath += part;
                first = false;
            }
            return outPath;
        }

        void _AppendLiveLayerBoundsOverlayEntryNodes(
            UiNav::Builder::BuilderDocument@ doc,
            const LiveLayerBoundsRow@ row,
            int layerIx,
            const string &in path,
            const string &in color,
            float fillOpacity,
            float lineOpacity,
            float zBase,
            const string &in labelPrefix
        ) {
            if (doc is null || row is null || !row.hasAll) return;

            vec2 minP = row.minAll;
            vec2 maxP = row.maxAll;
            vec2 center = (minP + maxP) * 0.5f;
            vec2 size = maxP - minP;
            if (size.x < 0.001f || size.y < 0.001f) return;

            float t = 0.95f;
            string pathKey = path.Length == 0 ? "root" : path.Replace("/", "_");
            string uidPrefix = "__uinav_live_bounds_" + labelPrefix + "_l" + layerIx + "_" + pathKey + "_";
            doc.nodes.InsertLast(_MakeOverlayQuad(uidPrefix + "fill", center, size, color, fillOpacity, zBase));
            doc.nodes.InsertLast(_MakeOverlayQuad(uidPrefix + "top", vec2(center.x, maxP.y), vec2(size.x, t), color, lineOpacity, zBase + 0.1f));
            doc.nodes.InsertLast(_MakeOverlayQuad(uidPrefix + "bot", vec2(center.x, minP.y), vec2(size.x, t), color, lineOpacity, zBase + 0.1f));
            doc.nodes.InsertLast(_MakeOverlayQuad(uidPrefix + "l", vec2(minP.x, center.y), vec2(t, size.y), color, lineOpacity, zBase + 0.1f));
            doc.nodes.InsertLast(_MakeOverlayQuad(uidPrefix + "r", vec2(maxP.x, center.y), vec2(t, size.y), color, lineOpacity, zBase + 0.1f));

            string visMark = row.visible ? "V" : "H";
            string pathSuffix = path.Length > 0 ? (" /" + path) : "";
            string lbl = labelPrefix + " L[" + layerIx + "]" + pathSuffix + " " + visMark + " n=" + row.nodes;
            doc.nodes.InsertLast(_MakeOverlayLabel(uidPrefix + "lbl", vec2(center.x, maxP.y + 6.0f), vec2(260, 6), lbl, color, 1.55f, zBase + 0.2f));
        }

        void _AppendLiveLayerBoundsOverlayNodes(
            UiNav::Builder::BuilderDocument@ doc,
            const LiveLayerBoundsRow@ selectedRow,
            int selectedLayerIx,
            const string &in selectedPath = "",
            const array<LiveLayerBoundsRow@> @parentRows = null,
            const array<string> @parentPaths = null
        ) {
            if (doc is null) return;

            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_live_bounds_origin_h", vec2(0, 0), vec2(20, 0.5f), "fff", 0.65f, 12000.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_live_bounds_origin_v", vec2(0, 0), vec2(0.5f, 20), "fff", 0.65f, 12000.0f));
            doc.nodes.InsertLast(_MakeOverlayLabel("__uinav_live_bounds_origin_lbl", vec2(0, -10), vec2(70, 6), "LIVE BOUNDS", "fff", 1.5f, 12001.0f));

            if (selectedLayerIx < 0) {
                _RebuildNodeIndex(doc);
                return;
            }

            if (parentRows !is null && parentPaths !is null) {
                uint count = Math::Min(parentRows.Length, parentPaths.Length);
                for (uint i = 0; i < count; ++i) {
                    auto row = parentRows[i];
                    if (row is null) continue;
                    string color = _PreviewAncestorOverlayColor(int(i));
                    float fillOpacity = Math::Max(0.02f, 0.05f - float(i) * 0.005f);
                    float lineOpacity = Math::Max(0.40f, 0.78f - float(i) * 0.08f);
                    float zBase = 11880.0f - float(i) * 2.0f;
                    _AppendLiveLayerBoundsOverlayEntryNodes(
                        doc,
                        row,
                        selectedLayerIx,
                        parentPaths[i],
                        color,
                        fillOpacity,
                        lineOpacity,
                        zBase,
                        "P" + (i + 1)
                    );
                }
            }

            if (selectedRow !is null && selectedRow.hasAll) {
                string color = selectedRow.visible ? "ff0" : "f6a";
                _AppendLiveLayerBoundsOverlayEntryNodes(
                    doc,
                    selectedRow,
                    selectedLayerIx,
                    selectedPath,
                    color,
                    0.09f,
                    0.88f,
                    11900.0f,
                    "SEL"
                );
            }

            _RebuildNodeIndex(doc);
        }

        bool RefreshLiveLayerBoundsOverlay(bool rescan = false, bool quiet = false) {
            if (!S_LiveLayerBoundsOverlayEnabled) return false;

            int targetAppKind = g_ImportAppKind;
            int targetLayerIx = g_ImportLayerIx;
            string targetPath = "";
            bool targetFromMlSelection = false;
            bool hasTarget = _ResolveLiveBoundsOverlayTarget(
                targetAppKind,
                targetLayerIx,
                targetPath,
                targetFromMlSelection
            );
            CGameManiaApp@ overlayApp = null;
            if (hasTarget) {
                @overlayApp = _GetAppByKind(targetAppKind);
            } else {
                @overlayApp = UiNavKit::Runtime::GetManiaApp();
            }
            if (overlayApp is null) @overlayApp = UiNavKit::Runtime::GetManiaAppMenu();
            if (overlayApp is null) @overlayApp = UiNavKit::Runtime::GetManiaAppPlayground();
            if (overlayApp is null) {
                if (!quiet) g_Status = "Live bounds overlay failed: no target app context.";
                return false;
            }

            LiveLayerBoundsRow@ targetRow = null;
            array<LiveLayerBoundsRow@> parentRows;
            array<string> parentPaths;
            if (hasTarget) {
                auto layer = _GetLayerByKindIx(targetAppKind, targetLayerIx);
                bool okScan = false;
                if (layer !is null) {
                    if (targetFromMlSelection && targetPath.Length > 0) {
                        okScan = _ScanLiveLayerBoundsPathRow(
                            layer,
                            targetAppKind,
                            targetLayerIx,
                            targetPath,
                            targetRow
                        );
                    } else
                    okScan = _ScanLiveLayerBoundsRow(layer, targetAppKind, targetLayerIx, targetRow);
                }
                if (!okScan || targetRow is null) {
                    if (!quiet) g_Status = "Live bounds overlay failed: target layer unavailable.";
                    return false;
                }

                if (targetFromMlSelection && targetPath.Length > 0 && S_LiveLayerBoundsOverlayParentChainEnabled) {
                    string parentPath = _LiveBoundsParentPath(targetPath);
                    int depth = 0;
                    while (depth < 64) {
                        LiveLayerBoundsRow@ parentRow = null;
                        bool parentOk = false;
                        if (parentPath.Length > 0) {
                            parentOk = _ScanLiveLayerBoundsPathRow(
                                layer,
                                targetAppKind,
                                targetLayerIx,
                                parentPath,
                                parentRow
                            );
                        } else {
                            parentOk = _ScanLiveLayerBoundsRow(layer, targetAppKind, targetLayerIx, parentRow);
                        }

                        if (parentOk && parentRow !is null) {
                            parentRows.InsertLast(parentRow);
                            parentPaths.InsertLast(parentPath);
                        }

                        if (parentPath.Length == 0) break;
                        parentPath = _LiveBoundsParentPath(parentPath);
                        depth++;
                    }
                }
            }

            auto doc = _NewDocument();
            doc.name = "UiNav_BuilderLiveBoundsOverlay";
            _AppendLiveLayerBoundsOverlayNodes(
                doc,
                targetRow,
                hasTarget ? targetLayerIx :-1,
                targetFromMlSelection ? targetPath : "",
                parentRows,
                parentPaths
            );

            string xml = ExportToXml(doc);
            if (xml.Length == 0) {
                g_Status = "Live bounds overlay failed: generated XML is empty.";
                return false;
            }

            string key = _LiveBoundsOverlayKey();
            auto layer = UiNavKit::Runtime::EnsureAtApp(key, xml, overlayApp, true, false);
            if (layer is null) {
                g_Status = "Live bounds overlay failed: could not create/update overlay layer.";
                return false;
            }

            if (!quiet) {
                string targetText = "no target";
                if (hasTarget) {
                    targetText = "target L[" + targetLayerIx + "] app=" + targetAppKind;
                    if (targetFromMlSelection && targetPath.Length > 0) targetText += " path=" + targetPath;
                }
                g_Status = "Live bounds overlay updated (" + targetText + ").";
            }
            return true;
        }

        bool DestroyLiveLayerBoundsOverlay() {
            string key = _LiveBoundsOverlayKey();
            bool ok = UiNavKit::Runtime::Destroy(key);
            g_Status = ok ? "Destroyed live bounds overlay." : "Live bounds overlay not found.";
            return ok;
        }

    }
}
