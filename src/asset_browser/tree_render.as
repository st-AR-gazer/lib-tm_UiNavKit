namespace UiNavKit {
    namespace AssetBrowser {

        void _MlBrowserRenderTreeNode(MlBrowserTreeNode@ node) {
            if (node is null) return;
            UI::PushID("ml-browser-tree-" + node.key);
            if (node.isFile) {
                bool isSel = node.entry !is null && g_MlBrowserSelectedUrl == node.entry.url;
                bool isFav = node.entry !is null && _MlBrowserIsFavorite(node.entry.url);
                if (node.entry !is null) g_MlBrowserVisibleUrls.InsertLast(node.entry.url);

                string ext = _MlBrowserFileExtension(node.name);
                string color = _MlBrowserFileColorCode(ext);
                string icon = _MlBrowserFileIcon(ext);
                string favStar = isFav ? " \\$ff6" + Icons::Star + "\\$z" : "";
                string label = color + icon + "\\$z " + node.name + favStar;

                if (UI::Selectable(label + "##ml-browser-file", isSel) && node.entry !is null) _MlBrowserSelectUrl(node.entry.url);
                if (isSel && g_MlBrowserScrollToSelection) {
                    UI::SetScrollHereY();
                    g_MlBrowserScrollToSelection = false;
                }

                if (isSel) {
                    vec4 r = UI::GetItemRect();
                    vec4 box = vec4(r.x - 2.0f, r.y - 1.0f, r.z + 2.0f, r.w + 1.0f);
                    auto dl = UI::GetWindowDrawList();
                    dl.AddRectFilled(box, vec4(0.28f, 0.62f, 1.0f, 0.11f));
                    dl.AddRect(box, vec4(0.40f, 0.74f, 1.0f, 0.48f));
                }

                if (UI::IsItemHovered() && node.entry !is null) {
                    UI::SetTooltip("Source: " + node.entry.source + "\nKind: " + node.entry.kind + (ext.Length > 0 ? "\nType: " + ext.ToUpper() : "") + "\n" + node.entry.url);
                }
                UI::PopID();
                return;
            }

            int fileCount = 0;
            int folderCount = 0;
            for (uint c = 0; c < node.children.Length; ++c) {
                if (node.children[c] !is null) {
                    if (node.children[c].isFile) {
                        fileCount++;
                    } else {
                        folderCount++;
                    }
                }
            }
            string folderLabel = "\\$cef" + Icons::FolderO + "\\$z " + node.name;
            if (fileCount > 0 || folderCount > 0) {
                folderLabel += " \\$888(" + (fileCount > 0 ? tostring(fileCount) + "f" : "")
                    + (fileCount > 0 && folderCount > 0 ? " " : "")
                    + (folderCount > 0 ? tostring(folderCount) + "d" : "") + ")\\$z";
            }

            bool open = UI::TreeNode(folderLabel);
            bool folderSelected = g_MlBrowserSelectedFolderKey == node.key;
            if (folderSelected) {
                vec4 r = UI::GetItemRect();
                vec4 box = vec4(r.x - 2.0f, r.y - 1.0f, r.z + 2.0f, r.w + 1.0f);
                auto dl = UI::GetWindowDrawList();
                dl.AddRectFilled(box, vec4(0.98f, 0.78f, 0.28f, 0.08f));
                dl.AddRect(box, vec4(0.98f, 0.78f, 0.28f, 0.40f));
            }
            if (UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right)) {
                _MlBrowserSelectFolder(node.key, node.name);
            }
            if (open) {
                for (uint i = 0; i < node.children.Length; ++i) {
                    _MlBrowserRenderTreeNode(node.children[i]);
                }
                UI::TreePop();
            }
            UI::PopID();
        }

    }
}
