namespace UiNavKit {
namespace Debug {

    string _MlNoteAnchorToken(CGameManialinkControl@ n, int childIx = -1) {
        if (n is null) return "<null>";
        string controlId = UiNav::ML::ControlId(n);
        if (controlId.Length > 0) return "#" + controlId;
        string classList;
        string classSel = _MlFirstClassSelector(n, classList);
        if (classSel.Length > 0) return classSel;
        string token = "@" + UiNav::ML::TypeName(n);
        if (childIx >= 0) token += "[" + childIx + "]";
        return token;
    }

    string _MlBuildAnchor(CGameManialinkFrame@ root, const string &in idxPath) {
        if (root is null) return "";
        CGameManialinkControl@ cur = root;
        string anchor = _MlNoteAnchorToken(cur, -1);
        if (idxPath.Length == 0) return anchor;

        array<string>@ parts = idxPath.Split("/");
        for (uint i = 0; i < parts.Length; ++i) {
            string part = parts[i].Trim();
            if (part.Length == 0) continue;
            int idx = Text::ParseInt(part);
            if (idx < 0) break;
            auto f = cast<CGameManialinkFrame@>(cur);
            if (f is null || uint(idx) >= f.Controls.Length) break;
            @cur = f.Controls[uint(idx)];
            if (cur is null) break;
            anchor += "/" + _MlNoteAnchorToken(cur, idx);
        }
        return anchor;
    }

    bool _MlGetActiveNotesTooltip(const string &in layerKey, const string &in anchor, CGameManialinkControl@ n, CGameManialinkFrame@ layerRoot,
                                  string &out tooltip, int &out count) {
        _MlNotesEnsureLoaded();
        tooltip = "";
        count = 0;
        for (uint i = 0; i < g_MlDebugNotes.Length; ++i) {
            auto note = g_MlDebugNotes[i];
            if (note is null) continue;
            if (note.layerKey != layerKey) continue;
            if (note.anchor != anchor) continue;
            if (!_MlNoteIsActive(note, n, layerRoot)) continue;
            string noteText = _MlNormalizeNoteText(note.text).Trim();
            if (noteText.Length == 0) continue;

            if (tooltip.Length > 0) tooltip += "\n\n";
            tooltip += noteText;
            count++;
        }
        return count > 0;
    }

    void _MlRenderNoteIndicator(const string &in layerKey, const string &in anchor, CGameManialinkControl@ n, CGameManialinkFrame@ layerRoot) {
        string tooltip;
        int count = 0;
        if (!_MlGetActiveNotesTooltip(layerKey, anchor, n, layerRoot, tooltip, count)) return;
        UI::SameLine();
        UI::Text("\\$ff0" + Icons::ExclamationTriangle + "\\$z " + count);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text("UiNav note" + (count == 1 ? "" : "s"));
            UI::Separator();
            UI::PushTextWrapPos(420.0f);
            UI::TextWrapped(tooltip);
            UI::PopTextWrapPos();
            UI::EndTooltip();
        }
    }

    bool _GetSelectedMlLayerContext(CGameManiaApp@ &out app, CGameUILayer@ &out layer, CGameManialinkFrame@ &out root) {
        @app = _GetMlManiaAppByKind(g_SelectedMlAppKind);
        @layer = null;
        @root = null;
        @layer = _GetMlLayerByIx(g_SelectedMlAppKind, g_SelectedMlLayerIx);
        if (layer is null) return false;
        if (layer is null || layer.LocalPage is null) return false;
        @root = layer.LocalPage.MainFrame;
        return root !is null;
    }

    string _MlNewNoteId(const string &in layerKey, const string &in anchor, const string &in text) {
        return Crypto::MD5(layerKey + "|" + anchor + "|" + text + "|" + Time::Now + "|" + g_MlDebugNotes.Length);
    }

    void _ClearMlSelection() {
        @g_SelectedMlNode = null;
        g_SelectedMlUiPath = "";
        g_SelectedMlPath = "";
        g_SelectedMlLayerIx = -1;
        g_SelectedMlAppKind = 0;
        _ClearMlNodeFocus();
    }

    void _SelectMl(CGameManialinkControl@ n, const string &in path, const string &in uiPath, int layerIx) {
        _ClearMlNodeFocus();
        @g_SelectedMlNode = null;
        g_SelectedMlUiPath = uiPath;
        g_SelectedMlPath = path;
        g_SelectedMlLayerIx = layerIx;
        g_SelectedMlAppKind = g_MlActiveAppKind;

        if (UiNavKit::Builder::S_LiveLayerBoundsOverlayEnabled) {
            UiNavKit::Builder::RefreshLiveLayerBoundsOverlay(false, true);
        }
    }

    void _ClearControlTreeSelection() {
        @g_SelectedControlTreeNode = null;
        g_SelectedControlTreeUiPath = "";
        g_SelectedControlTreeRootIx = -1;
        if (g_ControlTreeOverlay >= 0) g_SelectedControlTreeOverlayAtSel = uint(g_ControlTreeOverlay);
        g_SelectedControlTreePath = "";
        g_SelectedControlTreeDisplayPath = "";
    }

    void _SelectControlTree(CControlBase@ n, const string &in path, const string &in displayPath,
                            const string &in uiPath, int rootIx, uint overlayAtSelection) {
        @g_SelectedControlTreeNode = null;
        g_SelectedControlTreeUiPath = uiPath;
        g_SelectedControlTreeRootIx = rootIx;
        g_SelectedControlTreeOverlayAtSel = overlayAtSelection;
        g_SelectedControlTreePath = path;
        g_SelectedControlTreeDisplayPath = displayPath;
    }

    string _NodePathParent(const string &in rawPath) {
        string p = rawPath.Trim();
        if (p.Length == 0) return "";
        auto parts = p.Split("/");
        array<string> parent;
        if (parts.Length <= 1) return "";
        for (uint i = 0; i + 1 < parts.Length; ++i) {
            string part = parts[i].Trim();
            if (part.Length == 0) continue;
            parent.InsertLast(part);
        }
        return _JoinParts(parent, "/");
    }

    bool _TryExtractPipedPathCommand(const string &in rawSearch, string &out cmd) {
        cmd = "";
        string s = rawSearch.Trim();
        if (s.Length < 3) return false;
        if (!s.StartsWith("|") || !s.EndsWith("|")) return false;
        cmd = s.SubStr(1, s.Length - 2).Trim();
        return cmd.Length > 0;
    }

