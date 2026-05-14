namespace UiNavKit {
    namespace Builder {

        class _LiveBoundsState {
            bool hasAll = false;
            vec2 minAll = vec2();
            vec2 maxAll = vec2();

            bool hasVisible = false;
            vec2 minVisible = vec2();
            vec2 maxVisible = vec2();

            int nodes = 0;
            int clipActiveFrames = 0;
            int hiddenSelf = 0;
            int hiddenByAncestor = 0;
            int underClipAncestor = 0;
        }

        float _AnchorXFromLiveAlign(CGameManialinkControl::EAlignHorizontal a) {
            int v = int(a);
            if (v == 0) return 0.0f;
            if (v == 2) return 1.0f;
            return 0.5f;
        }

        float _AnchorYFromLiveAlign(CGameManialinkControl::EAlignVertical a) {
            int v = int(a);
            if (v == 0) return 0.0f;
            if (v == 2) return 1.0f;
            return 0.5f;
        }

        void _LiveBoundsUpdateAll(_LiveBoundsState@ st, const vec2 &in bMin, const vec2 &in bMax) {
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

        void _LiveBoundsUpdateVisible(_LiveBoundsState@ st, const vec2 &in bMin, const vec2 &in bMax) {
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

        void _LiveBoundsVisit(CGameManialinkControl@ n, bool hiddenAncestor, int clipDepth, _LiveBoundsState@ st) {
            if (n is null || st is null) return;
            st.nodes++;

            bool selfVisible = true;
            try {
                selfVisible = n.Visible;
            } catch {
                selfVisible = true;
            }
            bool selfHidden = !selfVisible;
            bool nowHidden = hiddenAncestor || selfHidden;
            if (selfHidden) st.hiddenSelf++;
            if (hiddenAncestor && !selfHidden) st.hiddenByAncestor++;
            if (clipDepth > 0) st.underClipAncestor++;

            bool ok = true;
            vec2 absPos = vec2();
            vec2 size = vec2();
            float absScale = 1.0f;
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
                _LiveBoundsUpdateAll(st, bMin, bMax);
                if (!nowHidden) _LiveBoundsUpdateVisible(st, bMin, bMax);
            }

            auto f = cast<CGameManialinkFrame@>(n);
            if (f is null) return;

            bool clipActive = false;
            try {
                clipActive = f.ClipWindowActive;
            } catch {
                clipActive = false;
            }
            int nextClipDepth = clipDepth + (clipActive ? 1 : 0);
            if (clipActive) st.clipActiveFrames++;

            try {
                for (uint i = 0; i < f.Controls.Length; ++i) {
                    auto ch = f.Controls[i];
                    if (ch is null) continue;
                    _LiveBoundsVisit(ch, nowHidden, nextClipDepth, st);
                }
            } catch {
                return;
            }
        }

    }
}
