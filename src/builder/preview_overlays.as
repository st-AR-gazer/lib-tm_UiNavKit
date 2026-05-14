namespace UiNavKit {
    namespace Builder {

        UiNav::Builder::BuilderNode@ _MakeOverlayQuad(
            const string &in uid,
            const vec2 &in pos,
            const vec2 &in size,
            const string &in color,
            float opacity,
            float z
        ) {
            auto n = UiNav::Builder::BuilderNode();
            n.uid = uid;
            n.kind = "quad";
            n.tagName = "quad";
            n.parentIx = -1;
            @n.typed = UiNav::Builder::BuilderTypedProps();
            n.typed.pos = pos;
            n.typed.size = size;
            n.typed.z = z;
            n.typed.opacity = opacity;
            n.typed.bgColor = color;
            n.typed.hAlign = "center";
            n.typed.vAlign = "center";
            return n;
        }

        UiNav::Builder::BuilderNode@ _MakeOverlayLabel(
            const string &in uid,
            const vec2 &in pos,
            const vec2 &in size,
            const string &in textV,
            const string &in color,
            float textSize,
            float z
        ) {
            auto n = UiNav::Builder::BuilderNode();
            n.uid = uid;
            n.kind = "label";
            n.tagName = "label";
            n.parentIx = -1;
            @n.typed = UiNav::Builder::BuilderTypedProps();
            n.typed.pos = pos;
            n.typed.size = size;
            n.typed.z = z;
            n.typed.text = textV;
            n.typed.textColor = color;
            n.typed.textSize = textSize;
            n.typed.hAlign = "center";
            n.typed.vAlign = "center";
            n.typed.opacity = 1.0f;
            return n;
        }

        void _AppendPreviewOverlayNodes(UiNav::Builder::BuilderDocument@ doc, const _PreviewBoundsState@ st) {
            if (doc is null) return;

            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_origin_h", vec2(0, 0), vec2(24, 0.7f), "f00", 0.85f, 10000.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_origin_v", vec2(0, 0), vec2(0.7f, 24), "f00", 0.85f, 10000.0f));
            doc.nodes.InsertLast(_MakeOverlayLabel("__uinav_dbg_origin_lbl", vec2(0, -12), vec2(60, 6), "ORIGIN (0,0)", "f44", 2.0f, 10001.0f));

            if (st is null || !st.hasAll) return;
            vec2 minP = st.minAll;
            vec2 maxP = st.maxAll;
            vec2 center = (minP + maxP) * 0.5f;
            vec2 size = maxP - minP;
            if (size.x < 0.001f || size.y < 0.001f) return;

            float t = 0.6f;
            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_bounds_fill", center, size, "0f0", 0.08f, 9990.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_bounds_top", vec2(center.x, maxP.y), vec2(size.x, t), "0f0", 0.70f, 9991.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_bounds_bot", vec2(center.x, minP.y), vec2(size.x, t), "0f0", 0.70f, 9991.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_bounds_l", vec2(minP.x, center.y), vec2(t, size.y), "0f0", 0.70f, 9991.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_bounds_r", vec2(maxP.x, center.y), vec2(t, size.y), "0f0", 0.70f, 9991.0f));
            doc.nodes.InsertLast(_MakeOverlayLabel("__uinav_dbg_bounds_lbl", vec2(center.x, center.y + 6.0f), vec2(180, 6), "BOUNDS " + _FmtVec2(minP) + " .. " + _FmtVec2(maxP), "0f0", 1.6f, 9992.0f));
        }

        void _AppendPreviewBoundsOutlineNodes(
            UiNav::Builder::BuilderDocument@ doc,
            const string &in prefix,
            const BuilderAbsMetrics@ metrics,
            const string &in color,
            float fillOpacity,
            float edgeOpacity,
            float zBase
        ) {
            if (doc is null || metrics is null || !metrics.ok) return;

            vec2 minP = metrics.boundsMin;
            vec2 maxP = metrics.boundsMax;
            vec2 center = (minP + maxP) * 0.5f;
            vec2 size = maxP - minP;
            if (size.x < 0.001f || size.y < 0.001f) return;

            float t = 0.6f;
            doc.nodes.InsertLast(_MakeOverlayQuad(prefix + "_fill", center, size, color, fillOpacity, zBase));
            doc.nodes.InsertLast(_MakeOverlayQuad(prefix + "_top", vec2(center.x, maxP.y), vec2(size.x, t), color, edgeOpacity, zBase + 1.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad(prefix + "_bot", vec2(center.x, minP.y), vec2(size.x, t), color, edgeOpacity, zBase + 1.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad(prefix + "_l", vec2(minP.x, center.y), vec2(t, size.y), color, edgeOpacity, zBase + 1.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad(prefix + "_r", vec2(maxP.x, center.y), vec2(t, size.y), color, edgeOpacity, zBase + 1.0f));
        }

        string _PreviewAncestorOverlayColor(int depth) {
            const string[] palette = {"fa0", "f70", "f48", "d5f", "8cf", "4fd"};
            if (depth < 0) depth = 0;
            if (depth >= int(palette.Length)) depth = int(palette.Length) - 1;
            return palette[uint(depth)];
        }

        void _AppendPreviewSelectedParentOverlayNodes(
            UiNav::Builder::BuilderDocument@ doc,
            const UiNav::Builder::BuilderDocument@ previewDoc,
            int nodeIx,
            BuilderAbsMetrics@ selectedMetrics = null
        ) {
            if (doc is null || previewDoc is null) return;
            if (nodeIx < 0 || nodeIx >= int(previewDoc.nodes.Length)) return;

            auto selected = previewDoc.nodes[uint(nodeIx)];
            if (selected is null) return;

            array<BuilderAbsMetrics@> seen;
            if (selectedMetrics !is null && selectedMetrics.ok) {
                seen.InsertLast(selectedMetrics);
            }

            int parentIx = selected.parentIx;
            int depth = 0;
            while (parentIx >= 0 && parentIx < int(previewDoc.nodes.Length) && depth < 64) {
                auto parentMetrics = ComputeAbsMetrics(previewDoc, parentIx);
                if (parentMetrics !is null && parentMetrics.ok) {
                    int sameBoundsCount = 0;
                    for (uint i = 0; i < seen.Length; ++i) {
                        if (_BuilderBoundsSame(parentMetrics, seen[i])) sameBoundsCount++;
                    }

                    float fillOpacity = Math::Max(0.02f, 0.045f - float(depth) * 0.004f);
                    float edgeOpacity = Math::Max(0.38f, 0.70f - float(depth) * 0.06f);
                    float zBase = 9983.0f - float(depth) * 2.0f;
                    string color = _PreviewAncestorOverlayColor(depth);
                    _AppendPreviewBoundsOutlineNodes(
                        doc,
                        "__uinav_dbg_sel_parent_" + depth,
                        parentMetrics,
                        color,
                        fillOpacity,
                        edgeOpacity,
                        zBase
                    );

                    vec2 center = (parentMetrics.boundsMin + parentMetrics.boundsMax) * 0.5f;
                    float labelY = parentMetrics.boundsMax.y + 6.0f + float(sameBoundsCount) * 5.0f;
                    string lbl = "P" + (depth + 1) + " pos=" + _FmtVec2(parentMetrics.absPos);
                    if (sameBoundsCount > 0) lbl += "  ! same bounds";
                    doc.nodes.InsertLast(_MakeOverlayLabel("__uinav_dbg_sel_parent_lbl_" + depth, vec2(center.x, labelY), vec2(240, 6), lbl, color, 1.35f, zBase + 2.0f));

                    seen.InsertLast(parentMetrics);
                }

                auto parent = previewDoc.nodes[uint(parentIx)];
                if (parent is null) break;
                parentIx = parent.parentIx;
                depth++;
            }
        }

        void _AppendPreviewSelectedOverlayNodes(UiNav::Builder::BuilderDocument@ doc, const BuilderAbsMetrics@ sel) {
            if (doc is null || sel is null || !sel.ok) return;

            vec2 minP = sel.boundsMin;
            vec2 maxP = sel.boundsMax;
            vec2 center = (minP + maxP) * 0.5f;
            vec2 size = maxP - minP;
            if (size.x < 0.001f || size.y < 0.001f) return;

            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_sel_anchor_h", sel.absPos, vec2(18, 0.6f), "ff0", 0.92f, 10002.0f));
            doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_sel_anchor_v", sel.absPos, vec2(0.6f, 18), "ff0", 0.92f, 10002.0f));

            _AppendPreviewBoundsOutlineNodes(doc, "__uinav_dbg_sel", sel, "ff0", 0.06f, 0.80f, 9993.0f);

            vec2 sz = maxP - minP;
            string lbl = "SELECTED bounds " + _FmtVec2(minP) + " .. " + _FmtVec2(maxP)
                + " size=" + _FmtVec2(sz)
                + " absPos=" + _FmtVec2(sel.absPos)
                + " absScale=" + sel.absScale;
            doc.nodes.InsertLast(_MakeOverlayLabel("__uinav_dbg_sel_lbl", vec2(center.x, maxP.y + 6.0f), vec2(260, 6), lbl, "ff0", 1.5f, 10003.0f));
        }

        void _AppendPreviewStickyGuideOverlayNodes(UiNav::Builder::BuilderDocument@ doc) {
            if (doc is null) return;
            if (!S_BuilderStickySnapGuidesEnabled || !g_BuilderStickyGuides.active) return;

            vec2 half = g_BuilderStickyGuides.screenHalfExtents;
            float margin = g_BuilderStickyGuides.offscreenMargin;
            float fullW = (half.x + margin) * 2.0f;
            float fullH = (half.y + margin) * 2.0f;
            float t = 0.45f;
            string color = "6ff";
            float zBase = 10010.0f;

            for (uint i = 0; i < g_BuilderStickyGuides.verticals.Length; ++i) {
                float x = g_BuilderStickyGuides.verticals[i];
                doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_snap_v_" + i, vec2(x, 0.0f), vec2(t, fullH), color, 0.90f, zBase));
                doc.nodes.InsertLast(_MakeOverlayLabel("__uinav_dbg_snap_vlbl_" + i, vec2(x, half.y + margin + 4.0f), vec2(48, 6), "X", color, 1.3f, zBase + 0.2f));
            }

            for (uint i = 0; i < g_BuilderStickyGuides.horizontals.Length; ++i) {
                float y = g_BuilderStickyGuides.horizontals[i];
                doc.nodes.InsertLast(_MakeOverlayQuad("__uinav_dbg_snap_h_" + i, vec2(0.0f, y), vec2(fullW, t), color, 0.90f, zBase));
                doc.nodes.InsertLast(_MakeOverlayLabel("__uinav_dbg_snap_hlbl_" + i, vec2(half.x + margin + 6.0f, y), vec2(48, 6), "Y", color, 1.3f, zBase + 0.2f));
            }
        }

    }
}