    bool _TryParseMlUiPathLike(const string &in raw, int defaultAppKind, int defaultLayerIx,
                               int &out appKind, int &out layerIx, string &out relPath, string &out uiPath, string &out err) {
        err = "";
        appKind = defaultAppKind;
        layerIx = -1;
        relPath = "";
        uiPath = "";

        string s = raw.Trim();
        while (s.StartsWith("/")) s = s.SubStr(1);
        while (s.EndsWith("/")) s = s.SubStr(0, s.Length - 1);
        if (s.Length == 0) { err = "Empty path"; return false; }

        string[] parts = s.Split("/");
        uint i = 0;

        if (parts.Length > 0) {
            string p0 = parts[0].Trim();
            if (p0 == "P") { appKind = 0; i = 1; }
            else if (p0 == "M") { appKind = 1; i = 1; }
            else if (p0 == "E") { appKind = 2; i = 1; }
        }

        if (i >= parts.Length) { err = "Missing layer segment (expected L<ix>)"; return false; }

        string layerTok = parts[i].Trim();
        if (layerTok.Length > 0 && layerTok.StartsWith("L")) {
            string layerStr = layerTok.SubStr(1).Trim();
            if (layerStr.StartsWith("[") && layerStr.EndsWith("]") && layerStr.Length > 2) {
                layerStr = layerStr.SubStr(1, layerStr.Length - 2).Trim();
            }
            layerIx = Text::ParseInt(layerStr);
            if (layerIx < 0) { err = "Invalid layer index: " + layerTok; return false; }
            i++;
        } else {
            if (defaultLayerIx < 0) { err = "Missing layer segment (expected L<ix>)"; return false; }
            layerIx = defaultLayerIx;
        }

        array<string> selParts;
        for (; i < parts.Length; ++i) {
            string part = parts[i].Trim();
            if (part.Length == 0) continue;
            selParts.InsertLast(part);
        }
        relPath = _JoinParts(selParts, "/");

        uiPath = _MlAppPrefixByKind(appKind) + "/L" + layerIx;
        if (relPath.Length > 0) uiPath += "/" + relPath;
        return true;
    }

    bool _TryBuildMlIndexPathFromNode(CGameManialinkFrame@ root, CGameManialinkControl@ node, string &out outPath, string &out err) {
        outPath = "";
        err = "";
        if (root is null) { err = "Root is null"; return false; }
        if (node is null) { err = "Node is null"; return false; }
        if (node is root) return true;

        array<int> revPath;
        CGameManialinkControl@ cur = node;
        int guard = 0;
        while (cur !is null && !(cur is root) && guard < 512) {
            guard++;
            CGameManialinkControl@ parent = null;
            try { @parent = cur.Parent; } catch { @parent = null; }
            if (parent is null) { err = "Node has no parent"; return false; }

            auto pf = cast<CGameManialinkFrame@>(parent);
            if (pf is null) { err = "Parent is not a frame"; return false; }

            int found = -1;
            try {
                for (uint i = 0; i < pf.Controls.Length; ++i) {
                    if (pf.Controls[i] is cur) { found = int(i); break; }
                }
            } catch {
                found = -1;
            }
            if (found < 0) { err = "Could not locate node index in parent"; return false; }

            revPath.InsertLast(found);
            @cur = cast<CGameManialinkControl@>(parent);
        }
        if (!(cur is root)) { err = "Node is not under root"; return false; }

        for (int i = int(revPath.Length) - 1; i >= 0; --i) {
            if (outPath.Length > 0) outPath += "/";
            outPath += tostring(revPath[uint(i)]);
        }
        return true;
    }

    bool _TryJumpToMlSelectorAnyLayer(const string &in raw, int defaultAppKind, string &out status) {
        status = "";

        string s = raw.Trim();
        while (s.StartsWith("/")) s = s.SubStr(1);
        while (s.EndsWith("/")) s = s.SubStr(0, s.Length - 1);
        if (s.Length == 0) { status = "Invalid ML selector: empty"; return false; }

        int appKind = defaultAppKind;
        string[] parts = s.Split("/");
        uint startIx = 0;
        if (parts.Length > 0) {
            string p0 = parts[0].Trim();
            if (p0 == "P") { appKind = 0; startIx = 1; }
            else if (p0 == "M") { appKind = 1; startIx = 1; }
            else if (p0 == "E") { appKind = 2; startIx = 1; }
        }

        array<string> selParts;
        for (uint i = startIx; i < parts.Length; ++i) {
            string part = parts[i].Trim();
            if (part.Length == 0) continue;
            selParts.InsertLast(part);
        }
        string selector = _JoinParts(selParts, "/");
        if (selector.Length == 0) { status = "Invalid ML selector: empty"; return false; }

        uint layersLen = _GetMlLayerCount(appKind);
        for (uint li = 0; li < layersLen; ++li) {
            auto root = _GetMlRootByLayerIx(int(li), appKind);
            if (root is null) continue;

            CGameManialinkControl@ found = UiNav::ML::ResolveSelector(selector, root);
            if (found is null) continue;

            string indexPath = "";
            string pathErr = "";
            if (!_TryBuildMlIndexPathFromNode(root, found, indexPath, pathErr)) continue;

            string uiPath = _MlAppPrefixByKind(appKind) + "/L" + li;
            if (indexPath.Length > 0) uiPath += "/" + indexPath;

            g_MlUnifiedSourceSelectPending = appKind;

            _ClearMlNodeFocus();
            @g_SelectedMlNode = null;
            g_SelectedMlAppKind = appKind;
            g_SelectedMlLayerIx = int(li);
            g_SelectedMlPath = indexPath;
            g_SelectedMlUiPath = uiPath;

            g_MlViewLayerIndex = int(li);
            g_MlFlatDirty = true;

            g_MlNodeFocusActive = true;
            g_MlNodeFocusAppKind = appKind;
            g_MlNodeFocusLayerIx = int(li);
            g_MlNodeFocusPath = indexPath;
            g_MlNodeFocusUiPath = uiPath;
            g_MlNodeFocusStatus = "Jumped to selector: " + selector + " -> " + uiPath;

            status = g_MlNodeFocusStatus;
            return true;
        }

        status = "Could not resolve ML selector: " + selector;
        return false;
    }

