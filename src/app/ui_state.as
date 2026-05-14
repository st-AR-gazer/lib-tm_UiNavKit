namespace UiNavKit {

    void _EnsureUiStateInit() {
        if (!g_WidthsInit) {
            g_MlTreeWidth = S_MlTreeWidth;
            g_ControlTreeTreeWidth = S_ControlTreeTreeWidth;
            g_WidthsInit = true;
        }
    }
}
