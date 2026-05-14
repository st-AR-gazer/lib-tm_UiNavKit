[SettingsTab name="General" icon="Cog" order="1"]
void RenderUiNavGeneralSettingsTab() {
    UiNavKit::App::RenderGeneralSettingsUI();
}

[SettingsTab name="Selector" icon="Crosshairs" order="2"]
void RenderUiNavSelectorSettingsTab() {
    UiNavKit::Builder::RenderSelectorSettingsUI();
}

[SettingsTab name="ManiaLink UI" icon="FolderO" order="3"]
void RenderUiNavManiaLinkSettingsTab() {
    UiNavKit::App::RenderManiaLinkUiSettingsUI();
}

[SettingsTab name="ControlTree UI" icon="ShareSquareO" order="4"]
void RenderUiNavControlTreeUiSettingsTab() {
    UiNavKit::App::RenderControlTreeUiSettingsUI();
}

[SettingsTab name="ManiaLink Builder" icon="PlusSquareO" order="5"]
void RenderUiNavManiaLinkBuilderSettingsTab() {
    UiNavKit::Builder::RenderSettingsUI();
}

[SettingsTab name="ManiaLink Browser" icon="FolderOpenO" order="6"]
void RenderUiNavManiaLinkBrowserSettingsTab() {
    UiNavKit::App::RenderManiaLinkBrowserSettingsUI();
}

[SettingsTab name="Diagnostics" icon="ExclamationTriangle" order="7"]
void RenderUiNavDiagnosticsSettingsTab() {
    UiNavKit::App::RenderDiagnosticsSettingsUI();
}

[SettingsTab name="Logging" icon="ListAlt" order="99"]
void RenderUiNavLoggingSettingsTab() {
    logging::RenderSettingsUI("uinavkit-logging");
}