    bool _TryJumpToMlUiPathLike(const string &in raw, string &out status) {
        status = "";

        int defaultLayerIx = g_MlViewLayerIndex >= 0 ? g_MlViewLayerIndex : (g_SelectedMlLayerIx >= 0 ? g_SelectedMlLayerIx : -1);

        int appKind = 0;
        int layerIx = -1;
        string selector = "";
        string uiPathRaw = "";
        string err = "";
        if (!_TryParseMlUiPathLike(raw, g_MlActiveAppKind, defaultLayerIx, appKind, layerIx, selector, uiPathRaw, err)) {
            return _TryJumpToMlSelectorAnyLayer(raw, g_MlActiveAppKind, status);
        }

        auto root = _GetMlRootByLayerIx(layerIx, appKind);
        if (root is null) {
            status = "Could not resolve ML layer root: " + _MlAppPrefixByKind(appKind) + "/L" + layerIx;
            return false;
        }

        CGameManialinkControl@ node = (selector.Length == 0) ? cast<CGameManialinkControl@>(root) : UiNav::ML::ResolveSelector(selector, root);
        if (node is null) {
            status = "Could not resolve ML selector: " + uiPathRaw;
            return false;
        }

        string indexPath = "";
        string pathErr = "";
        if (!_TryBuildMlIndexPathFromNode(root, node, indexPath, pathErr)) {
            status = "Could not build ML index path: " + pathErr;
            return false;
        }

        string uiPath = _MlAppPrefixByKind(appKind) + "/L" + layerIx;
        if (indexPath.Length > 0) uiPath += "/" + indexPath;

        g_MlUnifiedSourceSelectPending = appKind;

        _ClearMlNodeFocus();
        @g_SelectedMlNode = null;
        g_SelectedMlAppKind = appKind;
        g_SelectedMlLayerIx = layerIx;
        g_SelectedMlPath = indexPath;
        g_SelectedMlUiPath = uiPath;

        g_MlViewLayerIndex = layerIx;
        g_MlFlatDirty = true;

        g_MlNodeFocusActive = true;
        g_MlNodeFocusAppKind = appKind;
        g_MlNodeFocusLayerIx = layerIx;
        g_MlNodeFocusPath = indexPath;
        g_MlNodeFocusUiPath = uiPath;
        g_MlNodeFocusStatus = (selector.Length > 0 && selector != indexPath)
            ? ("Jumped via selector: " + selector + " -> " + uiPath)
            : ("Jumped to path: " + uiPath);

        status = g_MlNodeFocusStatus;
        return true;
    }

    bool _TryParseControlTreeUiPathLike(const string &in raw, uint defaultOverlay, int defaultRootIx,
                                        uint &out overlay, int &out rootIx, string &out relPath,
                                        string &out uiPath, string &out displayPath, string &out err) {
        err = "";
        overlay = defaultOverlay;
        rootIx = -1;
        relPath = "";
        uiPath = "";
        displayPath = "";

        string s = raw.Trim();
        while (s.StartsWith("/")) s = s.SubStr(1);
        while (s.EndsWith("/")) s = s.SubStr(0, s.Length - 1);
        if (s.Length == 0) { err = "Empty path"; return false; }

        if (s.StartsWith("O")) {
            int len = int(s.Length);
            int j = 1;
            while (j < len) {
                uint c = s[j];
                if (c < 48 || c > 57) break;
                j++;
            }
            if (j <= 1) { err = "Invalid overlay prefix"; return false; }
            int ov = Text::ParseInt(s.SubStr(1, j - 1));
            if (ov < 0) { err = "Invalid overlay index"; return false; }
            overlay = uint(ov);
            s = s.SubStr(j).Trim();
            if (s.StartsWith("/")) s = s.SubStr(1);
        } else if (s.StartsWith("overlay[")) {
            int end = s.IndexOf("]");
            if (end < 0) { err = "Invalid overlay[...] segment"; return false; }
            int ov = Text::ParseInt(s.SubStr(7, end - 7));
            if (ov < 0) { err = "Invalid overlay index"; return false; }
            overlay = uint(ov);
            s = s.SubStr(end + 1).Trim();
            if (s.StartsWith("/")) s = s.SubStr(1);
        } else if (s.StartsWith("overlay=")) {
            string rest = s.SubStr(8).Trim();
            int rlen = int(rest.Length);
            int j = 0;
            while (j < rlen) {
                uint c = rest[j];
                if (c < 48 || c > 57) break;
                j++;
            }
            if (j == 0) { err = "Invalid overlay= segment"; return false; }
            int ov = Text::ParseInt(rest.SubStr(0, j));
            if (ov < 0) { err = "Invalid overlay index"; return false; }
            overlay = uint(ov);
            rest = rest.SubStr(j).Trim();
            if (rest.StartsWith("/")) rest = rest.SubStr(1);
            s = rest;
        }

        if (s.StartsWith("root[")) {
            int end = s.IndexOf("]");
            if (end < 0) { err = "Invalid root[...] segment"; return false; }
            rootIx = Text::ParseInt(s.SubStr(5, end - 5));
            if (rootIx < 0) { err = "Invalid root index"; return false; }
            s = s.SubStr(end + 1).Trim();
            if (s.StartsWith("/")) s = s.SubStr(1);
        } else if (defaultRootIx >= 0) {
            rootIx = defaultRootIx;
        } else {
            err = "Missing root segment (expected root[<ix>])";
            return false;
        }

        array<string> selParts;
        if (s.Length > 0) {
            auto parts = s.Split("/");
            for (uint i = 0; i < parts.Length; ++i) {
                string part = parts[i].Trim();
                if (part.Length == 0) continue;
                selParts.InsertLast(part);
            }
        }
        relPath = _JoinParts(selParts, "/");

        uiPath = "O" + overlay + "/root[" + rootIx + "]";
        displayPath = "overlay[" + overlay + "]/root[" + rootIx + "]";
        if (relPath.Length > 0) {
            uiPath += "/" + relPath;
            displayPath += "/" + relPath;
        }
        return true;
    }

    bool _TryJumpToControlTreeSelectorAnyRoot(const string &in raw, string &out status) {
        status = "";

        string selector = raw.Trim();
        while (selector.StartsWith("/")) selector = selector.SubStr(1);
        while (selector.EndsWith("/")) selector = selector.SubStr(0, selector.Length - 1);
        if (selector.Length == 0) { status = "Invalid ControlTree selector: empty"; return false; }

        CGameCtnApp@ app = GetApp();
        if (app is null || app.Viewport is null) { status = "No viewport"; return false; }
        auto vp = cast<CDx11Viewport>(app.Viewport);
        if (vp is null) { status = "No Dx11 viewport"; return false; }

        uint startOverlay = 0;
        uint endOverlay = vp.Overlays.Length;
        if (g_ControlTreeOverlay >= 0) {
            if (uint(g_ControlTreeOverlay) >= endOverlay) { status = "Overlay index out of range"; return false; }
            startOverlay = uint(g_ControlTreeOverlay);
            endOverlay = startOverlay + 1;
        }

        for (uint ov = startOverlay; ov < endOverlay; ++ov) {
            auto found = ResolvePathAnyRoot(selector, ov, 64);
            if (found is null) continue;

            int rootIx = -1;
            string relPath = "";
            if (!_FindControlTreePathForControlAtOverlay(found, ov, rootIx, relPath) || rootIx < 0) continue;

            string uiPath = "O" + ov + "/root[" + rootIx + "]";
            string displayPath = "overlay[" + ov + "]/root[" + rootIx + "]";
            if (relPath.Length > 0) { uiPath += "/" + relPath; displayPath += "/" + relPath; }

            _ClearControlTreeNodeFocus();
            g_ControlTreeOverlay = int(ov);
            _SelectControlTree(found, relPath, displayPath, uiPath, rootIx, ov);
            _ControlTreeExpandToUiPath(uiPath);
            g_ControlTreeSelectionStatus = "Jumped to selector: " + selector + " -> " + uiPath;
            status = g_ControlTreeSelectionStatus;
            return true;
        }

        status = "Could not resolve ControlTree selector: " + selector;
        return false;
    }

