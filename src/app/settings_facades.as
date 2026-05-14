namespace UiNavKit {
    namespace App {

        void RenderGeneralSettingsUI() {
            UiNavKit::_EnsureUiStateInit();
            bool open = UI::BeginChild(
                "##uinav-settings-general-root",
                vec2(0, 0),
                false,
                UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse
            );
            if (open) {
                UI::Text("UiNavKit - General");
                UI::TextDisabled("Shared maintenance actions for all UiNavKit tools.");
                UI::Separator();
                UiNavKit::_RenderUiNavOwnedLayersCleanupBar();
            }
            UI::EndChild();
        }

        void RenderManiaLinkUiSettingsUI() {
            UiNavKit::_EnsureUiStateInit();
            bool open = UI::BeginChild(
                "##uinav-settings-ml-root",
                vec2(0, 0),
                false,
                UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse
            );
            if (open) {
                UI::Text("UiNavKit - ManiaLink UI Inspector");
                UiNavKit::Inspectors::ManiaLink::_RenderMlTab();
            }
            UI::EndChild();
        }

        void RenderControlTreeUiSettingsUI() {
            UiNavKit::_EnsureUiStateInit();
            bool open = UI::BeginChild(
                "##uinav-settings-controltree-root",
                vec2(0, 0),
                false,
                UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse
            );
            if (open) {
                UI::Text("UiNavKit - ControlTree UI Inspector");
                UiNavKit::Inspectors::ControlTree::_RenderControlTreeTab();
            }
            UI::EndChild();
        }

        void RenderManiaLinkBrowserSettingsUI() {
            UiNavKit::_EnsureUiStateInit();
            bool open = UI::BeginChild(
                "##uinav-settings-browser-root",
                vec2(0, 0),
                false,
                UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoScrollWithMouse
            );
            if (open) {
                UI::Text("UiNavKit - ManiaLink Browser");
                UiNavKit::AssetBrowser::_RenderMlBrowserTab();
            }
            UI::EndChild();
        }

        void RenderDiagnosticsSettingsUI() {
            UiNavKit::_EnsureUiStateInit();
            bool diagOpen = UI::BeginChild("##uinav-settings-diag-root", vec2(0, 0), false);
            if (diagOpen) {
                UI::Text("UiNavKit - Diagnostics");
                UI::TextDisabled("Crash breadcrumbs, trace buffer, and runtime diagnostics.");
                UI::Separator();
                UiNavKit::Diagnostics::_RenderDiagnosticsPanel();
            }
            UI::EndChild();
        }

    }
}
