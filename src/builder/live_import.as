namespace UiNavKit {
    namespace Builder {

        string _AlignHToXml(CGameManialinkControl::EAlignHorizontal a) {
            int v = int(a);
            if (v == 0) return "left";
            if (v == 1) return "center";
            if (v == 2) return "right";
            return "";
        }

        string _AlignVToXml(CGameManialinkControl::EAlignVertical a) {
            int v = int(a);
            if (v == 0) return "top";
            if (v == 1) return "center";
            if (v == 2) return "bottom";
            if (v == 4) return "center2";
            return "";
        }

        int _ClampByte(float v) {
            if (v < 0.0f) v = 0.0f;
            if (v > 1.0f) v = 1.0f;
            return int(v * 255.0f + 0.5f);
        }

        string _Vec3ToHexRgb(const vec3 &in v) {
            int r = _ClampByte(v.x);
            int g = _ClampByte(v.y);
            int b = _ClampByte(v.z);
            return Text::Format("%02x", r) + Text::Format("%02x", g) + Text::Format("%02x", b);
        }

        string _WStr(const wstring &in v) {
            return string(v);
        }

        class _LiveTreeCloneState {
            int maxNodes = 6000;
            int maxDepth = 256;
            int nodes = 0;
            bool truncated = false;
        }

        void _CloneLiveCommonProps(UiNav::Builder::BuilderNode@ outNode, CGameManialinkControl@ inNode) {
            if (outNode is null || inNode is null || outNode.typed is null) return;

            outNode.controlId = inNode.ControlId;
            outNode.typed.pos = inNode.RelativePosition_V3;
            outNode.typed.size = inNode.Size;
            outNode.typed.z = inNode.ZIndex;
            outNode.typed.scale = inNode.RelativeScale;
            outNode.typed.rot = inNode.RelativeRotation;
            outNode.typed.visible = inNode.Visible;
            outNode.typed.hAlign = _AlignHToXml(inNode.HorizontalAlign);
            outNode.typed.vAlign = _AlignVToXml(inNode.VerticalAlign);

            auto classes = inNode.ControlClasses;
            for (uint i = 0; i < classes.Length; ++i) {
                outNode.classes.InsertLast(classes[i]);
            }
        }

        string _TagFromLiveControl(CGameManialinkControl@ n, string &out kind) {
            kind = "generic";
            if (n is null) return "control";

            if (cast<CGameManialinkFrame@>(n) !is null) {
                kind = "frame";
                return "frame";
            }
            if (cast<CGameManialinkQuad@>(n) !is null) {
                kind = "quad";
                return "quad";
            }
            if (cast<CGameManialinkLabel@>(n) !is null) {
                kind = "label";
                return "label";
            }
            if (cast<CGameManialinkTextEdit@>(n) !is null) {
                kind = "textedit";
                return "textedit";
            }
            if (cast<CGameManialinkEntry@>(n) !is null) {
                kind = "entry";
                return "entry";
            }

            if (cast<CGameManialinkGauge@>(n) !is null) return "gauge";
            if (cast<CGameManialinkGraph@>(n) !is null) return "graph";
            if (cast<CGameManialinkMiniMap@>(n) !is null) return "minimap";
            if (cast<CGameManialinkPlayerList@>(n) !is null) return "playerlist";
            if (cast<CGameManialinkMediaPlayer@>(n) !is null) return "mediaplayer";
            if (cast<CGameManialinkArrow@>(n) !is null) return "arrow";
            if (cast<CGameManialinkSlider@>(n) !is null) return "slider";
            if (cast<CGameManialinkTimeLine@>(n) !is null) return "timeline";
            if (cast<CGameManialinkCamera@>(n) !is null) return "camera";
            if (cast<CGameManialinkColorChooser@>(n) !is null) return "colorchooser";

            return "control";
        }

        int _AppendLiveTreeNode(
            UiNav::Builder::BuilderDocument@ doc,
            CGameManialinkControl@ live,
            int parentIx,
            int depth,
            _LiveTreeCloneState@ st
        ) {
            if (doc is null || st is null) return -1;
            if (live is null) return -1;
            if (st.nodes >= st.maxNodes || depth > st.maxDepth) {
                st.truncated = true;
                return -1;
            }
            st.nodes++;

            string kind;
            string tag = _TagFromLiveControl(live, kind);
            auto node = _NewNode(kind, parentIx);
            node.tagName = tag;

            _CloneLiveCommonProps(node, live);
            node.fidelity.level = 1;
            node.fidelity.reasons.InsertLast("live_tree_clone");

            if (kind == "frame") {
                auto f = cast<CGameManialinkFrame@>(live);
                if (f !is null) {
                    node.typed.clipActive = f.ClipWindowActive;
                    node.typed.clipPos = f.ClipWindowRelativePosition;
                    node.typed.clipSize = f.ClipWindowSize;
                    node.typed.clipPosExplicit = node.typed.clipActive
                        && (Math::Abs(node.typed.clipPos.x) > 0.001f || Math::Abs(node.typed.clipPos.y) > 0.001f);
                    node.typed.clipSizeExplicit = node.typed.clipActive
                        && (Math::Abs(node.typed.clipSize.x) > 0.001f || Math::Abs(node.typed.clipSize.y) > 0.001f);
                }
            } else if (kind == "quad") {
                auto q = cast<CGameManialinkQuad@>(live);
                if (q !is null) {
                    node.typed.image = q.ImageUrl;
                    node.typed.imageFocus = q.ImageUrlFocus;
                    node.typed.alphaMask = q.AlphaMaskUrl;
                    node.typed.style = q.Style;
                    node.typed.subStyle = q.Substyle;
                    node.typed.bgColor = _Vec3ToHexRgb(q.BgColor);
                    node.typed.bgColorFocus = _Vec3ToHexRgb(q.BgColorFocus);
                    node.typed.modulateColor = _Vec3ToHexRgb(q.ModulateColor);
                    node.typed.colorize = _Vec3ToHexRgb(q.Colorize);
                    node.typed.opacity = q.Opacity;
                    node.typed.keepRatioMode = int(q.KeepRatio);
                    node.typed.blendMode = int(q.Blend);
                }
            } else if (kind == "label") {
                auto l = cast<CGameManialinkLabel@>(live);
                if (l !is null) {
                    node.typed.text = _WStr(l.Value);
                    node.typed.textSize = l.TextSizeReal;
                    node.typed.textFont = _WStr(l.TextFont);
                    node.typed.textPrefix = _WStr(l.TextPrefix);
                    node.typed.textColor = _Vec3ToHexRgb(l.TextColor);
                    node.typed.opacity = l.Opacity;
                    node.typed.maxLine = l.MaxLine;
                    node.typed.autoNewLine = l.AutoNewLine;
                    node.typed.lineSpacing = l.LineSpacing;
                    node.typed.italicSlope = l.ItalicSlope;
                    node.typed.appendEllipsis = l.AppendEllipsis;
                    node.typed.style = l.Style;
                    node.typed.subStyle = l.Substyle;
                }
            } else if (kind == "entry") {
                auto e = cast<CGameManialinkEntry@>(live);
                if (e !is null) {
                    node.typed.value = _WStr(e.Value);
                    node.typed.textFormat = int(e.TextFormat);
                    node.typed.textSize = e.TextSizeReal;
                    node.typed.textColor = _Vec3ToHexRgb(e.TextColor);
                    node.typed.opacity = e.Opacity;
                    node.typed.maxLength = e.MaxLength;
                    node.typed.maxLine = e.MaxLine;
                    node.typed.autoNewLine = e.AutoNewLine;
                }
            } else if (kind == "textedit") {
                auto t = cast<CGameManialinkTextEdit@>(live);
                if (t !is null) {
                    node.typed.value = _WStr(t.Value);
                    node.typed.textFormat = int(t.TextFormat);
                    node.typed.textSize = t.TextSizeReal;
                    node.typed.textColor = _Vec3ToHexRgb(t.TextColor);
                    node.typed.opacity = t.Opacity;
                    node.typed.maxLine = t.MaxLine;
                    node.typed.autoNewLine = t.AutoNewLine;
                    node.typed.lineSpacing = t.LineSpacing;
                }
            } else {
                node.fidelity.level = 2;
                node.fidelity.reasons.InsertLast("unsupported_kind_live_tree");
            }

            int ix = int(doc.nodes.Length);
            doc.nodes.InsertLast(node);
            if (parentIx >= 0 && parentIx < int(doc.nodes.Length)) {
                auto parent = doc.nodes[uint(parentIx)];
                if (parent !is null) parent.childIx.InsertLast(ix);
            }
            doc.nodeByUid.Set(node.uid, ix);

            auto f = cast<CGameManialinkFrame@>(live);
            if (f !is null) {
                for (uint i = 0; i < f.Controls.Length; ++i) {
                    auto ch = f.Controls[i];
                    if (ch is null) continue;
                    _AppendLiveTreeNode(doc, ch, ix, depth + 1, st);
                }
            }

            return ix;
        }

        int _AppendLiveLayerTreeRoots(
            UiNav::Builder::BuilderDocument@ doc,
            CGameManialinkFrame@ mainFrame,
            _LiveTreeCloneState@ st
        ) {
            if (doc is null || st is null || mainFrame is null) return 0;

            int appended = 0;
            bool appendedChild = false;
            try {
                for (uint i = 0; i < mainFrame.Controls.Length; ++i) {
                    auto ch = mainFrame.Controls[i];
                    if (ch is null) continue;
                    int ix = _AppendLiveTreeNode(doc, ch, -1, 0, st);
                    if (ix >= 0) {
                        appended++;
                        appendedChild = true;
                    }
                }
            } catch {
                appendedChild = false;
            }

            if (appendedChild) return appended;

            int rootIx = _AppendLiveTreeNode(doc, mainFrame, -1, 0, st);
            return rootIx >= 0 ? 1 : 0;
        }

        bool ImportFromLiveLayerTree(int appKind, int layerIx) {
            auto layer = _GetLayerByKindIx(appKind, layerIx);
            if (layer is null) {
                g_Status = "Clone failed: layer not found (app_kind=" + appKind + ", layer_ix=" + layerIx + ").";
                return false;
            }
            if (layer.LocalPage is null || layer.LocalPage.MainFrame is null) {
                g_Status = "Clone failed: layer has no LocalPage/MainFrame.";
                return false;
            }

            auto doc = _NewDocument();
            doc.sourceKind = "import_live_tree";
            doc.sourceLabel = "app=" + appKind + " layer=" + layerIx;
            doc.originalXml = _GetLayerXml(layer);

            auto st = _LiveTreeCloneState();
            int appendedRoots = _AppendLiveLayerTreeRoots(doc, layer.LocalPage.MainFrame, st);
            if (appendedRoots <= 0) {
                g_Status = "Clone failed: live tree produced no nodes.";
                return false;
            }
            if (st.truncated) {
                _AddDiag(doc, "clone.truncated", "warn", "Live tree clone truncated at node/depth budget.");
            }

            _ResetDocument(doc);
            int strippedClip = 0;
            if (S_StripFrameClippingOnImport) strippedClip = _SetFrameClipActiveInDoc(g_Doc, false);
            bool centered = false;
            if (S_CenterImportedLiveCopy) centered = _CenterDocumentRoots(g_Doc);
            g_BaselineXml = ExportToXml(g_Doc);
            g_Doc.dirty = false;
            g_LastExportXml = g_BaselineXml;
            _QueueAutoPreview();
            g_Status = "Cloned live tree: " + g_Doc.nodes.Length + " nodes across " + appendedRoots + " root(s)."
                + (strippedClip > 0 ? (" Stripped clipping on " + strippedClip + " frame(s).") : "")
                + (S_CenterImportedLiveCopy ? (centered ? " Centered." : " Centering skipped.") : "");
            return true;
        }

    }
}
