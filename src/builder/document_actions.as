namespace UiNavKit {
    namespace Builder {

        void _ClearRedo() {
            g_RedoSnapshots.Resize(0);
        }

        void _PushUndoSnapshot() {
            _EnsureDoc();
            g_UndoSnapshots.InsertLast(_CloneDocument(g_Doc));
            int maxKeep = S_UndoMax;
            if (maxKeep < 10) maxKeep = 10;
            while (int(g_UndoSnapshots.Length) > maxKeep) {
                g_UndoSnapshots.RemoveAt(0);
            }
            _ClearRedo();
        }

        bool Undo() {
            _EnsureDoc();
            if (g_UndoSnapshots.Length == 0) return false;
            g_RedoSnapshots.InsertLast(_CloneDocument(g_Doc));
            @g_Doc = g_UndoSnapshots[g_UndoSnapshots.Length - 1];
            g_UndoSnapshots.RemoveAt(g_UndoSnapshots.Length - 1);
            _RebuildNodeIndex(g_Doc);
            if (g_SelectedNodeIx >= int(g_Doc.nodes.Length)) g_SelectedNodeIx = -1;
            _UpdateDirtyState();
            _QueueAutoPreview();
            g_Status = "Undo applied.";
            return true;
        }

        bool Redo() {
            _EnsureDoc();
            if (g_RedoSnapshots.Length == 0) return false;
            g_UndoSnapshots.InsertLast(_CloneDocument(g_Doc));
            @g_Doc = g_RedoSnapshots[g_RedoSnapshots.Length - 1];
            g_RedoSnapshots.RemoveAt(g_RedoSnapshots.Length - 1);
            _RebuildNodeIndex(g_Doc);
            if (g_SelectedNodeIx >= int(g_Doc.nodes.Length)) g_SelectedNodeIx = -1;
            _UpdateDirtyState();
            _QueueAutoPreview();
            g_Status = "Redo applied.";
            return true;
        }

        bool _NodeCanContainChildren(const UiNav::Builder::BuilderNode@ n) {
            if (n is null) return false;
            return n.kind == "frame"
                || n.kind == "generic"
                || n.kind == "raw_xml";
        }

        int _CountRootNodes(const UiNav::Builder::BuilderDocument@ doc) {
            if (doc is null) return 0;
            int c = 0;
            for (uint i = 0; i < doc.nodes.Length; ++i) {
                auto n = doc.nodes[i];
                if (n !is null && n.parentIx < 0) c++;
            }
            return c;
        }

        int _FirstRootNodeIx(const UiNav::Builder::BuilderDocument@ doc) {
            if (doc is null) return -1;
            for (uint i = 0; i < doc.nodes.Length; ++i) {
                auto n = doc.nodes[i];
                if (n !is null && n.parentIx < 0) return int(i);
            }
            return -1;
        }

        bool _GetNodeSiblingContext(int nodeIx, int &out parentIx, int &out siblingPos, int &out siblingCount) {
            _EnsureDoc();
            parentIx = -1;
            siblingPos = -1;
            siblingCount = 0;

            if (nodeIx < 0 || nodeIx >= int(g_Doc.nodes.Length)) return false;
            auto node = g_Doc.nodes[uint(nodeIx)];
            if (node is null) return false;

            parentIx = node.parentIx;
            if (parentIx >= 0) {
                auto parent = g_Doc.nodes[uint(parentIx)];
                if (parent is null) return false;

                siblingCount = int(parent.childIx.Length);
                for (uint i = 0; i < parent.childIx.Length; ++i) {
                    if (parent.childIx[i] == nodeIx) {
                        siblingPos = int(i);
                        return true;
                    }
                }
                return false;
            }

            for (uint i = 0; i < g_Doc.nodes.Length; ++i) {
                auto maybeRoot = g_Doc.nodes[i];
                if (maybeRoot is null || maybeRoot.parentIx >= 0) continue;
                if (int(i) == nodeIx) siblingPos = siblingCount;
                siblingCount++;
            }
            return siblingPos >= 0;
        }

        bool _CanMoveNodeSiblingOrderDelta(int nodeIx, int delta) {
            int parentIx = -1;
            int siblingPos = -1;
            int siblingCount = 0;
            if (!_GetNodeSiblingContext(nodeIx, parentIx, siblingPos, siblingCount)) return false;

            int targetPos = siblingPos + delta;
            return targetPos >= 0 && targetPos < siblingCount;
        }

        bool _ReorderDocumentNodes(const array<int> &in order) {
            _EnsureDoc();
            if (order.Length != g_Doc.nodes.Length) return false;

            array<bool> seen;
            seen.Resize(order.Length);
            for (uint i = 0; i < seen.Length; ++i) seen[i] = false;

            array<int> remap;
            remap.Resize(order.Length);
            for (uint i = 0; i < remap.Length; ++i) remap[i] = -1;

            array<UiNav::Builder::BuilderNode@> newNodes;
            for (uint newIx = 0; newIx < order.Length; ++newIx) {
                int oldIx = order[newIx];
                if (oldIx < 0 || oldIx >= int(g_Doc.nodes.Length)) return false;
                if (seen[uint(oldIx)]) return false;

                seen[uint(oldIx)] = true;
                remap[uint(oldIx)] = int(newIx);
                newNodes.InsertLast(_CloneNode(g_Doc.nodes[uint(oldIx)]));
            }

            for (uint i = 0; i < newNodes.Length; ++i) {
                auto node = newNodes[i];
                if (node is null) continue;

                if (node.parentIx >= 0) {
                    if (node.parentIx >= int(remap.Length)) return false;
                    int mappedParent = remap[uint(node.parentIx)];
                    if (mappedParent < 0) return false;
                    node.parentIx = mappedParent;
                }

                array<int> children;
                for (uint c = 0; c < node.childIx.Length; ++c) {
                    int oldChildIx = node.childIx[c];
                    if (oldChildIx < 0 || oldChildIx >= int(remap.Length)) return false;
                    int mappedChild = remap[uint(oldChildIx)];
                    if (mappedChild < 0) return false;
                    children.InsertLast(mappedChild);
                }
                node.childIx = children;
            }

            int oldSelectedIx = g_SelectedNodeIx;
            int oldBoundsTargetIx = g_BoundsTargetNodeIx;
            int oldRootIx = g_Doc.rootIx;

            g_Doc.nodes = newNodes;

            g_SelectedNodeIx = (oldSelectedIx >= 0 && oldSelectedIx < int(remap.Length)) ?
            remap[uint(oldSelectedIx)] :-1;
            g_BoundsTargetNodeIx = (oldBoundsTargetIx >= 0 && oldBoundsTargetIx < int(remap.Length)) ?
            remap[uint(oldBoundsTargetIx)] :-1;
            g_Doc.rootIx = (oldRootIx >= 0 && oldRootIx < int(remap.Length)) ? remap[uint(oldRootIx)] :-1;
            if (g_Doc.rootIx < 0 || g_Doc.rootIx >= int(g_Doc.nodes.Length)) {
                g_Doc.rootIx = _FirstRootNodeIx(g_Doc);
            } else {
                auto root = g_Doc.nodes[uint(g_Doc.rootIx)];
                if (root is null || root.parentIx >= 0) g_Doc.rootIx = _FirstRootNodeIx(g_Doc);
            }

            _RebuildNodeIndex(g_Doc);
            return true;
        }

        bool _MoveRootNodeSiblingOrder(int nodeIx, int delta) {
            int parentIx = -1;
            int siblingPos = -1;
            int siblingCount = 0;
            if (!_GetNodeSiblingContext(nodeIx, parentIx, siblingPos, siblingCount)) return false;
            if (parentIx >= 0) return false;

            int targetPos = siblingPos + delta;
            if (targetPos < 0 || targetPos >= siblingCount) return false;

            array<int> rootIxs;
            for (uint i = 0; i < g_Doc.nodes.Length; ++i) {
                auto n = g_Doc.nodes[i];
                if (n is null || n.parentIx >= 0) continue;
                rootIxs.InsertLast(int(i));
            }
            if (targetPos < 0 || targetPos >= int(rootIxs.Length)) return false;

            int targetRootIx = rootIxs[uint(targetPos)];
            if (targetRootIx == nodeIx) return true;

            array<int> order;
            order.Resize(g_Doc.nodes.Length);
            for (uint i = 0; i < order.Length; ++i) order[i] = int(i);
            int tmp = order[uint(nodeIx)];
            order[uint(nodeIx)] = order[uint(targetRootIx)];
            order[uint(targetRootIx)] = tmp;

            _PushUndoSnapshot();
            if (!_ReorderDocumentNodes(order)) return false;
            _UpdateDirtyState();
            _QueueAutoPreview();
            return true;
        }

        void _InitAuthoringDefaults(UiNav::Builder::BuilderNode@ n, int siblingCount = 0) {
            if (n is null || n.typed is null) return;

            float dx = float(siblingCount % 8) * 6.0f;
            float dy = float(siblingCount % 8) * -4.0f;
            n.typed.pos = vec2(dx, dy);

            if (n.kind == "frame") {
                n.typed.size = vec2(160.0f, 90.0f);
                n.typed.z = 0.0f;
                return;
            }
            if (n.kind == "quad") {
                n.typed.size = vec2(36.0f, 20.0f);
                n.typed.bgColor = "09f";
                n.typed.opacity = 1.0f;
                n.typed.z = 4.0f;
                return;
            }
            if (n.kind == "label") {
                n.typed.size = vec2(40.0f, 8.0f);
                n.typed.text = "New Label";
                n.typed.textColor = "fff";
                n.typed.textSize = 2.0f;
                n.typed.z = 6.0f;
                return;
            }
            if (n.kind == "entry" || n.kind == "textedit") {
                n.typed.size = vec2(50.0f, 8.0f);
                n.typed.value = "Type here";
                n.typed.textColor = "fff";
                n.typed.textSize = 1.5f;
                n.typed.z = 6.0f;
                return;
            }
        }

        float _ComputeAbsScaleAtIx(int nodeIx) {
            if (g_Doc is null) return 1.0f;
            float s = 1.0f;
            int cur = nodeIx;
            int guard = 0;
            while (cur >= 0 && cur < int(g_Doc.nodes.Length) && guard < 512) {
                guard++;
                auto n = g_Doc.nodes[uint(cur)];
                if (n is null || n.typed is null) break;
                s *= n.typed.scale;
                cur = n.parentIx;
            }
            return s;
        }

        int AddNode(const string &in kindRaw, int parentIx = -1) {
            _EnsureDoc();
            string kind = kindRaw.Trim().ToLower();
            if (kind.Length == 0) kind = "frame";
            if (!_IsKnownKind(kind)) kind = "generic";

            if (parentIx < -1 || parentIx >= int(g_Doc.nodes.Length)) parentIx = -1;
            if (parentIx >= 0) {
                auto maybeParent = g_Doc.nodes[uint(parentIx)];
                if (!_NodeCanContainChildren(maybeParent)) {
                    parentIx = maybeParent is null ? -1 : maybeParent.parentIx;
                }
            }

            _PushUndoSnapshot();

            if (parentIx < 0 && g_Doc.nodes.Length == 0 && kind != "frame") {
                auto root = _NewNode("frame", -1);
                root.tagName = "frame";
                _InitAuthoringDefaults(root, 0);
                g_Doc.nodes.InsertLast(root);
                parentIx = int(g_Doc.nodes.Length) - 1;
            }

            int siblingCount = 0;
            if (parentIx >= 0 && parentIx < int(g_Doc.nodes.Length)) {
                auto p = g_Doc.nodes[uint(parentIx)];
                if (p !is null) siblingCount = int(p.childIx.Length);
            } else {
                siblingCount = _CountRootNodes(g_Doc);
            }

            auto n = _NewNode(kind, parentIx);
            n.tagName = kind;
            _InitAuthoringDefaults(n, siblingCount);

            if (parentIx >= 0 && n.typed !is null) {
                float parentAbsScale = _ComputeAbsScaleAtIx(parentIx);
                if (Math::Abs(parentAbsScale) > 0.0001f && Math::Abs(parentAbsScale - 1.0f) > 0.0001f) {
                    n.typed.pos /= parentAbsScale;
                    n.typed.size /= parentAbsScale;
                    if (n.kind == "label" || n.kind == "entry" || n.kind == "textedit") {
                        n.typed.textSize /= parentAbsScale;
                    }
                }
            }

            int ix = int(g_Doc.nodes.Length);
            g_Doc.nodes.InsertLast(n);
            if (parentIx >= 0) {
                auto p = g_Doc.nodes[uint(parentIx)];
                if (p !is null) p.childIx.InsertLast(ix);
            }

            _RebuildNodeIndex(g_Doc);
            g_SelectedNodeIx = ix;
            _UpdateDirtyState();
            _QueueAutoPreview();
            g_Status = "Added node: " + kind + ".";
            return ix;
        }

        void _MarkDeleteRecursive(int nodeIx, array<bool> &inout marks) {
            if (nodeIx < 0 || nodeIx >= int(marks.Length)) return;
            if (marks[uint(nodeIx)]) return;
            marks[uint(nodeIx)] = true;

            if (g_Doc is null) return;
            if (nodeIx >= int(g_Doc.nodes.Length)) return;
            auto n = g_Doc.nodes[uint(nodeIx)];
            if (n is null) return;
            for (uint i = 0; i < n.childIx.Length; ++i) {
                _MarkDeleteRecursive(n.childIx[i], marks);
            }
        }

        bool DeleteNode(int nodeIx) {
            _EnsureDoc();
            if (nodeIx < 0 || nodeIx >= int(g_Doc.nodes.Length)) return false;

            _PushUndoSnapshot();

            array<bool> marks;
            marks.Resize(g_Doc.nodes.Length);
            for (uint i = 0; i < marks.Length; ++i) marks[i] = false;
            _MarkDeleteRecursive(nodeIx, marks);

            array<int> remap;
            remap.Resize(g_Doc.nodes.Length);
            for (uint i = 0; i < remap.Length; ++i) remap[i] = -1;

            array<UiNav::Builder::BuilderNode@> newNodes;
            for (uint i = 0; i < g_Doc.nodes.Length; ++i) {
                if (marks[i]) continue;
                remap[i] = int(newNodes.Length);
                newNodes.InsertLast(_CloneNode(g_Doc.nodes[i]));
            }

            for (uint i = 0; i < newNodes.Length; ++i) {
                auto n = newNodes[i];
                if (n is null) continue;
                if (n.parentIx >= 0) n.parentIx = remap[uint(n.parentIx)];

                array<int> children;
                for (uint c = 0; c < n.childIx.Length; ++c) {
                    int oldIx = n.childIx[c];
                    if (oldIx < 0 || oldIx >= int(remap.Length)) continue;
                    int mapped = remap[uint(oldIx)];
                    if (mapped >= 0) children.InsertLast(mapped);
                }
                n.childIx = children;
            }

            g_Doc.nodes = newNodes;
            _RebuildNodeIndex(g_Doc);

            if (nodeIx >= 0 && nodeIx < int(remap.Length)) {
                int mappedSel = remap[uint(nodeIx)];
                g_SelectedNodeIx = mappedSel >= 0 ? mappedSel :-1;
            } else {
                g_SelectedNodeIx = -1;
            }

            _UpdateDirtyState();
            _QueueAutoPreview();
            g_Status = "Deleted node/subtree.";
            return true;
        }

        bool _IsAncestor(int nodeIx, int maybeAncestor) {
            if (nodeIx < 0 || maybeAncestor < 0) return false;
            if (nodeIx >= int(g_Doc.nodes.Length) || maybeAncestor >= int(g_Doc.nodes.Length)) return false;
            int cur = nodeIx;
            while (cur >= 0 && cur < int(g_Doc.nodes.Length)) {
                if (cur == maybeAncestor) return true;
                auto n = g_Doc.nodes[uint(cur)];
                if (n is null) break;
                cur = n.parentIx;
            }
            return false;
        }

        bool _CanMoveNodeTo(int nodeIx, int newParentIx) {
            _EnsureDoc();
            if (nodeIx < 0 || nodeIx >= int(g_Doc.nodes.Length)) return false;
            if (newParentIx >= int(g_Doc.nodes.Length)) return false;
            if (newParentIx == nodeIx) return false;
            if (newParentIx >= 0 && _IsAncestor(newParentIx, nodeIx)) return false;

            auto node = g_Doc.nodes[uint(nodeIx)];
            if (node is null) return false;
            if (newParentIx >= 0) {
                auto parent = g_Doc.nodes[uint(newParentIx)];
                if (!_NodeCanContainChildren(parent)) return false;
            }
            return true;
        }

        bool MoveNode(int nodeIx, int newParentIx) {
            _EnsureDoc();
            if (!_CanMoveNodeTo(nodeIx, newParentIx)) return false;

            auto node = g_Doc.nodes[uint(nodeIx)];
            if (node is null) return false;
            int oldParent = node.parentIx;
            if (oldParent == newParentIx) return true;

            _PushUndoSnapshot();

            if (oldParent >= 0 && oldParent < int(g_Doc.nodes.Length)) {
                auto p = g_Doc.nodes[uint(oldParent)];
                if (p !is null) {
                    for (uint i = 0; i < p.childIx.Length; ++i) {
                        if (p.childIx[i] == nodeIx) {
                            p.childIx.RemoveAt(i);
                            break;
                        }
                    }
                }
            }

            node.parentIx = newParentIx;
            if (newParentIx >= 0) {
                auto p2 = g_Doc.nodes[uint(newParentIx)];
                if (p2 !is null) p2.childIx.InsertLast(nodeIx);
            }

            _UpdateDirtyState();
            _QueueAutoPreview();
            g_Status = "Moved node.";
            return true;
        }

        bool MoveNodeToRootAction(int nodeIx) {
            _EnsureDoc();
            if (nodeIx < 0 || nodeIx >= int(g_Doc.nodes.Length)) {
                g_Status = "Move failed: invalid node.";
                return false;
            }

            auto node = g_Doc.nodes[uint(nodeIx)];
            if (node is null) {
                g_Status = "Move failed: node is unavailable.";
                return false;
            }
            if (node.parentIx < 0) {
                g_Status = "Node is already at root.";
                return false;
            }

            if (!MoveNode(nodeIx, -1)) {
                g_Status = "Move failed (invalid parent or cycle).";
                return false;
            }

            g_Status = "Moved node to root.";
            return true;
        }

        bool MoveNodeOutOneLevel(int nodeIx) {
            _EnsureDoc();
            if (nodeIx < 0 || nodeIx >= int(g_Doc.nodes.Length)) {
                g_Status = "Move failed: invalid node.";
                return false;
            }

            auto node = g_Doc.nodes[uint(nodeIx)];
            if (node is null) {
                g_Status = "Move failed: node is unavailable.";
                return false;
            }
            if (node.parentIx < 0) {
                g_Status = "Node is already at root.";
                return false;
            }

            auto parent = g_Doc.nodes[uint(node.parentIx)];
            int grandParentIx = parent is null ? -1 : parent.parentIx;
            if (!MoveNode(nodeIx, grandParentIx)) {
                g_Status = "Move failed (invalid parent or cycle).";
                return false;
            }

            g_Status = grandParentIx >= 0 ?
            ("Moved node out one level under [" + grandParentIx + "].") : "Moved node to root.";
            return true;
        }

        bool MoveNodeSiblingOrder(int nodeIx, int delta) {
            _EnsureDoc();
            if (delta == 0) return true;

            int parentIx = -1;
            int siblingPos = -1;
            int siblingCount = 0;
            if (!_GetNodeSiblingContext(nodeIx, parentIx, siblingPos, siblingCount)) {
                g_Status = "Move failed: node is not in a sibling list.";
                return false;
            }

            int targetPos = siblingPos + delta;
            if (targetPos < 0) {
                g_Status = "Node is already first among siblings.";
                return false;
            }
            if (targetPos >= siblingCount) {
                g_Status = "Node is already last among siblings.";
                return false;
            }

            if (parentIx < 0) {
                if (!_MoveRootNodeSiblingOrder(nodeIx, delta)) {
                    g_Status = "Move failed: could not reorder root nodes.";
                    return false;
                }
            } else {
                auto parent = g_Doc.nodes[uint(parentIx)];
                if (parent is null) {
                    g_Status = "Move failed: parent is unavailable.";
                    return false;
                }

                _PushUndoSnapshot();
                int movingIx = parent.childIx[uint(siblingPos)];
                parent.childIx.RemoveAt(uint(siblingPos));
                parent.childIx.InsertAt(uint(targetPos), movingIx);
                _UpdateDirtyState();
                _QueueAutoPreview();
            }

            g_Status = delta < 0 ? "Moved node up among siblings." : "Moved node down among siblings.";
            return true;
        }

        int _SetFrameClipActiveInDoc(UiNav::Builder::BuilderDocument@ doc, bool active) {
            if (doc is null) return 0;
            int changed = 0;
            for (uint i = 0; i < doc.nodes.Length; ++i) {
                auto n = doc.nodes[i];
                if (n is null || n.typed is null) continue;
                if (n.kind != "frame") continue;
                if (n.typed.clipActive == active) continue;
                n.typed.clipActive = active;
                changed++;
            }
            return changed;
        }

        int DisableAllFrameClipping(bool pushUndo = true, bool applyPreviewNow = true) {
            _EnsureDoc();

            int activeCount = 0;
            for (uint i = 0; i < g_Doc.nodes.Length; ++i) {
                auto n = g_Doc.nodes[i];
                if (n is null || n.typed is null) continue;
                if (n.kind != "frame") continue;
                if (n.typed.clipActive) activeCount++;
            }
            if (activeCount <= 0) {
                g_Status = "No active frame clipping found.";
                return 0;
            }

            if (pushUndo) _PushUndoSnapshot();
            int changed = _SetFrameClipActiveInDoc(g_Doc, false);

            _UpdateDirtyState();
            _QueueAutoPreview();
            if (applyPreviewNow && !S_AutoLivePreview) _ApplyPreviewLayerInternal(false);

            g_Status = "Disabled frame clipping on " + changed + " frame(s).";
            return changed;
        }

        bool ImportFromXmlText(
            const string &in xmlText,
            const string &in sourceKind = "import_xml",
            const string &in sourceLabel = "",
            bool centerAfterImport = false
        ) {
            string txt = xmlText.Trim();
            if (txt.Length == 0) {
                g_Status = "Import failed: XML is empty.";
                return false;
            }

            auto doc = ImportFromXml(xmlText, sourceKind, sourceLabel);
            if (doc is null) {
                g_Status = "Import failed: parser returned null document.";
                return false;
            }

            _ResetDocument(doc);
            int strippedClip = 0;
            if (S_StripFrameClippingOnImport) strippedClip = _SetFrameClipActiveInDoc(g_Doc, false);
            bool centered = false;
            if (centerAfterImport) centered = _CenterDocumentRoots(g_Doc);
            g_BaselineXml = ExportToXml(g_Doc);
            g_Doc.dirty = false;
            g_LastExportXml = g_BaselineXml;
            _QueueAutoPreview();
            g_Status = "Imported XML: " + g_Doc.nodes.Length + " nodes.";
            if (strippedClip > 0) g_Status += " Stripped clipping on " + strippedClip + " frame(s).";
            if (centerAfterImport) {
                g_Status += centered ? " Centered copy at screen center." : " Centering skipped.";
            }
            return true;
        }

        bool ImportFromLiveLayer(int appKind, int layerIx) {
            auto layer = _GetLayerByKindIx(appKind, layerIx);
            if (layer is null) {
                g_Status = "Import failed: layer not found (app_kind=" + appKind + ", layer_ix=" + layerIx + ").";
                return false;
            }

            string xml = _GetLayerXml(layer);
            if (xml.Length == 0) {
                g_Status = "Import failed: layer XML is empty.";
                return false;
            }

            string label = "app=" + appKind + " layer=" + layerIx;
            return ImportFromXmlText(xml, "import_live_layer", label, S_CenterImportedLiveCopy);
        }

    }
}
