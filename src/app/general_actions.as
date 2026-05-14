namespace UiNavKit {

    void _DestroyAllUiNavOwnedLayersNow() {
        UiNavKit::Runtime::DestroyAllOwnedGlobal();
        uint swept = UiNavKit::Runtime::LastDestroyAllOwnedSweepCount();
        g_UiNavOwnedLayerCleanupStatus = "Destroyed all UiNav-owned layers (registry + prefix sweep: " + swept + ").";
        UI::ShowNotification("UiNavKit", g_UiNavOwnedLayerCleanupStatus, 4500);
    }

    void _RenderUiNavOwnedLayersCleanupBar() {
        if (UI::Button("Destroy all UiNav layers")) {
            _DestroyAllUiNavOwnedLayersNow();
        }
        UI::SameLine();
        UI::TextDisabled("Clears plugin-owned layers (typically UiNav_*)");
        if (g_UiNavOwnedLayerCleanupStatus.Length > 0) UI::Text(g_UiNavOwnedLayerCleanupStatus);
    }
}
