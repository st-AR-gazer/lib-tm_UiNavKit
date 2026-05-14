namespace UiNavKit {
    namespace Builder {

        bool AddDebugOriginMarker(bool applyPreviewNow = true) {
            _EnsureDoc();
            _PushUndoSnapshot();

            auto q = _NewNode("quad", -1);
            q.tagName = "quad";
            q.controlId = "UiNav_DbgOriginQuad";
            q.typed.pos = vec2(0, 0);
            q.typed.size = vec2(6.0f, 6.0f);
            q.typed.hAlign = "center";
            q.typed.vAlign = "center";
            q.typed.bgColor = "f00";
            q.typed.opacity = 1.0f;
            q.typed.z = 10000.0f;
            g_Doc.nodes.InsertLast(q);

            auto l = _NewNode("label", -1);
            l.tagName = "label";
            l.controlId = "UiNav_DbgOriginLabel";
            l.typed.pos = vec2(0, -10.0f);
            l.typed.size = vec2(80.0f, 6.0f);
            l.typed.hAlign = "center";
            l.typed.vAlign = "center";
            l.typed.text = "ORIGIN";
            l.typed.textColor = "f66";
            l.typed.textSize = 2.2f;
            l.typed.opacity = 1.0f;
            l.typed.z = 10001.0f;
            g_Doc.nodes.InsertLast(l);

            _RebuildNodeIndex(g_Doc);
            _UpdateDirtyState();
            _QueueAutoPreview();
            if (applyPreviewNow) _ApplyPreviewLayerInternal(false);
            g_Status = "Added origin marker.";
            return true;
        }

        bool ExportToClipboard() {
            _EnsureDoc();
            string xml = ExportToXml(g_Doc);
            if (xml.Length == 0) {
                g_Status = "Export failed: generated XML is empty.";
                return false;
            }
            g_LastExportXml = xml;
            IO::SetClipboard(xml);
            g_Status = "Exported XML to clipboard (" + xml.Length + " chars).";
            return true;
        }

        bool ExportToFilePath(const string &in pathRaw) {
            _EnsureDoc();
            string path = pathRaw.Trim();
            if (path.Length == 0) {
                g_Status = "Export failed: file path is empty.";
                return false;
            }

            string xml = ExportToXml(g_Doc);
            if (xml.Length == 0) {
                g_Status = "Export failed: generated XML is empty.";
                return false;
            }

            string folder = Path::GetDirectoryName(path);
            if (folder.Length > 0 && !IO::FolderExists(folder)) IO::CreateFolder(folder, true);
            _IO::File::WriteFile(path, xml, false);
            g_LastExportXml = xml;
            g_Status = "Exported XML to: " + path;
            return true;
        }

        bool _ApplyPreviewLayerInternal(bool writeSuccessStatus = true) {
            _EnsureDoc();
            string key = S_PreviewLayerKey.Trim();
            if (key.Length == 0) key = "UiNav_BuilderPreview";

            bool wantClone = S_PreviewDebugOverlayEnabled
                || S_PreviewSelectedBoundsOverlayEnabled
                || S_PreviewSelectedParentBoundsOverlayEnabled
                || (S_BuilderStickySnapGuidesEnabled && g_BuilderStickyGuides.active)
                || S_PreviewSanitizeInvalidTags
                || S_PreviewOmitGenericCommonAttrs
                || g_PreviewForceFitOnce;

            UiNav::Builder::BuilderDocument@ previewDoc = g_Doc;
            UiNav::Builder::BuilderDocument@ tmp = null;
            if (wantClone) {
                @tmp = _CloneDocument(g_Doc);
                @previewDoc = tmp;
            }

            int sanitizedTags = 0;
            if (tmp !is null && S_PreviewSanitizeInvalidTags) {
                for (uint i = 0; i < tmp.nodes.Length; ++i) {
                    auto n = tmp.nodes[i];
                    if (n is null) continue;
                    string tagLower = n.tagName.Trim().ToLower();
                    if (tagLower.Length == 0 || tagLower == "control") {
                        n.tagName = "frame";
                        sanitizedTags++;
                    }
                }
            }

            bool appliedForceFit = false;
            float forceFitScale = 1.0f;
            if (tmp !is null && g_PreviewForceFitOnce) {
                g_PreviewForceFitOnce = false;

                auto stPre = _PreviewBoundsState();
                _ComputePreviewBounds(tmp, stPre);
                if (stPre.hasAll) {
                    vec2 sz = stPre.maxAll - stPre.minAll;
                    float targetW = Math::Max(1.0f, S_PreviewForceFitHalfW * 2.0f);
                    float targetH = Math::Max(1.0f, S_PreviewForceFitHalfH * 2.0f);

                    float s = 1.0f;
                    if (sz.x > 0.001f) s = Math::Min(s, targetW / sz.x);
                    if (sz.y > 0.001f) s = Math::Min(s, targetH / sz.y);
                    s *= S_PreviewForceFitMargin;
                    if (s < 0.001f) s = 0.001f;
                    if (s > 50.0f) s = 50.0f;

                    vec2 center = (stPre.minAll + stPre.maxAll) * 0.5f;
                    for (uint i = 0; i < tmp.nodes.Length; ++i) {
                        auto n = tmp.nodes[i];
                        if (n is null || n.parentIx >= 0 || n.typed is null) continue;
                        n.typed.pos = (n.typed.pos - center) * s;
                        n.typed.scale *= s;
                    }
                    appliedForceFit = true;
                    forceFitScale = s;
                }
            }

            int omittedGenericTyped = 0;
            if (tmp !is null && S_PreviewOmitGenericCommonAttrs) {
                for (uint i = 0; i < tmp.nodes.Length; ++i) {
                    auto n = tmp.nodes[i];
                    if (n is null) continue;
                    if (n.kind == "generic" && n.typed !is null) {
                        @n.typed = null;
                        omittedGenericTyped++;
                    }
                }
            }

            auto boundsSt = _PreviewBoundsState();
            bool wantDiag = S_PreviewDiagnosticsEnabled || S_PreviewDebugOverlayEnabled || appliedForceFit || sanitizedTags > 0 || omittedGenericTyped > 0;
            if (wantDiag) {
                _ComputePreviewBounds(previewDoc, boundsSt);
            }

            BuilderAbsMetrics@ selAbs = null;
            if (tmp !is null && (S_PreviewSelectedBoundsOverlayEnabled || S_PreviewSelectedParentBoundsOverlayEnabled) && g_SelectedNodeIx >= 0) {
                @selAbs = ComputeAbsMetrics(previewDoc, g_SelectedNodeIx);
            }

            if (tmp !is null && S_PreviewDebugOverlayEnabled) _AppendPreviewOverlayNodes(tmp, boundsSt);
            if (tmp !is null && S_PreviewSelectedParentBoundsOverlayEnabled && g_SelectedNodeIx >= 0) {
                _AppendPreviewSelectedParentOverlayNodes(tmp, previewDoc, g_SelectedNodeIx, selAbs);
            }
            if (tmp !is null && S_PreviewSelectedBoundsOverlayEnabled && selAbs !is null && selAbs.ok) _AppendPreviewSelectedOverlayNodes(
                tmp,
                selAbs
            );
            if (tmp !is null && S_BuilderStickySnapGuidesEnabled && g_BuilderStickyGuides.active) _AppendPreviewStickyGuideOverlayNodes(tmp);

            string xml = ExportToXml(previewDoc);
            if (xml.Length == 0) {
                g_Status = "Preview failed: generated XML is empty.";
                return false;
            }

            auto layer = UiNavKit::Runtime::Ensure(key, xml, true, false);
            if (layer is null) {
                g_Status = "Preview failed: UiNavKit::Runtime::Ensure returned null.";
                return false;
            }

            uint nowMs = Time::Now;
            g_LastPreviewAtMs = nowMs;
            g_LastPreviewLayerKey = key;
            g_LastPreviewXmlLen = xml.Length;
            _LocateOwnedPreviewLayer(layer, g_LastPreviewAppLabel, g_LastPreviewLayerIx);

            if (wantDiag) {
                string diagText = "";
                _BuildPreviewDiagText(
                    previewDoc,
                    key,
                    xml.Length,
                    layer,
                    boundsSt,
                    appliedForceFit,
                    forceFitScale,
                    sanitizedTags,
                    omittedGenericTyped,
                    diagText
                );
                g_LastPreviewDiagText = diagText;
                g_LastPreviewBoundsHas = boundsSt.hasAll;
                if (boundsSt.hasAll) {
                    g_LastPreviewBoundsMin = boundsSt.minAll;
                    g_LastPreviewBoundsMax = boundsSt.maxAll;
                }
                if (S_PreviewDiagnosticsPrintToLog && diagText.Length > 0) {
                    log(
                        "[UiNav.Builder] Preview diagnostics:\n" + diagText,
                        LogLevel::Info,
                        213,
                        "UiNavKit::Builder::_ApplyPreviewLayerInternal"
                    );
                }
            } else {
                g_LastPreviewDiagText = "";
                g_LastPreviewBoundsHas = false;
            }

            g_LastExportXml = xml;
            if (writeSuccessStatus) g_Status = "Preview applied to layer key: " + key;
            g_AutoPreviewPending = false;

            if (S_LiveLayerBoundsOverlayEnabled) {
                RefreshLiveLayerBoundsOverlay(true, true);
            }
            return true;
        }

        bool ApplyPreviewLayer() {
            return _ApplyPreviewLayerInternal(true);
        }

        bool DestroyPreviewLayer() {
            string key = S_PreviewLayerKey.Trim();
            if (key.Length == 0) key = "UiNav_BuilderPreview";
            bool ok = UiNavKit::Runtime::Destroy(key);
            g_Status = ok ?
            ("Destroyed preview layer: " + key) : ("Preview layer not found or could not be destroyed: " + key);
            return ok;
        }

        void DiffAgainstOriginal() {
            _EnsureDoc();
            string current = ExportToXml(g_Doc);
            g_LastExportXml = current;
            _ComputeDiffSummary(g_Doc.originalXml, current, g_LastDiff);
            g_Status = "Diff generated.";
        }

    }
}