    bool _TryJumpToControlTreeUiPathLike(const string &in raw, string &out status) {
        status = "";

        uint defaultOverlay = 16;
        if (g_ControlTreeOverlay >= 0) defaultOverlay = uint(g_ControlTreeOverlay);
        else if (g_SelectedControlTreeUiPath.Length > 0) defaultOverlay = g_SelectedControlTreeOverlayAtSel;

        int defaultRootIx = -1;
        if (g_SelectedControlTreeRootIx >= 0) defaultRootIx = g_SelectedControlTreeRootIx;
        else if (g_ControlTreeNodeFocusRootIx >= 0) defaultRootIx = g_ControlTreeNodeFocusRootIx;

        uint overlay = 0;
        int rootIx = -1;
        string selector = "";
        string uiPathRaw = "";
        string displayPathRaw = "";
        string err = "";
        if (!_TryParseControlTreeUiPathLike(raw, defaultOverlay, defaultRootIx, overlay, rootIx, selector, uiPathRaw, displayPathRaw, err)) {
            return _TryJumpToControlTreeSelectorAnyRoot(raw, status);
        }

        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene) || scene is null) {
            status = "No scene for overlay " + overlay;
            return false;
        }
        if (rootIx < 0 || uint(rootIx) >= scene.Mobils.Length) {
            status = "Root index out of range: " + rootIx;
            return false;
        }
        auto root = _RootFromMobil(scene, uint(rootIx));
        if (root is null) {
            status = "Root is null: root[" + rootIx + "]";
            return false;
        }

        CControlBase@ rootNode = cast<CControlBase@>(root);
        if (rootNode is null) {
            status = "Root is not a CControlBase";
            return false;
        }

        CControlBase@ node = (selector.Length == 0) ? rootNode : UiNav::CT::ResolveSelector(selector, rootNode);
        if (node is null) {
            status = "Could not resolve ControlTree selector: " + uiPathRaw;
            return false;
        }

        string relPath = "";
        if (node !is rootNode) {
            string found = "";
            if (!_FindControlTreePathRec(rootNode, node, "", found)) {
                status = "Could not build ControlTree index path.";
                return false;
            }
            relPath = found;
        }

        string uiPath = "O" + overlay + "/root[" + rootIx + "]";
        string displayPath = "overlay[" + overlay + "]/root[" + rootIx + "]";
        if (relPath.Length > 0) {
            uiPath += "/" + relPath;
            displayPath += "/" + relPath;
        }

        _ClearControlTreeNodeFocus();
        g_ControlTreeOverlay = int(overlay);
        _SelectControlTree(node, relPath, displayPath, uiPath, rootIx, overlay);
        _ControlTreeExpandToUiPath(uiPath);
        g_ControlTreeSelectionStatus = (selector.Length > 0 && selector != relPath)
            ? ("Jumped via selector: " + selector + " -> " + uiPath)
            : ("Jumped to path: " + uiPath);

        status = g_ControlTreeSelectionStatus;
        return true;
    }

    bool _HandleMlSearchPathCommand() {
        string raw = g_MlSearch.Trim();
        if (raw.Length == 0) return false;

        string cmd = "";
        if (!_TryExtractPipedPathCommand(raw, cmd)) {
            if (raw.IndexOf("/") < 0) return false;
            string s = raw;
            while (s.StartsWith("/")) s = s.SubStr(1);
            bool looksLike = s.StartsWith("#")
                || s.StartsWith("*")
                || s.StartsWith("L")
                || s.StartsWith("P/")
                || s.StartsWith("M/")
                || s.StartsWith("E/");
            if (!looksLike) {
                uint c0 = s[0];
                looksLike = (c0 >= 48 && c0 <= 57);
            }
            if (!looksLike) return false;
            cmd = raw;
        }

        string status;
        _TryJumpToMlUiPathLike(cmd, status);
        g_MlSearch = "";
        return true;
    }

    bool _HandleControlTreeSearchPathCommand() {
        string raw = g_ControlTreeSearch.Trim();
        if (raw.Length == 0) return false;

        string cmd = "";
        if (!_TryExtractPipedPathCommand(raw, cmd)) {
            if (raw.IndexOf("/") < 0) return false;
            string s = raw;
            while (s.StartsWith("/")) s = s.SubStr(1);
            bool looksLike = s.StartsWith("#")
                || s.StartsWith("*")
                || s.StartsWith("O")
                || s.StartsWith("overlay[")
                || s.StartsWith("overlay=")
                || s.StartsWith("root[");
            if (!looksLike) {
                uint c0 = s[0];
                looksLike = (c0 >= 48 && c0 <= 57);
            }
            if (!looksLike) return false;
            cmd = raw;
        }

        string status;
        _TryJumpToControlTreeUiPathLike(cmd, status);
        g_ControlTreeSearch = "";
        return true;
    }

    string _MlNodeFocusParentPathDisplay() {
        if (!g_MlNodeFocusActive || g_MlNodeFocusLayerIx < 0) return "";
        string base = _MlAppPrefixByKind(g_MlNodeFocusAppKind) + "/L" + g_MlNodeFocusLayerIx;
        string parentPath = _NodePathParent(g_MlNodeFocusPath);
        if (parentPath.Length > 0) return base + "/" + parentPath;
        return base;
    }

    string _ControlTreeNodeFocusParentPathDisplay() {
        if (!g_ControlTreeNodeFocusActive || g_ControlTreeNodeFocusRootIx < 0) return "";
        string base = "overlay[" + g_ControlTreeNodeFocusOverlay + "]/root[" + g_ControlTreeNodeFocusRootIx + "]";
        string parentPath = _NodePathParent(g_ControlTreeNodeFocusPath);
        if (parentPath.Length > 0) return base + "/" + parentPath;
        return base;
    }

    void _PersistMlNodeFocusToTreeOpen() {
        if (!g_MlNodeFocusActive || g_MlNodeFocusLayerIx < 0) return;

        string uiPath = _MlAppPrefixByKind(g_MlNodeFocusAppKind) + "/L" + g_MlNodeFocusLayerIx;
        _SetMlTreeOpen(uiPath, true);

        if (g_MlNodeFocusPath.Length == 0) return;

        auto parts = g_MlNodeFocusPath.Split("/");
        for (uint i = 0; i < parts.Length; ++i) {
            string part = parts[i].Trim();
            if (part.Length == 0) continue;
            uiPath += "/" + part;
            _SetMlTreeOpen(uiPath, true);
        }
    }

    void _ClearMlNodeFocus() {
        _PersistMlNodeFocusToTreeOpen();
        g_MlNodeFocusActive = false;
        g_MlNodeFocusAppKind = 0;
        g_MlNodeFocusLayerIx = -1;
        g_MlNodeFocusPath = "";
        g_MlNodeFocusUiPath = "";
    }

    bool _FocusSelectedMlNode() {
        if (g_SelectedMlLayerIx < 0 || g_SelectedMlUiPath.Length == 0) return false;

        CGameManialinkFrame@ root = null;
        CGameManialinkControl@ node = null;
        if (!_ResolveMlNodeByPath(g_SelectedMlAppKind, g_SelectedMlLayerIx, g_SelectedMlPath, root, node) || node is null) {
            return false;
        }

        g_MlNodeFocusActive = true;
        g_MlNodeFocusAppKind = g_SelectedMlAppKind;
        g_MlNodeFocusLayerIx = g_SelectedMlLayerIx;
        g_MlNodeFocusPath = g_SelectedMlPath;
        g_MlNodeFocusUiPath = g_SelectedMlUiPath;
        g_MlViewLayerIndex = g_SelectedMlLayerIx;
        return true;
    }

    void _ClearControlTreeNodeFocus() {
        g_ControlTreeNodeFocusActive = false;
        g_ControlTreeNodeFocusOverlay = 16;
        g_ControlTreeNodeFocusRootIx = -1;
        g_ControlTreeNodeFocusPath = "";
        g_ControlTreeNodeFocusUiPath = "";
    }

    bool _FocusSelectedControlTreeNode() {
        if (g_SelectedControlTreeRootIx < 0 || g_SelectedControlTreeUiPath.Length == 0) return false;

        CControlBase@ node = null;
        if (!_ResolveControlTreeNodeByPath(g_SelectedControlTreeOverlayAtSel, g_SelectedControlTreeRootIx, g_SelectedControlTreePath, node) || node is null) {
            return false;
        }

        g_ControlTreeNodeFocusActive = true;
        g_ControlTreeNodeFocusOverlay = g_SelectedControlTreeOverlayAtSel;
        g_ControlTreeNodeFocusRootIx = g_SelectedControlTreeRootIx;
        g_ControlTreeNodeFocusPath = g_SelectedControlTreePath;
        g_ControlTreeNodeFocusUiPath = g_SelectedControlTreeUiPath;
        g_ControlTreeOverlay = int(g_SelectedControlTreeOverlayAtSel);
        _SetControlTreeTreeOpen(g_ControlTreeNodeFocusUiPath, true);
        return true;
    }

    CGameManialinkControl@ _ResolveSelectedMlNode(string &out err) {
        err = "";
        if (g_SelectedMlUiPath.Length == 0) { err = "No selection"; return null; }
        if (g_SelectedMlLayerIx < 0) { err = "No selected layer"; return null; }

        auto layer = _GetMlLayerByIx(g_SelectedMlAppKind, g_SelectedMlLayerIx);
        if (layer is null || layer.LocalPage is null || layer.LocalPage.MainFrame is null) {
            err = "Layer has no LocalPage/MainFrame";
            return null;
        }

        CGameManialinkControl@ cur = layer.LocalPage.MainFrame;
        if (g_SelectedMlPath.Length == 0) return cur;

        string[] parts = g_SelectedMlPath.Split("/");
        for (uint i = 0; i < parts.Length; ++i) {
            string part = parts[i].Trim();
            if (part.Length == 0) continue;
            int idx = Text::ParseInt(part);
            if (idx < 0) { err = "Invalid path segment: " + part; return null; }

            auto f = cast<CGameManialinkFrame@>(cur);
            if (f is null) { err = "Path points into non-frame"; return null; }
            if (uint(idx) >= f.Controls.Length) { err = "Path index out of range: " + part; return null; }

            @cur = f.Controls[uint(idx)];
            if (cur is null) { err = "Null child at index: " + part; return null; }
        }
        return cur;
    }

    CControlBase@ _ResolveSelectedControlTreeNode(string &out err) {
        err = "";
        if (g_SelectedControlTreeUiPath.Length == 0) { err = "No selection"; return null; }

        uint overlay = g_SelectedControlTreeOverlayAtSel;
        if (g_SelectedControlTreeRootIx >= 0) {
            CScene2d@ scene;
            if (!_GetScene2d(overlay, scene)) { err = "No scene for overlay " + overlay; return null; }
            if (uint(g_SelectedControlTreeRootIx) >= scene.Mobils.Length) { err = "Root index out of range"; return null; }
            CControlFrame@ root = _RootFromMobil(scene, uint(g_SelectedControlTreeRootIx));
            if (root is null) { err = "Root is null"; return null; }

            CControlBase@ cur = cast<CControlBase@>(root);
            if (g_SelectedControlTreePath.Length == 0) return cur;

            string[] parts = g_SelectedControlTreePath.Split("/");
            for (uint i = 0; i < parts.Length; ++i) {
                string part = parts[i].Trim();
                if (part.Length == 0) continue;
                int idx = Text::ParseInt(part);
                if (idx < 0) { err = "Invalid path segment: " + part; return null; }

                uint len = _ChildrenLen(cur);
                if (uint(idx) >= len) { err = "Path index out of range: " + part; return null; }
                CControlBase@ ch = _ChildAt(cur, uint(idx));
                if (ch is null) { err = "Null child at index: " + part; return null; }
                @cur = ch;
            }
            return cur;
        }

        if (g_SelectedControlTreePath.Length > 0) {
            auto found = ResolvePathAnyRoot(g_SelectedControlTreePath, overlay, 64);
            if (found !is null) return found;
        }

        err = "Could not resolve selection";
        return null;
    }

    bool _ResolveMlNodeByPath(int appKind, int layerIx, const string &in path, CGameManialinkFrame@ &out root, CGameManialinkControl@ &out node) {
        @root = _GetMlRootByLayerIx(layerIx, appKind);
        @node = null;
        if (root is null) return false;

        @node = root;
        if (path.Length == 0) return true;

        string[] parts = path.Split("/");
        for (uint i = 0; i < parts.Length; ++i) {
            string part = parts[i].Trim();
            if (part.Length == 0) continue;
            int idx = Text::ParseInt(part);
            if (idx < 0) return false;

            auto f = cast<CGameManialinkFrame@>(node);
            if (f is null) return false;
            if (uint(idx) >= f.Controls.Length) return false;

            @node = f.Controls[uint(idx)];
            if (node is null) return false;
        }
        return true;
    }

    bool _ResolveControlTreeNodeByPath(uint overlay, int rootIx, const string &in relPath, CControlBase@ &out node) {
        @node = null;
        if (rootIx < 0) return false;
        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene) || scene is null) return false;
        if (uint(rootIx) >= scene.Mobils.Length) return false;

        CControlFrame@ root = _RootFromMobil(scene, uint(rootIx));
        if (root is null) return false;

        @node = cast<CControlBase@>(root);
        if (relPath.Length == 0) return true;

        string[] parts = relPath.Split("/");
        for (uint i = 0; i < parts.Length; ++i) {
            string part = parts[i].Trim();
            if (part.Length == 0) continue;
            int idx = Text::ParseInt(part);
            if (idx < 0) return false;
            uint len = _ChildrenLen(node);
            if (uint(idx) >= len) return false;
            @node = _ChildAt(node, uint(idx));
            if (node is null) return false;
        }
        return true;
    }

    void _OpenNodExplorer(CGameManialinkControl@ n) {
        if (n is null) return;
#if SIG_DEVELOPER
        ExploreNod(n);
#endif
    }

    void _OpenNodExplorer(CControlBase@ n) {
        if (n is null) return;
#if SIG_DEVELOPER
        ExploreNod(n);
#endif
    }

    dictionary g_MlTreeOpen;
    dictionary g_ControlTreeTreeOpen;

    void _SetMlTreeOpen(const string &in uiPath, bool open) {
        if (uiPath.Length == 0) return;
        bool prev = false;
        bool had = g_MlTreeOpen.Get(uiPath, prev);
        g_MlTreeOpen.Set(uiPath, open);
        if (!had || prev != open) {
            g_MlFlatDirty = true;
            g_MlTreeOpenEpoch++;
        }
    }

    bool _IsMlTreeOpen(const string &in uiPath) {
        if (uiPath.Length == 0) return false;
        bool open = false;
        if (g_MlTreeOpen.Exists(uiPath)) {
            g_MlTreeOpen.Get(uiPath, open);
        }
        return open;
    }

    void _SetControlTreeTreeOpen(const string &in uiPath, bool open) {
        if (uiPath.Length == 0) return;
        bool prev = false;
        bool had = g_ControlTreeTreeOpen.Get(uiPath, prev);
        g_ControlTreeTreeOpen.Set(uiPath, open);
        if (!had || prev != open) g_ControlTreeFlatDirty = true;
    }

    bool _IsControlTreeTreeOpen(const string &in uiPath) {
        if (uiPath.Length == 0) return false;
        bool open = false;
        if (g_ControlTreeTreeOpen.Exists(uiPath)) {
            g_ControlTreeTreeOpen.Get(uiPath, open);
        }
        return open;
    }

    void _NodButton(const string &in label, const vec2 &in size, bool &out leftPressed, bool &out rightPressed) {
        UI::PushStyleColor(UI::Col::Button, vec4(0.16f, 0.36f, 0.62f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.22f, 0.46f, 0.76f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.12f, 0.30f, 0.52f, 1.0f));
        leftPressed = UI::Button(label, size);
        bool hovered = UI::IsItemHovered();
        rightPressed = hovered && UI::IsMouseClicked(UI::MouseButton::Right);
        if (hovered) UI::SetTooltip("Left click: open NOD\nRight click: open parent in NOD");
        UI::PopStyleColor(3);
    }

    const float kTreeActionBtnWidth = 48.0f;
    const float kTreeActionBtnHeight = 11.0f;
    const float kTreeActionBtnFontSize = 10.5f;
    const float kTreeToggleBtnWidth = 10.0f;
    const float kTreeToggleBtnHeight = 12.0f;
    const float kTreeToggleBtnFontSize = 12.0f;

    void _DrawStackedTreeActionButtons(const string &in idBase, bool &out selectPressed,
                                       bool &out nodPressed, bool &out nodParentPressed) {
        selectPressed = false;
        nodPressed = false;
        nodParentPressed = false;

        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2.0f, 1.0f));
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2.0f, 1.0f));
        UI::PushFontSize(kTreeActionBtnFontSize);
        UI::BeginGroup();
        selectPressed = UI::Button("Select##sel-" + idBase, vec2(kTreeActionBtnWidth, kTreeActionBtnHeight));
        _NodButton("Nod##nod-" + idBase, vec2(kTreeActionBtnWidth, kTreeActionBtnHeight), nodPressed, nodParentPressed);
        UI::EndGroup();
        UI::PopFontSize();
        UI::PopStyleVar(2);
    }

    bool _OpenMlParentNodExplorer(int appKind, int layerIx, const string &in path) {
        CGameManialinkFrame@ root = null;
        CGameManialinkControl@ node = null;
        string parentPath = _NodePathParent(path);
        if (!_ResolveMlNodeByPath(appKind, layerIx, parentPath, root, node) || node is null) return false;
        _OpenNodExplorer(node);
        return true;
    }

    bool _OpenControlTreeParentNodExplorer(uint overlay, int rootIx, const string &in relPath) {
        CControlBase@ node = null;
        string parentPath = _NodePathParent(relPath);
        if (!_ResolveControlTreeNodeByPath(overlay, rootIx, parentPath, node) || node is null) return false;
        _OpenNodExplorer(node);
        return true;
    }

    void _DrawStackedTreeActionButtonsSpacer() {
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2.0f, 1.0f));
        UI::BeginGroup();
        UI::Dummy(vec2(kTreeActionBtnWidth, kTreeActionBtnHeight));
        UI::Dummy(vec2(kTreeActionBtnWidth, kTreeActionBtnHeight));
        UI::EndGroup();
        UI::PopStyleVar();
    }

    bool _DrawTreeToggleButton(const string &in idBase, bool isOpen, bool enabled = true) {
        if (!enabled) {
            UI::Dummy(vec2(kTreeToggleBtnWidth, kTreeToggleBtnHeight));
            return false;
        }

        UI::PushID("tree-toggle-" + idBase);
        UI::PushFontSize(kTreeToggleBtnFontSize);
        UI::Text(isOpen ? Icons::ChevronDown : Icons::ChevronRight);
        bool hovered = UI::IsItemHovered();
        bool pressed = hovered && UI::IsMouseClicked(UI::MouseButton::Left);
        UI::PopFontSize();
        if (hovered) {
            UI::SetMouseCursor(UI::MouseCursor::Hand);
            UI::SetTooltip(isOpen ? "Collapse" : "Expand");
        }
        UI::PopID();
        return pressed;
    }

    void _TreeRowMouseActions(bool hovered, bool canOpen, bool &out openRequested, bool &out selectRequested) {
        openRequested = false;
        selectRequested = false;
        if (!hovered) return;

        if (canOpen && UI::IsMouseClicked(UI::MouseButton::Left)) {
            openRequested = true;
        }
        if (UI::IsMouseClicked(UI::MouseButton::Right)) {
            selectRequested = true;
        }
    }

    string _TypeColorCode(const string &in typeName) {
        string low = typeName.ToLower();
        if (low.Contains("frame")) return "\\$9fd";
        if (low.Contains("label") || low.Contains("text")) return "\\$bff";
        if (low.Contains("quad") || low.Contains("sprite") || low.Contains("image")) return "\\$fcb";
        if (low.Contains("entry") || low.Contains("input")) return "\\$fd8";
        if (low.Contains("gauge") || low.Contains("meter") || low.Contains("progress")) return "\\$fc8";
        return "\\$ddd";
    }

    string _ColorizeTypeName(const string &in typeName) {
        if (typeName.Length == 0) return "<unknown>";
        return _TypeColorCode(typeName) + typeName + "\\$z";
    }

    class _MlNodeDataEntry {
        uint epoch = 0;
        uint stampMs = 0;
        string id;
        string type;
        string label;
        bool visible = true;
        bool hasText = false;
        string text;
        bool hasClasses = false;
        string classes;
    }

    class _ControlTreeNodeDataEntry {
        uint epoch = 0;
        uint stampMs = 0;
        string type;
        string label;
        bool hasId = false;
        string id;
        bool hasVisible = false;
        bool visible = true;
        bool hasText = false;
        string text;
    }

    dictionary g_MlNodeDataCache;
    array<string> g_MlNodeDataCacheKeys;
    dictionary g_ControlTreeNodeDataCache;
    array<string> g_ControlTreeNodeDataCacheKeys;
    const uint kTreeNodeDataCacheMax = 12000;

    class _MlLayerNameCacheEntry {
        uint epoch = 0;
        CGameUILayer@ layer = null;
        string name;
    }

    dictionary g_MlLayerNameCache;

    string _TrimTreeText(const string &in raw) {
        string t = raw;
        if (t.Length > 60) t = t.SubStr(0, 60) + "...";
        return t;
    }

    bool _IsAllDigitsForTreeLabel(const string &in raw) {
        string s = raw.Trim();
        if (s.Length == 0) return false;
        for (int i = 0; i < int(s.Length); ++i) {
            string ch = s.SubStr(i, 1);
            if (ch < "0" || ch > "9") return false;
        }
        return true;
    }

    // ControlTree nodes often have no IdName; use the last UI path segment as a stable hint.
    // Examples:
    // - "O16/root[4263]" -> "4263"
    // - "O16/root[0]/4/1" -> "1"
    string _ControlTreeFallbackIdFromUiPath(const string &in uiPath) {
        string last = uiPath.Trim();
        if (last.Length == 0) return "";

        int slash = last.LastIndexOf("/");
        if (slash >= 0) last = last.SubStr(slash + 1).Trim();
        if (last.Length == 0) return "";

        if (_IsAllDigitsForTreeLabel(last)) return last;

        int lb = last.IndexOf("[");
        int rb = last.IndexOf("]");
        if (lb >= 0 && rb > lb + 1) {
            string inner = last.SubStr(lb + 1, rb - (lb + 1)).Trim();
            if (_IsAllDigitsForTreeLabel(inner)) return inner;
        }

        return "";
    }

    // NOTE: ImGui uses "##" to separate the visible label from an internal ID.
    // Tree rows append their own "##id" suffix, so avoid creating a "##" sequence
    // in the visible label itself (e.g. when IdName is "#2").
    string _TreeLabelIdSuffix(const string &in rawId) {
        string id = rawId.Trim();
        if (id.Length == 0) return "";
        if (id.StartsWith("#")) return " " + id;
        return " #" + id;
    }

    void _MlNodeDataCacheInsert(const string &in key, _MlNodeDataEntry@ e) {
        bool exists = g_MlNodeDataCache.Exists(key);
        g_MlNodeDataCache.Set(key, @e);
        if (!exists) {
            g_MlNodeDataCacheKeys.InsertLast(key);
            if (g_MlNodeDataCacheKeys.Length > kTreeNodeDataCacheMax) {
                string victim = g_MlNodeDataCacheKeys[0];
                g_MlNodeDataCacheKeys.RemoveAt(0);
                g_MlNodeDataCache.Delete(victim);
            }
        }
    }

    void _ControlTreeNodeDataCacheInsert(const string &in key, _ControlTreeNodeDataEntry@ e) {
        bool exists = g_ControlTreeNodeDataCache.Exists(key);
        g_ControlTreeNodeDataCache.Set(key, @e);
        if (!exists) {
            g_ControlTreeNodeDataCacheKeys.InsertLast(key);
            if (g_ControlTreeNodeDataCacheKeys.Length > kTreeNodeDataCacheMax) {
                string victim = g_ControlTreeNodeDataCacheKeys[0];
                g_ControlTreeNodeDataCacheKeys.RemoveAt(0);
                g_ControlTreeNodeDataCache.Delete(victim);
            }
        }
    }

    void _MlNodeDataCacheClear() {
        g_MlNodeDataCache.DeleteAll();
        g_MlNodeDataCacheKeys.Resize(0);
    }

    void _ControlTreeNodeDataCacheClear() {
        g_ControlTreeNodeDataCache.DeleteAll();
        g_ControlTreeNodeDataCacheKeys.Resize(0);
    }

    _MlNodeDataEntry@ _MlNodeData(CGameManialinkControl@ n, const string &in uiPath, bool needText = false, bool needClasses = false, bool needVisible = false) {
        if (n is null) return null;

        uint epoch = g_MlSearchCacheEpoch;
        uint now = Time::Now;
        uint ttl = S_DebugTreeNodeCacheTtlMs;
        string key = uiPath;

        _MlNodeDataEntry@ e;
        bool valid = false;
        if (g_MlNodeDataCache.Get(key, @e) && e !is null) {
            uint age = now - e.stampMs;
            bool ttlOk = (ttl == 0 || age <= ttl);
            if (ttlOk && e.epoch == epoch) valid = true;
        }

        if (!valid || e is null) {
            @e = _MlNodeDataEntry();
            e.epoch = epoch;
            e.stampMs = now;
            e.id = n.ControlId;
            e.type = UiNav::ML::TypeName(n);
            e.label = _ColorizeTypeName(e.type);
            e.label += _TreeLabelIdSuffix(e.id);
            if (S_DebugTreeInlineText || needText) {
                e.text = UiNav::CleanUiFormatting(UiNav::ML::ReadText(n));
                e.hasText = true;
                if (S_DebugTreeInlineText && e.text.Length > 0) {
                    e.label += " | \"" + _TrimTreeText(e.text) + "\"";
                }
            }
            if (needClasses) {
                auto classes = n.ControlClasses;
                for (uint c = 0; c < classes.Length; ++c) {
                    string cc = classes[c].Trim().ToLower();
                    if (cc.Length == 0) continue;
                    if (e.classes.Length > 0) e.classes += " ";
                    e.classes += cc;
                }
                e.hasClasses = true;
            }
            if (needVisible) {
                e.visible = n.Visible;
            }
            _MlNodeDataCacheInsert(key, e);
            return e;
        }

        if ((S_DebugTreeInlineText || needText) && !e.hasText) {
            e.text = UiNav::CleanUiFormatting(UiNav::ML::ReadText(n));
            e.hasText = true;
            if (S_DebugTreeInlineText && e.text.Length > 0 && !e.label.Contains(" | \"")) {
                e.label += " | \"" + _TrimTreeText(e.text) + "\"";
            }
            e.stampMs = now;
        }
        if (needClasses && !e.hasClasses) {
            auto classes = n.ControlClasses;
            for (uint c = 0; c < classes.Length; ++c) {
                string cc = classes[c].Trim().ToLower();
                if (cc.Length == 0) continue;
                if (e.classes.Length > 0) e.classes += " ";
                e.classes += cc;
            }
            e.hasClasses = true;
            e.stampMs = now;
        }
        if (needVisible) {
            e.visible = n.Visible;
        }
        return e;
    }

    _ControlTreeNodeDataEntry@ _ControlTreeNodeData(CControlBase@ n, const string &in uiPath, bool needText = false, bool needVisible = false, bool needId = false) {
        if (n is null) return null;

        uint epoch = g_ControlTreeSearchCacheEpoch;
        uint now = Time::Now;
        uint ttl = S_DebugTreeNodeCacheTtlMs;
        string key = uiPath;

        _ControlTreeNodeDataEntry@ e;
        bool valid = false;
        if (g_ControlTreeNodeDataCache.Get(key, @e) && e !is null) {
            uint age = now - e.stampMs;
            bool ttlOk = (ttl == 0 || age <= ttl);
            if (ttlOk && e.epoch == epoch) valid = true;
        }

        if (!valid || e is null) {
            @e = _ControlTreeNodeDataEntry();
            e.epoch = epoch;
            e.stampMs = now;
            e.type = NodeTypeName(n);
            e.label = _ColorizeTypeName(e.type);
            string idNameDisplay = n.IdName.Trim();
            if (idNameDisplay.Length == 0) {
                idNameDisplay = _ControlTreeFallbackIdFromUiPath(uiPath);
                if (idNameDisplay.Length == 0) idNameDisplay = "?";
            }
            e.label += _TreeLabelIdSuffix(idNameDisplay);
            if (S_DebugTreeInlineText || needText) {
                e.text = CleanUiFormatting(ReadText(n));
                e.hasText = true;
                if (S_DebugTreeInlineText && e.text.Length > 0) {
                    e.label += " | \"" + _TrimTreeText(e.text) + "\"";
                }
            }
            if (needId) {
                string idName = n.IdName.Trim().ToLower();
                string stack = n.StackText.Trim().ToLower();
                if (idName.Length > 0) e.id = idName;
                if (stack.Length > 0) {
                    if (e.id.Length > 0) e.id += " ";
                    e.id += stack;
                }
                e.hasId = true;
            }
            if (needVisible) {
                e.visible = IsEffectivelyVisible(n);
                e.hasVisible = true;
            }
            _ControlTreeNodeDataCacheInsert(key, e);
            return e;
        }

        if ((S_DebugTreeInlineText || needText) && !e.hasText) {
            e.text = CleanUiFormatting(ReadText(n));
            e.hasText = true;
            if (S_DebugTreeInlineText && e.text.Length > 0 && !e.label.Contains(" | \"")) {
                e.label += " | \"" + _TrimTreeText(e.text) + "\"";
            }
            e.stampMs = now;
        }

        // Ensure cached nodes still show an identifier if the cache was built before
        // the "always show IdName / fallback id" behavior was added.
        if (e.label.IndexOf(" #") < 0) {
            string idNameDisplay = n.IdName.Trim();
            if (idNameDisplay.Length == 0) {
                idNameDisplay = _ControlTreeFallbackIdFromUiPath(uiPath);
                if (idNameDisplay.Length == 0) idNameDisplay = "?";
            }

            int textIx = e.label.IndexOf(" | \"");
            string textSuffix = "";
            if (textIx >= 0) {
                textSuffix = e.label.SubStr(textIx);
                e.label = e.label.SubStr(0, textIx);
            }
            e.label += _TreeLabelIdSuffix(idNameDisplay) + textSuffix;
            e.stampMs = now;
        }
        if (needId && !e.hasId) {
            string idName = n.IdName.Trim().ToLower();
            string stack = n.StackText.Trim().ToLower();
            e.id = "";
            if (idName.Length > 0) e.id = idName;
            if (stack.Length > 0) {
                if (e.id.Length > 0) e.id += " ";
                e.id += stack;
            }
            e.hasId = true;
        }
        if (needVisible) {
            e.visible = IsEffectivelyVisible(n);
            e.hasVisible = true;
        }
        return e;
    }

    string _MlLabel(CGameManialinkControl@ n, const string &in uiPath) {
        auto e = _MlNodeData(n, uiPath, S_DebugTreeInlineText, false, false);
        if (e is null) return "<null>";
        return e.label;
    }

    string _ControlTreeLabel(CControlBase@ n, const string &in uiPath) {
        auto e = _ControlTreeNodeData(n, uiPath, S_DebugTreeInlineText, false);
        if (e is null) return "<null>";
        return e.label;
    }

    class _SearchTerm {
        bool negated = false;
        string field = "any";
        string value = "";
    }


}
}


