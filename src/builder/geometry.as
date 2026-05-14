namespace UiNavKit {
    namespace Builder {

        class _CenterBoundsState {
            bool has = false;
            vec2 minP = vec2();
            vec2 maxP = vec2();
        }

        void _CenterBoundsVisit(
            const UiNav::Builder::BuilderDocument@ doc,
            int nodeIx,
            const vec2 &in parentPos,
            float parentScale,
            _CenterBoundsState@ st
        ) {
            if (doc is null || st is null) return;
            if (nodeIx < 0 || nodeIx >= int(doc.nodes.Length)) return;
            auto n = doc.nodes[uint(nodeIx)];
            if (n is null || n.typed is null) return;

            vec2 absPos = parentPos + n.typed.pos * parentScale;
            float absScale = parentScale * n.typed.scale;
            vec2 absSize = n.typed.size * absScale;

            float ax = 0.5f;
            float ay = 0.5f;
            {
                string h = n.typed.hAlign.Trim().ToLower();
                if (h == "left") {
                    ax = 0.0f;
                } else if (h == "right") {
                    ax = 1.0f;
                } else {
                    ax = 0.5f;
                }

                string v = n.typed.vAlign.Trim().ToLower();
                if (v == "top") {
                    ay = 0.0f;
                } else if (v == "bottom") {
                    ay = 1.0f;
                } else if (v == "center" || v == "vcenter" || v == "center2" || v == "vcenter2") {
                    ay = 0.5f;
                } else {
                    ay = 0.5f;
                }
            }

            vec2 bMin = vec2(absPos.x - ax * absSize.x, absPos.y - (1.0f - ay) * absSize.y);
            vec2 bMax = vec2(absPos.x + (1.0f - ax) * absSize.x, absPos.y + ay * absSize.y);

            if (!st.has) {
                st.has = true;
                st.minP = bMin;
                st.maxP = bMax;
            } else {
                if (bMin.x < st.minP.x) st.minP.x = bMin.x;
                if (bMin.y < st.minP.y) st.minP.y = bMin.y;
                if (bMax.x > st.maxP.x) st.maxP.x = bMax.x;
                if (bMax.y > st.maxP.y) st.maxP.y = bMax.y;
            }

            for (uint i = 0; i < n.childIx.Length; ++i) {
                _CenterBoundsVisit(doc, n.childIx[i], absPos, absScale, st);
            }
        }

        bool _CenterDocumentRoots(UiNav::Builder::BuilderDocument@ doc) {
            if (doc is null) return false;
            auto st = _CenterBoundsState();

            for (uint i = 0; i < doc.nodes.Length; ++i) {
                auto n = doc.nodes[i];
                if (n is null || n.parentIx >= 0) continue;
                _CenterBoundsVisit(doc, int(i), vec2(), 1.0f, st);
            }
            if (!st.has) return false;

            vec2 center = (st.minP + st.maxP) * 0.5f;
            vec2 delta = vec2(-center.x, -center.y);
            if (Math::Abs(delta.x) < 0.001f && Math::Abs(delta.y) < 0.001f) return true;

            bool movedAny = false;
            for (uint i = 0; i < doc.nodes.Length; ++i) {
                auto n = doc.nodes[i];
                if (n is null || n.parentIx >= 0 || n.typed is null) continue;
                n.typed.pos += delta;
                movedAny = true;
            }
            return movedAny;
        }

        class _PreviewBoundsState {
            bool hasAll = false;
            vec2 minAll = vec2();
            vec2 maxAll = vec2();

            bool hasVisible = false;
            vec2 minVisible = vec2();
            vec2 maxVisible = vec2();

            int nodesWithTyped = 0;
            int nodesHiddenSelf = 0;
            int nodesHiddenByAncestor = 0;
            int nodesUnderClipAncestor = 0;
            int clipActiveFrames = 0;
        }

        float _AnchorXFromHAlign(const string &in hAlign) {
            string h = hAlign.Trim().ToLower();
            if (h == "left") return 0.0f;
            if (h == "center" || h == "hcenter") return 0.5f;
            if (h == "right") return 1.0f;
            return 0.5f;
        }

        float _AnchorYFromVAlign(const string &in vAlign) {
            string v = vAlign.Trim().ToLower();
            if (v == "top") return 0.0f;
            if (v == "center" || v == "vcenter" || v == "center2" || v == "vcenter2") return 0.5f;
            if (v == "bottom") return 1.0f;
            return 0.5f;
        }

        class BuilderAbsMetrics {
            bool ok = false;

            vec2 absPos = vec2();
            float absScale = 1.0f;

            vec2 absSize = vec2();
            vec2 boundsMin = vec2();
            vec2 boundsMax = vec2();
            float anchorX = 0.5f;
            float anchorY = 0.5f;

            bool hiddenByAncestor = false;
            bool selfHidden = false;
            bool underClipAncestor = false;
            int clipAncestorCount = 0;
        }

        BuilderAbsMetrics@ ComputeAbsMetrics(const UiNav::Builder::BuilderDocument@ doc, int nodeIx) {
            auto m = BuilderAbsMetrics();
            if (doc is null) return m;
            if (nodeIx < 0 || nodeIx >= int(doc.nodes.Length)) return m;

            array<int> chain;
            int cur = nodeIx;
            int guard = 0;
            while (cur >= 0 && cur < int(doc.nodes.Length) && guard < 512) {
                guard++;
                chain.InsertLast(cur);
                auto n = doc.nodes[uint(cur)];
                if (n is null) break;
                cur = n.parentIx;
            }
            if (chain.Length == 0) return m;

            vec2 absPos = vec2();
            float parentScale = 1.0f;
            bool hiddenAncestor = false;
            int clipAnc = 0;

            for (int i = int(chain.Length) - 1; i >= 0; --i) {
                int ix = chain[uint(i)];
                auto n = doc.nodes[uint(ix)];
                if (n is null || n.typed is null) return m;

                bool isSelf = (i == 0);
                if (!isSelf) {
                    if (!n.typed.visible) hiddenAncestor = true;
                    if (n.kind == "frame" && n.typed.clipActive) clipAnc++;
                } else {
                    if (!n.typed.visible) m.selfHidden = true;
                }

                absPos = absPos + n.typed.pos * parentScale;
                parentScale *= n.typed.scale;
            }

            auto self = doc.nodes[uint(nodeIx)];
            if (self is null || self.typed is null) return m;

            m.ok = true;
            m.absPos = absPos;
            m.absScale = parentScale;
            m.anchorX = _AnchorXFromHAlign(self.typed.hAlign);
            m.anchorY = _AnchorYFromVAlign(self.typed.vAlign);

            m.absSize = self.typed.size * m.absScale;
            m.boundsMin = vec2(absPos.x - m.anchorX * m.absSize.x, absPos.y - (1.0f - m.anchorY) * m.absSize.y);
            m.boundsMax = vec2(absPos.x + (1.0f - m.anchorX) * m.absSize.x, absPos.y + m.anchorY * m.absSize.y);

            m.hiddenByAncestor = hiddenAncestor;
            m.clipAncestorCount = clipAnc;
            m.underClipAncestor = clipAnc > 0;
            return m;
        }

        bool _ComputeBuilderParentAbsBasis(
            const UiNav::Builder::BuilderDocument@ doc,
            int nodeIx,
            vec2 &out parentAbsPos,
            float &out parentAbsScale
        ) {
            parentAbsPos = vec2();
            parentAbsScale = 1.0f;

            if (doc is null) return false;
            if (nodeIx < 0 || nodeIx >= int(doc.nodes.Length)) return false;

            auto self = doc.nodes[uint(nodeIx)];
            if (self is null || self.typed is null) return false;

            array<int> chain;
            int cur = self.parentIx;
            int guard = 0;
            while (cur >= 0 && cur < int(doc.nodes.Length) && guard < 512) {
                guard++;
                chain.InsertLast(cur);
                auto n = doc.nodes[uint(cur)];
                if (n is null) break;
                cur = n.parentIx;
            }

            for (int i = int(chain.Length) - 1; i >= 0; --i) {
                int ix = chain[uint(i)];
                auto n = doc.nodes[uint(ix)];
                if (n is null || n.typed is null) return false;
                parentAbsPos = parentAbsPos + n.typed.pos * parentAbsScale;
                parentAbsScale *= n.typed.scale;
            }

            return true;
        }

        bool _ComputeBuilderNodeLocalPosClamp(
            const UiNav::Builder::BuilderDocument@ doc,
            int nodeIx,
            const vec2 &in screenHalfExtents,
            vec2 &out minPos,
            vec2 &out maxPos,
            float offscreenMargin = 0.0f
        ) {
            minPos = vec2();
            maxPos = vec2();

            if (doc is null) return false;
            if (nodeIx < 0 || nodeIx >= int(doc.nodes.Length)) return false;

            auto node = doc.nodes[uint(nodeIx)];
            if (node is null || node.typed is null) return false;

            vec2 parentAbsPos = vec2();
            float parentAbsScale = 1.0f;
            if (!_ComputeBuilderParentAbsBasis(doc, nodeIx, parentAbsPos, parentAbsScale)) return false;

            float denom = parentAbsScale;
            if (Math::Abs(denom) < 0.0001f) return false;

            float selfAbsScale = Math::Abs(parentAbsScale * node.typed.scale);
            float anchorX = _AnchorXFromHAlign(node.typed.hAlign);
            float anchorY = _AnchorYFromVAlign(node.typed.vAlign);

            vec2 absSize = node.typed.size * selfAbsScale;
            float minAbsX = -screenHalfExtents.x - offscreenMargin + anchorX * absSize.x;
            float maxAbsX = screenHalfExtents.x + offscreenMargin - (1.0f - anchorX) * absSize.x;
            float minAbsY = -screenHalfExtents.y - offscreenMargin + (1.0f - anchorY) * absSize.y;
            float maxAbsY = screenHalfExtents.y + offscreenMargin - anchorY * absSize.y;

            if (minAbsX > maxAbsX) {
                float mid = (minAbsX + maxAbsX) * 0.5f;
                minAbsX = mid;
                maxAbsX = mid;
            }
            if (minAbsY > maxAbsY) {
                float mid = (minAbsY + maxAbsY) * 0.5f;
                minAbsY = mid;
                maxAbsY = mid;
            }

            minPos = vec2((minAbsX - parentAbsPos.x) / denom, (minAbsY - parentAbsPos.y) / denom);
            maxPos = vec2((maxAbsX - parentAbsPos.x) / denom, (maxAbsY - parentAbsPos.y) / denom);

            if (minPos.x > maxPos.x) {
                float tmp = minPos.x;
                minPos.x = maxPos.x;
                maxPos.x = tmp;
            }
            if (minPos.y > maxPos.y) {
                float tmp = minPos.y;
                minPos.y = maxPos.y;
                maxPos.y = tmp;
            }
            return true;
        }

        vec2 ClampBuilderNodeLocalPosToScreen(
            const UiNav::Builder::BuilderDocument@ doc,
            int nodeIx,
            const vec2 &in requestedPos,
            const vec2 &in screenHalfExtents,
            float offscreenMargin = 0.0f
        ) {
            vec2 minPos = vec2();
            vec2 maxPos = vec2();
            if (!_ComputeBuilderNodeLocalPosClamp(doc, nodeIx, screenHalfExtents, minPos, maxPos, offscreenMargin)) return requestedPos;

            vec2 clamped = requestedPos;
            clamped.x = Math::Clamp(clamped.x, minPos.x, maxPos.x);
            clamped.y = Math::Clamp(clamped.y, minPos.y, maxPos.y);
            return clamped;
        }

        void _ClearBuilderStickyGuides() {
            g_BuilderStickyGuides.active = false;
            g_BuilderStickyGuides.verticals.Resize(0);
            g_BuilderStickyGuides.horizontals.Resize(0);
        }

        void _SetBuilderStickyGuides(
            const vec2 &in screenHalfExtents,
            float offscreenMargin,
            const array<float> &in verticals,
            const array<float> &in horizontals
        ) {
            g_BuilderStickyGuides.screenHalfExtents = screenHalfExtents;
            g_BuilderStickyGuides.offscreenMargin = offscreenMargin;
            g_BuilderStickyGuides.verticals = verticals;
            g_BuilderStickyGuides.horizontals = horizontals;
            g_BuilderStickyGuides.active = verticals.Length > 0 || horizontals.Length > 0;
        }

        bool _IsAncestorInDoc(const UiNav::Builder::BuilderDocument@ doc, int nodeIx, int maybeAncestor) {
            if (doc is null) return false;
            if (nodeIx < 0 || maybeAncestor < 0) return false;
            if (nodeIx >= int(doc.nodes.Length) || maybeAncestor >= int(doc.nodes.Length)) return false;

            int cur = nodeIx;
            int guard = 0;
            while (cur >= 0 && cur < int(doc.nodes.Length) && guard < 512) {
                guard++;
                if (cur == maybeAncestor) return true;
                auto n = doc.nodes[uint(cur)];
                if (n is null) break;
                cur = n.parentIx;
            }
            return false;
        }

        void _AddBuilderGuideUnique(array<float> &inout guides, float value, float eps = 0.05f) {
            for (uint i = 0; i < guides.Length; ++i) {
                if (Math::Abs(guides[i] - value) <= eps) return;
            }
            guides.InsertLast(value);
        }

        void _CollectBuilderStickyGuides(
            const UiNav::Builder::BuilderDocument@ doc,
            int nodeIx,
            const vec2 &in screenHalfExtents,
            bool includeScreen,
            bool includeNodes,
            array<float> &out verticals,
            array<float> &out horizontals
        ) {
            verticals.Resize(0);
            horizontals.Resize(0);

            if (includeScreen) {
                _AddBuilderGuideUnique(verticals, -screenHalfExtents.x);
                _AddBuilderGuideUnique(verticals, 0.0f);
                _AddBuilderGuideUnique(verticals, screenHalfExtents.x);
                _AddBuilderGuideUnique(horizontals, -screenHalfExtents.y);
                _AddBuilderGuideUnique(horizontals, 0.0f);
                _AddBuilderGuideUnique(horizontals, screenHalfExtents.y);
            }

            if (!includeNodes || doc is null) return;

            for (uint i = 0; i < doc.nodes.Length; ++i) {
                int otherIx = int(i);
                if (otherIx == nodeIx) continue;
                if (_IsAncestorInDoc(doc, otherIx, nodeIx)) continue;

                auto metrics = ComputeAbsMetrics(doc, otherIx);
                if (metrics is null || !metrics.ok) continue;
                if (metrics.selfHidden || metrics.hiddenByAncestor) continue;

                _AddBuilderGuideUnique(verticals, metrics.boundsMin.x);
                _AddBuilderGuideUnique(verticals, (metrics.boundsMin.x + metrics.boundsMax.x) * 0.5f);
                _AddBuilderGuideUnique(verticals, metrics.boundsMax.x);

                _AddBuilderGuideUnique(horizontals, metrics.boundsMin.y);
                _AddBuilderGuideUnique(horizontals, (metrics.boundsMin.y + metrics.boundsMax.y) * 0.5f);
                _AddBuilderGuideUnique(horizontals, metrics.boundsMax.y);
            }
        }

        bool _ResolveBuilderAxisSnap(
            float absPos,
            float absSize,
            float anchor,
            const array<float> &in guides,
            float threshold,
            float &out snappedAbsPos,
            float &out snappedGuide
        ) {
            snappedAbsPos = absPos;
            snappedGuide = 0.0f;
            if (threshold <= 0.0f || guides.Length == 0) return false;

            float minEdge = absPos - anchor * absSize;
            float center = minEdge + absSize * 0.5f;
            float maxEdge = minEdge + absSize;

            bool found = false;
            float bestDelta = 0.0f;
            float bestAbs = threshold + 0.0001f;

            for (uint i = 0; i < guides.Length; ++i) {
                float guide = guides[i];

                float deltaMin = guide - minEdge;
                float absMin = Math::Abs(deltaMin);
                if (absMin <= threshold && absMin < bestAbs) {
                    found = true;
                    bestAbs = absMin;
                    bestDelta = deltaMin;
                    snappedGuide = guide;
                }

                float deltaCenter = guide - center;
                float absCenter = Math::Abs(deltaCenter);
                if (absCenter <= threshold && absCenter < bestAbs) {
                    found = true;
                    bestAbs = absCenter;
                    bestDelta = deltaCenter;
                    snappedGuide = guide;
                }

                float deltaMax = guide - maxEdge;
                float absMax = Math::Abs(deltaMax);
                if (absMax <= threshold && absMax < bestAbs) {
                    found = true;
                    bestAbs = absMax;
                    bestDelta = deltaMax;
                    snappedGuide = guide;
                }
            }

            if (!found) return false;
            snappedAbsPos = absPos + bestDelta;
            return true;
        }

        vec2 ResolveBuilderNodeSliderPos(
            const UiNav::Builder::BuilderDocument@ doc,
            int nodeIx,
            const vec2 &in requestedPos,
            const vec2 &in screenHalfExtents,
            float offscreenMargin,
            bool stickyEnabled,
            bool stickyToScreen,
            bool stickyToNodes,
            float stickyThreshold,
            array<float> @verticalGuides = null,
            array<float> @horizontalGuides = null
        ) {
            if (verticalGuides !is null) verticalGuides.Resize(0);
            if (horizontalGuides !is null) horizontalGuides.Resize(0);

            vec2 resolved = ClampBuilderNodeLocalPosToScreen(
                doc,
                nodeIx,
                requestedPos,
                screenHalfExtents,
                offscreenMargin
            );
            if (!stickyEnabled || stickyThreshold <= 0.0f) return resolved;

            if (doc is null || nodeIx < 0 || nodeIx >= int(doc.nodes.Length)) return resolved;
            auto node = doc.nodes[uint(nodeIx)];
            if (node is null || node.typed is null) return resolved;

            vec2 parentAbsPos = vec2();
            float parentAbsScale = 1.0f;
            if (!_ComputeBuilderParentAbsBasis(doc, nodeIx, parentAbsPos, parentAbsScale)) return resolved;
            if (Math::Abs(parentAbsScale) < 0.0001f) return resolved;

            float absScale = Math::Abs(parentAbsScale * node.typed.scale);
            float anchorX = _AnchorXFromHAlign(node.typed.hAlign);
            float anchorY = _AnchorYFromVAlign(node.typed.vAlign);
            vec2 absSize = node.typed.size * absScale;
            vec2 absPos = parentAbsPos + resolved * parentAbsScale;

            array<float> candidateVerticals;
            array<float> candidateHorizontals;
            _CollectBuilderStickyGuides(
                doc,
                nodeIx,
                screenHalfExtents,
                stickyToScreen,
                stickyToNodes,
                candidateVerticals,
                candidateHorizontals
            );

            float snappedAbsX = absPos.x;
            float snappedGuideX = 0.0f;
            if (_ResolveBuilderAxisSnap(absPos.x, absSize.x, anchorX, candidateVerticals, stickyThreshold, snappedAbsX, snappedGuideX)) {
                resolved.x = (snappedAbsX - parentAbsPos.x) / parentAbsScale;
                if (verticalGuides !is null) _AddBuilderGuideUnique(verticalGuides, snappedGuideX);
            }

            float snappedAbsY = absPos.y;
            float snappedGuideY = 0.0f;
            if (_ResolveBuilderAxisSnap(absPos.y, absSize.y, anchorY, candidateHorizontals, stickyThreshold, snappedAbsY, snappedGuideY)) {
                resolved.y = (snappedAbsY - parentAbsPos.y) / parentAbsScale;
                if (horizontalGuides !is null) _AddBuilderGuideUnique(horizontalGuides, snappedGuideY);
            }

            return ClampBuilderNodeLocalPosToScreen(doc, nodeIx, resolved, screenHalfExtents, offscreenMargin);
        }

        bool _BuilderBoundsSame(const BuilderAbsMetrics@ a, const BuilderAbsMetrics@ b, float eps = 0.01f) {
            if (a is null || b is null) return false;
            if (!a.ok || !b.ok) return false;
            return Math::Abs(a.boundsMin.x - b.boundsMin.x) <= eps
                && Math::Abs(a.boundsMin.y - b.boundsMin.y) <= eps
                && Math::Abs(a.boundsMax.x - b.boundsMax.x) <= eps
                && Math::Abs(a.boundsMax.y - b.boundsMax.y) <= eps;
        }

        int _CountBuilderParentChain(const UiNav::Builder::BuilderDocument@ doc, int nodeIx) {
            if (doc is null) return 0;
            if (nodeIx < 0 || nodeIx >= int(doc.nodes.Length)) return 0;

            auto node = doc.nodes[uint(nodeIx)];
            if (node is null) return 0;

            int count = 0;
            int parentIx = node.parentIx;
            int guard = 0;
            while (parentIx >= 0 && parentIx < int(doc.nodes.Length) && guard < 256) {
                guard++;
                auto parent = doc.nodes[uint(parentIx)];
                if (parent is null) break;
                count++;
                parentIx = parent.parentIx;
            }
            return count;
        }

        string _DescribeBuilderParentChainOverlapWarnings(const UiNav::Builder::BuilderDocument@ doc, int nodeIx) {
            if (doc is null) return "";
            if (nodeIx < 0 || nodeIx >= int(doc.nodes.Length)) return "";

            array<BuilderAbsMetrics@> seen;
            array<string> seenNames;

            auto selectedMetrics = ComputeAbsMetrics(doc, nodeIx);
            if (selectedMetrics !is null && selectedMetrics.ok) {
                seen.InsertLast(selectedMetrics);
                seenNames.InsertLast("selected");
            }

            auto node = doc.nodes[uint(nodeIx)];
            if (node is null) return "";

            string outText = "";
            int parentIx = node.parentIx;
            int depth = 0;
            int guard = 0;
            while (parentIx >= 0 && parentIx < int(doc.nodes.Length) && guard < 256) {
                guard++;
                auto parent = doc.nodes[uint(parentIx)];
                if (parent is null) break;

                auto parentMetrics = ComputeAbsMetrics(doc, parentIx);
                if (parentMetrics !is null && parentMetrics.ok) {
                    string matches = "";
                    for (uint i = 0; i < seen.Length; ++i) {
                        if (!_BuilderBoundsSame(parentMetrics, seen[i])) continue;
                        if (matches.Length > 0) matches += ", ";
                        matches += seenNames[i];
                    }

                    if (matches.Length > 0) {
                        if (outText.Length > 0) outText += "\n";
                        outText += "Parent " + (depth + 1) + " shares bounds with " + matches + ".";
                    }

                    seen.InsertLast(parentMetrics);
                    seenNames.InsertLast("parent " + (depth + 1));
                }

                parentIx = parent.parentIx;
                depth++;
            }

            return outText;
        }

        void _BoundsUpdateAll(_PreviewBoundsState@ st, const vec2 &in bMin, const vec2 &in bMax) {
            if (st is null) return;
            if (!st.hasAll) {
                st.hasAll = true;
                st.minAll = bMin;
                st.maxAll = bMax;
                return;
            }
            if (bMin.x < st.minAll.x) st.minAll.x = bMin.x;
            if (bMin.y < st.minAll.y) st.minAll.y = bMin.y;
            if (bMax.x > st.maxAll.x) st.maxAll.x = bMax.x;
            if (bMax.y > st.maxAll.y) st.maxAll.y = bMax.y;
        }

        void _BoundsUpdateVisible(_PreviewBoundsState@ st, const vec2 &in bMin, const vec2 &in bMax) {
            if (st is null) return;
            if (!st.hasVisible) {
                st.hasVisible = true;
                st.minVisible = bMin;
                st.maxVisible = bMax;
                return;
            }
            if (bMin.x < st.minVisible.x) st.minVisible.x = bMin.x;
            if (bMin.y < st.minVisible.y) st.minVisible.y = bMin.y;
            if (bMax.x > st.maxVisible.x) st.maxVisible.x = bMax.x;
            if (bMax.y > st.maxVisible.y) st.maxVisible.y = bMax.y;
        }

        void _PreviewBoundsVisit(
            const UiNav::Builder::BuilderDocument@ doc,
            int nodeIx,
            const vec2 &in parentPos,
            float parentScale,
            bool hiddenAncestor,
            int clipDepth,
            _PreviewBoundsState@ st
        ) {
            if (doc is null || st is null) return;
            if (nodeIx < 0 || nodeIx >= int(doc.nodes.Length)) return;
            auto n = doc.nodes[uint(nodeIx)];
            if (n is null) return;

            bool selfHidden = false;
            bool hasTyped = n.typed !is null;
            if (hasTyped) {
                st.nodesWithTyped++;
                if (!n.typed.visible) {
                    st.nodesHiddenSelf++;
                    selfHidden = true;
                }
            }

            bool nowHiddenAncestor = hiddenAncestor || selfHidden;
            if (hiddenAncestor && !selfHidden) st.nodesHiddenByAncestor++;
            if (clipDepth > 0) st.nodesUnderClipAncestor++;

            vec2 absPos = parentPos;
            float absScale = parentScale;
            if (hasTyped) {
                absPos = parentPos + n.typed.pos * parentScale;
                absScale = parentScale * n.typed.scale;

                vec2 absSize = n.typed.size * absScale;
                float ax = _AnchorXFromHAlign(n.typed.hAlign);
                float ay = _AnchorYFromVAlign(n.typed.vAlign);
                vec2 bMin = vec2(absPos.x - ax * absSize.x, absPos.y - (1.0f - ay) * absSize.y);
                vec2 bMax = vec2(absPos.x + (1.0f - ax) * absSize.x, absPos.y + ay * absSize.y);
                _BoundsUpdateAll(st, bMin, bMax);
                if (!nowHiddenAncestor) {
                    _BoundsUpdateVisible(st, bMin, bMax);
                }
            }

            bool isClipFrame = false;
            if (n.kind == "frame" && hasTyped && n.typed.clipActive) {
                st.clipActiveFrames++;
                isClipFrame = true;
            }
            int nextClipDepth = clipDepth + (isClipFrame ? 1 : 0);

            for (uint i = 0; i < n.childIx.Length; ++i) {
                _PreviewBoundsVisit(doc, n.childIx[i], absPos, absScale, nowHiddenAncestor, nextClipDepth, st);
            }
        }

        void _ComputePreviewBounds(const UiNav::Builder::BuilderDocument@ doc, _PreviewBoundsState@ st) {
            if (doc is null || st is null) return;
            for (uint i = 0; i < doc.nodes.Length; ++i) {
                auto n = doc.nodes[i];
                if (n is null || n.parentIx >= 0) continue;
                _PreviewBoundsVisit(doc, int(i), vec2(), 1.0f, false, 0, st);
            }
        }

        bool _TryLocateLayerInApp(
            CGameManiaApp@ app,
            const string &in appLabel,
            CGameUILayer@ layer,
            string &out foundLabel,
            int &out foundIx
        ) {
            if (app is null || layer is null) return false;
            auto layers = app.UILayers;
            for (uint i = 0; i < layers.Length; ++i) {
                if (layers[i] is layer) {
                    foundLabel = appLabel;
                    foundIx = int(i);
                    return true;
                }
            }
            return false;
        }

        void _LocateOwnedPreviewLayer(CGameUILayer@ layer, string &out appLabel, int &out layerIx) {
            appLabel = "<unknown>";
            layerIx = -1;
            if (layer is null) return;

            if (_TryLocateLayerInApp(UiNavKit::Runtime::GetManiaApp(), "Current", layer, appLabel, layerIx)) return;
            if (_TryLocateLayerInApp(UiNavKit::Runtime::GetManiaAppMenu(), "Menu", layer, appLabel, layerIx)) return;
            if (_TryLocateLayerInApp(UiNavKit::Runtime::GetManiaAppPlayground(), "Playground", layer, appLabel, layerIx)) return;
        }

        int _AppKindFromLabel(const string &in labelRaw) {
            string l = labelRaw.Trim().ToLower();
            if (l == "playground") return 0;
            if (l == "menu") return 1;
            if (l == "current") return 2;
            return -1;
        }

        bool _ResolveLiveBoundsOverlayTarget(
            int &out appKind,
            int &out layerIx,
            string &out selectedPath,
            bool &out fromMlSelection
        ) {
            selectedPath = "";
            fromMlSelection = false;

            if (UiNavKit::g_SelectedMlLayerIx >= 0) {
                appKind = UiNavKit::g_SelectedMlAppKind;
                layerIx = UiNavKit::g_SelectedMlLayerIx;
                selectedPath = UiNavKit::g_SelectedMlPath.Trim();
                fromMlSelection = true;
                return true;
            }

            int previewAppKind = _AppKindFromLabel(g_LastPreviewAppLabel);
            if (g_LastPreviewAtMs > 0 && previewAppKind >= 0 && g_LastPreviewLayerIx >= 0) {
                appKind = previewAppKind;
                layerIx = g_LastPreviewLayerIx;
                return true;
            }

            appKind = g_ImportAppKind;
            layerIx = g_ImportLayerIx;
            return layerIx >= 0;
        }

        string _FmtVec2(const vec2 &in v) {
            return "(" + v.x + ", " + v.y + ")";
        }

        void _BuildPreviewDiagText(
            const UiNav::Builder::BuilderDocument@ doc,
            const string &in key,
            int xmlLen,
            CGameUILayer@ layer,
            const _PreviewBoundsState@ st,
            bool appliedForceFit,
            float forceFitScale,
            int sanitizedTags,
            int omittedGenericTyped,
            string &out text
        ) {
            array<string> lines;
            if (doc is null) {
                lines.InsertLast("Preview: <no document>");
                text = lines[0];
                return;
            }

            string appLabel = "<unknown>";
            int layerIx = -1;
            _LocateOwnedPreviewLayer(layer, appLabel, layerIx);

            lines.InsertLast("Preview target: key=\"" + key + "\" app=" + appLabel + " layerIx=" + layerIx);
            lines.InsertLast("XML length: " + xmlLen + " chars");

            int roots = 0;
            for (uint i = 0; i < doc.nodes.Length; ++i) if (doc.nodes[i] !is null && doc.nodes[i].parentIx < 0) roots++;
            lines.InsertLast("Nodes: total=" + doc.nodes.Length + " roots=" + roots);

            if (st !is null && st.hasAll) {
                vec2 sz = st.maxAll - st.minAll;
                bool sane = Math::Abs(st.minAll.x) < 2000.0f && Math::Abs(st.maxAll.x) < 2000.0f
                    && Math::Abs(st.minAll.y) < 2000.0f && Math::Abs(st.maxAll.y) < 2000.0f
                    && sz.x < 4000.0f && sz.y < 4000.0f;
                lines.InsertLast("Bounds(all): min=" + _FmtVec2(st.minAll) + " max=" + _FmtVec2(st.maxAll) + " size=" + _FmtVec2(sz) + " sane=" + (sane ? "yes" : "NO"));
            } else {
                lines.InsertLast("Bounds(all): <none>");
            }

            if (st !is null && st.hasVisible) {
                vec2 sz = st.maxVisible - st.minVisible;
                lines.InsertLast("Bounds(visible): min=" + _FmtVec2(st.minVisible) + " max=" + _FmtVec2(st.maxVisible) + " size=" + _FmtVec2(sz));
            } else {
                lines.InsertLast("Bounds(visible): <none>");
            }

            if (st !is null) {
                lines.InsertLast("Hidden: self=" + st.nodesHiddenSelf + " byAncestor=" + st.nodesHiddenByAncestor);
                lines.InsertLast("Clipping: clipFrames=" + st.clipActiveFrames + " nodesUnderClipAncestor=" + st.nodesUnderClipAncestor);
            }

            if (appliedForceFit) {
                lines.InsertLast("Force-fit applied: scale=" + forceFitScale);
            }
            if (sanitizedTags > 0) lines.InsertLast("Preview sanitization: rewritten invalid tags=" + sanitizedTags);
            if (omittedGenericTyped > 0) lines.InsertLast("Preview sanitization: omitted typed props for generic nodes=" + omittedGenericTyped);

            int cFrame = 0, cQuad = 0, cLabel = 0, cEntry = 0, cTextEdit = 0, cGeneric = 0, cRaw = 0;
            int cTagControl = 0;
            dictionary tagCounts;
            for (uint i = 0; i < doc.nodes.Length; ++i) {
                auto n = doc.nodes[i];
                if (n is null) continue;
                string k = n.kind;
                if (k == "frame") {
                    cFrame++;
                } else if (k == "quad") {
                    cQuad++;
                } else if (k == "label") {
                    cLabel++;
                } else if (k == "entry") {
                    cEntry++;
                } else if (k == "textedit") {
                    cTextEdit++;
                } else if (k == "raw_xml") {
                    cRaw++;
                } else {
                    cGeneric++;
                }

                string tag = n.tagName.Trim();
                if (tag.Length == 0) tag = n.kind;
                string tagLower = tag.ToLower();
                if (tagLower == "control") cTagControl++;
                int vv = 0;
                if (tagCounts.Get(tagLower, vv)) {
                    tagCounts.Set(tagLower, vv + 1);
                } else {
                    tagCounts.Set(tagLower, 1);
                }
            }
            lines.InsertLast("Kinds: frame=" + cFrame + " quad=" + cQuad + " label=" + cLabel + " entry=" + cEntry + " textedit=" + cTextEdit + " generic=" + cGeneric + " raw=" + cRaw);
            if (cTagControl > 0) lines.InsertLast("WARN: tag \"control\" count=" + cTagControl + " (likely invalid ML tag; can blank the whole page)");

            array<string> tags = tagCounts.GetKeys();
            array<int> counts;
            counts.Resize(tags.Length);
            for (uint i = 0; i < tags.Length; ++i) {
                int v = 0;
                tagCounts.Get(tags[i], v);
                counts[i] = v;
            }
            for (uint i = 0; i < tags.Length; ++i) {
                for (uint j = i + 1; j < tags.Length; ++j) {
                    if (counts[j] > counts[i]) {
                        int tc = counts[i];
                        counts[i] = counts[j];
                        counts[j] = tc;
                        string ts = tags[i];
                        tags[i] = tags[j];
                        tags[j] = ts;
                    }
                }
            }
            int topN = int(tags.Length);
            if (topN > 12) topN = 12;
            string top = "";
            for (int i = 0; i < topN; ++i) {
                if (i > 0) top += ", ";
                top += tags[uint(i)] + "=" + counts[uint(i)];
            }
            lines.InsertLast("Top tags: " + (top.Length > 0 ? top : "<none>") + " (unique=" + tags.Length + ")");

            lines.InsertLast("Root nodes:");
            int shown = 0;
            for (uint i = 0; i < doc.nodes.Length; ++i) {
                auto n = doc.nodes[i];
                if (n is null || n.parentIx >= 0) continue;
                string idPart = n.controlId.Length > 0 ? n.controlId : n.uid;
                string tag = n.tagName.Trim();
                if (tag.Length == 0) tag = n.kind;
                string line = "  [" + i + "] <" + tag + "> kind=" + n.kind + " id=" + idPart;
                if (n.typed is null) {
                    line += " <no typed props>";
                    lines.InsertLast(line);
                    shown++;
                    continue;
                }
                line += " pos=" + _FmtVec2(n.typed.pos)
                    + " size=" + _FmtVec2(n.typed.size)
                    + " scale=" + n.typed.scale
                    + " rot=" + n.typed.rot
                    + " z=" + n.typed.z
                    + " visible=" + (n.typed.visible ? "1" : "0");
                if (n.kind == "frame") {
                    line += " clip=" + (n.typed.clipActive ? "1" : "0");
                    if (n.typed.clipActive) {
                        line += " clipPos=" + _FmtVec2(n.typed.clipPos) + " clipSize=" + _FmtVec2(n.typed.clipSize);
                    }
                } else if (n.kind == "quad" || n.kind == "label" || n.kind == "entry" || n.kind == "textedit") {
                    line += " opacity=" + n.typed.opacity;
                }
                lines.InsertLast(line);
                shown++;
                if (shown >= 24) {
                    lines.InsertLast("  ... (truncated)");
                    break;
                }
            }

            text = "";
            for (uint i = 0; i < lines.Length; ++i) {
                if (i > 0) text += "\n";
                text += lines[i];
            }
        }

    }
}
