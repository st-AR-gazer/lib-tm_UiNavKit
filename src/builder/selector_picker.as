namespace UiNavKit {
    namespace Builder {

        string _SelectorAppKindLabel(int appKind) {
            if (appKind == 0) return "Playground";
            if (appKind == 1) return "Menu";
            if (appKind == 2) return "Current";
            return "<unknown>";
        }

        string SelectorSourceLabel(int appKind) {
            if (appKind < 0) return "All";
            return _SelectorAppKindLabel(appKind);
        }

        string _SelectorAppPrefixByKind(int appKind) {
            if (appKind == 0) return "P";
            if (appKind == 1) return "M";
            return "C";
        }

        string _SelectorMlPrefixByDebugKind(int debugAppKind) {
            if (debugAppKind == 1) return "M";
            if (debugAppKind == 2) return "E";
            return "P";
        }

        int _SelectorMapBuilderAppKindToDebugMlKind(int builderAppKind) {
            if (builderAppKind == 0 || builderAppKind == 1) return builderAppKind;
            if (builderAppKind != 2) return UiNavKit::g_MlActiveAppKind;

            auto cur = _GetAppByKind(2);
            auto menu = _GetAppByKind(1);
            auto pg = _GetAppByKind(0);
            if (cur !is null && menu !is null && cur is menu) return 1;
            if (cur !is null && pg !is null && cur is pg) return 0;
            return UiNavKit::g_MlActiveAppKind;
        }

        void SelectorArmPicker() {
            g_SelectorArmed = true;
            g_SelectorWaitMouseRelease = true;
            g_SelectorArmedAtMs = Time::Now;
            g_SelectorStatus = "Selector armed. Left-click a target UI element.";
        }

        void SelectorDisarmPicker(bool keepStatus = false) {
            g_SelectorArmed = false;
            g_SelectorWaitMouseRelease = false;
            if (!keepStatus) g_SelectorStatus = "Selector stopped.";
        }

        bool _SelectorPointInRect(const vec2 &in p, const vec2 &in minP, const vec2 &in maxP) {
            return p.x >= minP.x && p.x <= maxP.x && p.y >= minP.y && p.y <= maxP.y;
        }

        string _SelectorClasses(CGameManialinkControl@ n) {
            if (n is null) return "";
            string outS = "";
            try {
                auto classes = n.ControlClasses;
                for (uint i = 0; i < classes.Length; ++i) {
                    string c = classes[i].Trim();
                    if (c.Length == 0) continue;
                    if (outS.Length > 0) outS += " ";
                    outS += c;
                }
            } catch {
                outS = outS.Trim();
            }
            return outS;
        }

        string _SelectorTextPreview(CGameManialinkControl@ n, uint maxLen = 120) {
            if (n is null) return "";
            string t = "";
            try {
                t = UiNav::CleanUiFormatting(UiNav::ML::ReadText(n));
            } catch {
                t = "";
            }
            t = t.Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t");
            int maxLenI = int(maxLen);
            if (maxLenI < 8) maxLenI = 8;
            if (int(t.Length) > maxLenI) t = t.SubStr(0, maxLenI - 3) + "...";
            return t;
        }

        class _SelectorPickStats {
            uint nodesVisited = 0;
            uint geomFailed = 0;
        }

        void _SelectorVisit(
            CGameManialinkControl@ n,
            int appKind,
            int layerIx,
            bool layerVisible,
            const string &in layerAttachId,
            const string &in manialinkName,
            const string &in path,
            int depth,
            bool hiddenAncestor,
            const vec2 &in clickPoint,
            bool includeHidden,
            array<SelectorHitRow@> &inout hits,
            _SelectorPickStats@ st
        ) {
            if (n is null) return;
            if (st is null) return;
            st.nodesVisited++;

            bool selfVisible = true;
            try {
                selfVisible = n.Visible;
            } catch {
                selfVisible = true;
            }
            bool hiddenNow = hiddenAncestor || !selfVisible;

            bool ok = true;
            vec2 absPos = vec2();
            vec2 size = vec2();
            float absScale = 1.0f;
            float z = 0.0f;
            CGameManialinkControl::EAlignHorizontal ha = CGameManialinkControl::EAlignHorizontal(1);
            CGameManialinkControl::EAlignVertical va = CGameManialinkControl::EAlignVertical(1);

            try {
                absPos = n.AbsolutePosition_V3;
            } catch {
                ok = false;
            }
            try {
                size = n.Size;
            } catch {
                ok = false;
            }
            try {
                absScale = n.AbsoluteScale;
            } catch {
                absScale = 1.0f;
            }
            try {
                z = n.ZIndex;
            } catch {
                z = 0.0f;
            }
            try {
                ha = n.HorizontalAlign;
            } catch {
                ha = CGameManialinkControl::EAlignHorizontal(1);
            }
            try {
                va = n.VerticalAlign;
            } catch {
                va = CGameManialinkControl::EAlignVertical(1);
            }

            if (ok) {
                float ax = _AnchorXFromLiveAlign(ha);
                float ay = _AnchorYFromLiveAlign(va);
                vec2 absSize = size * absScale;
                vec2 bMin = vec2(absPos.x - ax * absSize.x, absPos.y - (1.0f - ay) * absSize.y);
                vec2 bMax = vec2(absPos.x + (1.0f - ax) * absSize.x, absPos.y + ay * absSize.y);

                bool isHit = _SelectorPointInRect(clickPoint, bMin, bMax);
                if (isHit && (includeHidden || !hiddenNow)) {
                    auto row = SelectorHitRow();
                    row.appKind = appKind;
                    row.layerIx = layerIx;
                    row.layerVisible = layerVisible;
                    row.layerAttachId = layerAttachId;
                    row.manialinkName = manialinkName;
                    row.path = path;
                    row.uiPath = _SelectorAppPrefixByKind(appKind) + "/L" + layerIx + (path.Length > 0 ? ("/" + path) : "");
                    row.depth = depth;
                    row.typeName = UiNav::ML::TypeName(n);
                    try {
                        row.controlId = n.ControlId;
                    } catch {
                        row.controlId = "";
                    }
                    row.classList = _SelectorClasses(n);
                    row.textPreview = _SelectorTextPreview(n);
                    row.selfVisible = selfVisible;
                    row.hiddenByAncestor = hiddenAncestor;
                    row.visibleEffective = row.layerVisible && row.selfVisible && !row.hiddenByAncestor;
                    row.zIndex = z;
                    row.clickPoint = clickPoint;
                    row.absPos = absPos;
                    row.absSize = absSize;
                    row.boundsMin = bMin;
                    row.boundsMax = bMax;
                    row.area = Math::Abs(absSize.x * absSize.y);
                    hits.InsertLast(row);
                }
            } else {
                st.geomFailed++;
            }

            auto f = cast<CGameManialinkFrame@>(n);
            if (f is null) return;

            try {
                for (uint i = 0; i < f.Controls.Length; ++i) {
                    auto ch = f.Controls[i];
                    if (ch is null) continue;
                    string childPath = path.Length > 0 ? (path + "/" + i) : tostring(i);
                    _SelectorVisit(
                        ch,
                        appKind,
                        layerIx,
                        layerVisible,
                        layerAttachId,
                        manialinkName,
                        childPath,
                        depth + 1,
                        hiddenNow,
                        clickPoint,
                        includeHidden,
                        hits,
                        st
                    );
                }
            } catch {
                return;
            }
        }

        void _SelectorPushUniqueApp(array<CGameManiaApp@> &inout apps, array<int> &inout kinds, int appKind) {
            auto app = _GetAppByKind(appKind);
            if (app is null) return;
            for (uint i = 0; i < apps.Length; ++i) {
                if (apps[i] is app) return;
            }
            apps.InsertLast(app);
            kinds.InsertLast(appKind);
        }

        int _SelectorAppRank(int appKind) {
            if (appKind == 2) return 3;
            if (appKind == 1) return 2;
            return 1;
        }

        bool _SelectorHitComesBefore(const SelectorHitRow@ a, const SelectorHitRow@ b) {
            if (a is null) return false;
            if (b is null) return true;

            bool aVisible = a.visibleEffective;
            bool bVisible = b.visibleEffective;
            if (aVisible != bVisible) return aVisible;

            int ar = _SelectorAppRank(a.appKind);
            int br = _SelectorAppRank(b.appKind);
            if (ar != br) return ar > br;

            if (a.layerIx != b.layerIx) return a.layerIx > b.layerIx;

            float zDelta = a.zIndex - b.zIndex;
            if (Math::Abs(zDelta) > 0.001f) return zDelta > 0.0f;

            if (a.depth != b.depth) return a.depth > b.depth;

            float areaDelta = a.area - b.area;
            if (Math::Abs(areaDelta) > 0.001f) return areaDelta < 0.0f;

            return a.path.Length > b.path.Length;
        }

        void _SelectorSortHits(array<SelectorHitRow@> &inout hits) {
            for (uint i = 0; i < hits.Length; ++i) {
                for (uint j = i + 1; j < hits.Length; ++j) {
                    if (_SelectorHitComesBefore(hits[j], hits[i])) {
                        auto tmp = hits[i];
                        @hits[i] = hits[j];
                        @hits[j] = tmp;
                    }
                }
            }
        }

        bool _SelectorBuildPathFromFocused(
            CGameManialinkFrame@ root,
            CGameManialinkControl@ focus,
            string &out path,
            int &out depth,
            bool &out hiddenByAncestor
        ) {
            path = "";
            depth = 0;
            hiddenByAncestor = false;
            if (root is null || focus is null) return false;
            if (focus is root) return true;

            array<int> revPath;
            CGameManialinkControl@ cur = focus;
            int guard = 0;
            while (cur !is null && !(cur is root) && guard < 512) {
                guard++;
                auto parent = cur.Parent;
                if (parent is null) return false;

                bool parentVisible = true;
                try {
                    parentVisible = parent.Visible;
                } catch {
                    parentVisible = true;
                }
                if (!parentVisible) hiddenByAncestor = true;

                int found = -1;
                try {
                    for (uint i = 0; i < parent.Controls.Length; ++i) {
                        if (parent.Controls[i] is cur) {
                            found = int(i);
                            break;
                        }
                    }
                } catch {
                    return false;
                }
                if (found < 0) return false;

                revPath.InsertLast(found);
                @cur = cast<CGameManialinkControl@>(parent);
                depth++;
            }
            if (!(cur is root)) return false;

            for (int i = int(revPath.Length) - 1; i >= 0; --i) {
                if (path.Length > 0) path += "/";
                path += tostring(revPath[uint(i)]);
            }
            return true;
        }

        bool _SelectorSyncHitToEnabledInspectors(int hitIx) {
            bool wantMl = S_SelectorSyncMlSelection;
            bool wantControlTree = S_SelectorSyncControlTreeSelection;
            if (!wantMl && !wantControlTree) return true;

            bool mlOk = !wantMl || SelectorSyncHitToMlSelection(hitIx);
            bool ctOk = !wantControlTree || SelectorSyncHitToControlTreeSelection(hitIx);

            if (wantMl && wantControlTree) {
                if (mlOk && ctOk) {
                    g_SelectorStatus = "Synced selected hit to ManiaLink UI and ControlTree selections.";
                } else if (mlOk) {
                    g_SelectorStatus = "Synced selected hit to ManiaLink UI selection; ControlTree sync failed.";
                } else if (ctOk) {
                    g_SelectorStatus = "Synced selected hit to ControlTree selection; ManiaLink UI sync failed.";
                } else {
                    g_SelectorStatus = "Could not sync selected hit to ManiaLink UI or ControlTree selection.";
                }
                return mlOk || ctOk;
            }

            if (wantMl) {
                g_SelectorStatus = mlOk ?
                "Synced selected hit to ManiaLink UI selection." : "Could not sync selected hit to ManiaLink UI selection.";
                return mlOk;
            }

            g_SelectorStatus = ctOk ?
            "Synced selected hit to ControlTree selection." : "Could not sync selected hit to ControlTree selection.";
            return ctOk;
        }

        bool SelectorSelectHit(int hitIx, bool syncMlSelection = false) {
            if (hitIx < 0 || hitIx >= int(g_SelectorHits.Length)) return false;
            g_SelectorSelectedHitIx = hitIx;
            if (syncMlSelection) return _SelectorSyncHitToEnabledInspectors(hitIx);
            return true;
        }

        bool SelectorPickNow() {
            g_SelectorHits.Resize(0);
            g_SelectorSelectedHitIx = -1;
            g_SelectorLastPickAtMs = Time::Now;

            bool dbg = S_SelectorDebugLog;
            array<string> dbgLines;
            if (dbg) {
                dbgLines.InsertLast("[UiNav.Builder.Selector] PickNow t_ms=" + g_SelectorLastPickAtMs);
                dbgLines.InsertLast("  display=" + Display::GetWidth() + "x" + Display::GetHeight() + " uiMouse=" + _FmtVec2(UI::GetMousePos()));
                dbgLines.InsertLast("  includeHidden=" + (S_SelectorIncludeHidden ? "1" : "0") + " sourceApp=" + SelectorSourceLabel(S_SelectorSourceAppKind));
            }

            array<CGameManiaApp@> apps;
            array<int> kinds;
            if (S_SelectorSourceAppKind >= 0 && S_SelectorSourceAppKind <= 2) {
                _SelectorPushUniqueApp(apps, kinds, S_SelectorSourceAppKind);
            } else {
                _SelectorPushUniqueApp(apps, kinds, 2);
                _SelectorPushUniqueApp(apps, kinds, 1);
                _SelectorPushUniqueApp(apps, kinds, 0);
            }

            if (apps.Length == 0) {
                g_SelectorStatus = "Selector pick failed: no UI app context available.";
                return false;
            }

            uint totalVisited = 0;
            uint totalGeomFailed = 0;

            for (uint ai = 0; ai < apps.Length; ++ai) {
                auto app = apps[ai];
                int appKind = kinds[ai];
                if (app is null) continue;

                vec2 clickPoint = vec2();
                bool okMouse = true;
                try {
                    clickPoint.x = app.MouseX;
                } catch {
                    okMouse = false;
                }
                try {
                    clickPoint.y = app.MouseY;
                } catch {
                    okMouse = false;
                }
                if (!okMouse) continue;

                if (dbg) {
                    dbgLines.InsertLast("  app=" + _SelectorAppKindLabel(appKind) + " mouse=" + _FmtVec2(clickPoint));
                }

                auto layers = app.UILayers;
                for (uint li = 0; li < layers.Length; ++li) {
                    auto layer = layers[li];
                    if (layer is null) continue;

                    bool layerVisible = true;
                    try {
                        layerVisible = layer.IsVisible;
                    } catch {
                        layerVisible = true;
                    }
                    if (!S_SelectorIncludeHidden && !layerVisible) continue;

                    auto page = layer.LocalPage;
                    if (page is null || page.MainFrame is null) continue;

                    string attachId = "";
                    try {
                        attachId = layer.AttachId;
                    } catch {
                        attachId = "";
                    }
                    string manialinkName = UiNavKit::Runtime::ExtractManialinkName(_GetLayerXml(layer));

                    auto st = _SelectorPickStats();
                    uint hitsBefore = g_SelectorHits.Length;
                    _SelectorVisit(
                        page.MainFrame,
                        appKind,
                        int(li),
                        layerVisible,
                        attachId,
                        manialinkName,
                        "",
                        0,
                        false,
                        clickPoint,
                        S_SelectorIncludeHidden,
                        g_SelectorHits,
                        st
                    );

                    totalVisited += st.nodesVisited;
                    totalGeomFailed += st.geomFailed;
                    if (dbg) {
                        uint hitsAdded = g_SelectorHits.Length - hitsBefore;
                        dbgLines.InsertLast("    layer=" + li + " visible=" + (layerVisible ? "1" : "0") + " visited=" + st.nodesVisited + " geomFailed=" + st.geomFailed + " hits=" + hitsAdded + (attachId.Length > 0 ? (" attachId=" + attachId) : "") + (manialinkName.Length > 0 ? (" name=" + manialinkName) : ""));
                    }
                }
            }

            _SelectorSortHits(g_SelectorHits);
            if (g_SelectorHits.Length == 0) {
                g_SelectorStatus = "No UI control found under this click.";
                if (dbg) {
                    dbgLines.InsertLast("  result=none totalVisited=" + totalVisited + " totalGeomFailed=" + totalGeomFailed);
                    string outS = "";
                    for (uint i = 0; i < dbgLines.Length; ++i) outS += (i == 0 ? "" : "\n") + dbgLines[i];
                    log(outS, LogLevel::Info, 492, "UiNavKit::Builder::SelectorPickNow");
                }
                return false;
            }

            g_SelectorSelectedHitIx = 0;
            auto top = g_SelectorHits[0];
            g_SelectorStatus = "Captured " + g_SelectorHits.Length + " hit(s). Top: "
                + _SelectorAppKindLabel(top.appKind) + " L" + top.layerIx
                + (top.path.Length > 0 ? ("/" + top.path) : "/<root>");

            if (dbg) {
                dbgLines.InsertLast("  result=ok hits=" + g_SelectorHits.Length + " totalVisited=" + totalVisited + " totalGeomFailed=" + totalGeomFailed);
                uint maxDbgHits = Math::Min(uint(5), g_SelectorHits.Length);
                for (uint i = 0; i < maxDbgHits; ++i) {
                    auto row = g_SelectorHits[i];
                    if (row is null) continue;
                    dbgLines.InsertLast("  " + SelectorHitSummary(row, int(i + 1)));
                }
                string outS = "";
                for (uint i = 0; i < dbgLines.Length; ++i) outS += (i == 0 ? "" : "\n") + dbgLines[i];
                log(outS, LogLevel::Info, 513, "UiNavKit::Builder::SelectorPickNow");
            }

            if (S_SelectorSyncMlSelection || S_SelectorSyncControlTreeSelection) {
                _SelectorSyncHitToEnabledInspectors(0);
            }
            return true;
        }

        bool SelectorSyncHitToMlSelection(int hitIx) {
            if (hitIx < 0 || hitIx >= int(g_SelectorHits.Length)) return false;
            auto row = g_SelectorHits[uint(hitIx)];
            if (row is null) return false;

            int mlAppKind = _SelectorMapBuilderAppKindToDebugMlKind(row.appKind);
            UiNavKit::g_MlActiveAppKind = mlAppKind;
            @UiNavKit::g_SelectedMlNode = null;
            UiNavKit::_ClearMlNodeFocus();
            UiNavKit::g_SelectedMlAppKind = mlAppKind;
            UiNavKit::g_SelectedMlLayerIx = row.layerIx;
            UiNavKit::g_SelectedMlPath = row.path;
            UiNavKit::g_SelectedMlUiPath = _SelectorMlPrefixByDebugKind(mlAppKind)
                + "/L" + row.layerIx + (row.path.Length > 0 ? ("/" + row.path) : "");
            string layerUiPath = _SelectorMlPrefixByDebugKind(mlAppKind) + "/L" + row.layerIx;
            UiNavKit::g_MlViewLayerIndex = row.layerIx;
            UiNavKit::g_MlFlatDirty = true;
            UiNavKit::g_MlNodeFocusActive = true;
            UiNavKit::g_MlNodeFocusAppKind = mlAppKind;
            UiNavKit::g_MlNodeFocusLayerIx = row.layerIx;
            UiNavKit::g_MlNodeFocusPath = row.path;
            UiNavKit::g_MlNodeFocusUiPath = UiNavKit::g_SelectedMlUiPath;
            UiNavKit::_SetMlTreeOpen(layerUiPath, false);
            UiNavKit::_SetMlTreeOpen(UiNavKit::g_SelectedMlUiPath, false);
            UiNavKit::g_MlNodeFocusStatus = "Selector synced selection and focused path.";

            if (S_LiveLayerBoundsOverlayEnabled) {
                RefreshLiveLayerBoundsOverlay(false, true);
            }
            return true;
        }

        bool SelectorSyncHitToControlTreeSelection(int hitIx) {
            if (hitIx < 0 || hitIx >= int(g_SelectorHits.Length)) return false;
            auto row = g_SelectorHits[uint(hitIx)];
            if (row is null) return false;

            auto layer = _GetLayerByKindIx(row.appKind, row.layerIx);
            if (layer is null || layer.LocalPage is null || layer.LocalPage.MainFrame is null) return false;

            CGameManialinkControl@ mlNode = null;
            bool hiddenAncestor = false;
            int clipDepth = 0;
            if (!_ResolveLiveNodeByPath(layer.LocalPage.MainFrame, row.path, mlNode, hiddenAncestor, clipDepth) || mlNode is null) {
                return false;
            }

            CControlBase@ controlTree = null;
            try {
                @controlTree = mlNode.Control;
            } catch {
                @controlTree = null;
            }
            if (controlTree is null) return false;

            uint overlay = 0;
            int rootIx = -1;
            string relPath = "";
            if (!UiNavKit::_FindControlTreePathForControlAnyOverlay(controlTree, overlay, rootIx, relPath) || rootIx < 0) {
                return false;
            }
            if (S_SelectorDebugLog) {
                log(
                    "[UiNav.Builder.Selector] SyncCT hitIx=" + hitIx + " ml=" + _SelectorAppKindLabel(row.appKind) + " L" + row.layerIx + " /" + (row.path.Length > 0 ? row.path : "<root>") + " -> overlay=" + overlay + " rootIx=" + rootIx + " relPath=" + (relPath.Length > 0 ? relPath : "<root>"),
                    LogLevel::Info,
                    584,
                    "UiNavKit::Builder::SelectorSyncHitToControlTreeSelection"
                );
            }

            UiNavKit::_ClearControlTreeNodeFocus();
            UiNavKit::g_ControlTreeOverlay = int(overlay);

            string rootUiPath = "O" + overlay + "/root[" + rootIx + "]";
            string uiPath = rootUiPath + (relPath.Length > 0 ? ("/" + relPath) : "");
            string displayPath = "overlay[" + overlay + "]/root[" + rootIx + "]";
            if (relPath.Length > 0) displayPath += "/" + relPath;

            UiNavKit::_SelectControlTree(controlTree, relPath, displayPath, uiPath, rootIx, overlay);
            UiNavKit::Inspectors::ControlTree::_ControlTreeExpandToUiPath(uiPath);
            UiNavKit::Inspectors::ControlTree::g_ControlTreeSelectionStatus = "Selector synced selection to ControlTree.";
            return true;
        }

        string SelectorHitSummary(const SelectorHitRow@ row, int rank = -1) {
            if (row is null) return "<null>";
            string pfx = rank >= 0 ? ("#" + rank + " ") : "";
            string idPart = row.controlId.Length > 0 ? ("#" + row.controlId) : "<no-id>";
            string pathPart = row.path.Length > 0 ? row.path : "<root>";
            vec2 sz = row.boundsMax - row.boundsMin;
            return pfx + _SelectorAppKindLabel(row.appKind) + " L" + row.layerIx + " /" + pathPart
                + " " + row.typeName + " " + idPart
                + " bounds=" + _FmtVec2(row.boundsMin) + ".." + _FmtVec2(row.boundsMax)
                + " size=" + _FmtVec2(sz);
        }

        string SelectorHitsTableText() {
            string outS = "";
            outS += "=== UiNav Builder Selector Hits ===\n";
            outS += "t_ms=" + g_SelectorLastPickAtMs + " hits=" + g_SelectorHits.Length + "\n";
            for (uint i = 0; i < g_SelectorHits.Length; ++i) {
                auto row = g_SelectorHits[i];
                if (row is null) continue;
                outS += SelectorHitSummary(row, int(i + 1)) + "\n";
            }
            return outS;
        }

    }
}
