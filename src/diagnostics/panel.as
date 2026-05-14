namespace UiNavKit {
    namespace Diagnostics {

        void _RenderDiagnosticsBreadcrumbsTab() {
            S_DiagBreadcrumbFile = UI::Checkbox("Enabled##diag-bc", S_DiagBreadcrumbFile);
            if (UI::IsItemHovered()) UI::SetTooltip("Write last-known step to a file for post-crash analysis");

            UI::SetNextItemWidth((UI::GetContentRegionAvail().x - 38.0f) * 0.5f);
            S_DiagBreadcrumbPath = UI::InputText("##diag-bc-path", S_DiagBreadcrumbPath);
            if (UI::IsItemHovered()) UI::SetTooltip(S_DiagBreadcrumbPath);
            UI::SameLine();
            if (UI::Button(Icons::FolderOpenO + "##diag-bc-open")) {
                string folder = Path::GetDirectoryName(S_DiagBreadcrumbPath);
                if (folder.Length == 0) folder = IO::FromStorageFolder("Diagnostics");
                _IO::OpenFolder(folder, true);
            }
            if (UI::IsItemHovered()) UI::SetTooltip("Open breadcrumb folder");

            UI::SetNextItemWidth(120.0f);
            int bcThrottle = int(S_DiagBreadcrumbThrottleMs);
            bcThrottle = UI::InputInt("Throttle (ms)##diag-bc", bcThrottle);
            if (bcThrottle < 0) bcThrottle = 0;
            S_DiagBreadcrumbThrottleMs = uint(bcThrottle);

            if (g_DiagBreadcrumbLastStep.Length > 0) {
                string lastInfo = "\\$bff" + Icons::ChevronRight + "\\$z " + g_DiagBreadcrumbLastStep;
                if (g_DiagBreadcrumbLastFn.Length > 0) lastInfo += "  \\$888(" + g_DiagBreadcrumbLastFn + ")\\$z";
                UI::Text(lastInfo);
            } else {
                UI::TextDisabled("No breadcrumb step recorded yet.");
            }
        }

        void _RenderDiagnosticsTraceTab() {
            bool traceEnabled = UiNav::Trace::Enabled();
            bool nextEnabled = UI::Checkbox("Enabled##diag-tr", traceEnabled);
            if (nextEnabled != traceEnabled) UiNav::Trace::SetEnabled(nextEnabled);
            UI::SameLine();
            UI::SetNextItemWidth(120.0f);
            int trMax = int(UiNav::Trace::MaxEntries());
            trMax = UI::InputInt("Max entries##diag-tr", trMax);
            if (trMax < 0) trMax = 0;
            if (uint(trMax) != UiNav::Trace::MaxEntries()) UiNav::Trace::SetMaxEntries(uint(trMax));

            if (UI::Button(Icons::Play + " Dump##diag-tr")) UiNav::Trace::DumpToLog();
            if (UI::IsItemHovered()) UI::SetTooltip("Dump trace entries to Openplanet log");
            UI::SameLine();
            if (UI::Button(Icons::TrashO + " Clear##diag-tr")) UiNav::Trace::Clear();
            if (UI::IsItemHovered()) UI::SetTooltip("Clear all trace entries");
            UI::SameLine();
            if (UI::Button(Icons::Clipboard + " Copy##diag-tr")) {
                string traceText = UiNav::Trace::SnapshotText();
                IO::SetClipboard(traceText.Length > 0 ? traceText : "(empty trace)");
            }
            if (UI::IsItemHovered()) UI::SetTooltip("Copy trace buffer to clipboard");

            float trViewH = 180.0f;
            if (UI::BeginChild("##diag-tr-viewer", vec2(0, trViewH), true)) {
                string snapshot = UiNav::Trace::SnapshotText();
                if (snapshot.Length == 0) {
                    UI::TextDisabled("Trace is empty.");
                    UI::TextDisabled("Enable trace and interact with UiNav to populate.");
                } else {
                    array<string> lines = snapshot.Split("\n");
                    for (uint ti = 0; ti < lines.Length; ++ti) {
                        string line = lines[ti].Trim();
                        if (line.Length == 0) continue;
                        UI::Text("\\$888" + line + "\\$z");
                    }
                }
            }
            UI::EndChild();
        }

        void _RenderDiagnosticsStepLogsTab() {
            S_DiagStepLogs = UI::Checkbox("Enable step logs##diag-sl", S_DiagStepLogs);
            if (UI::IsItemHovered()) UI::SetTooltip("Log per-operation diagnostic steps to Openplanet log");
            UI::SameLine();
            S_DiagVerbose = UI::Checkbox("Verbose##diag-sl", S_DiagVerbose);
            if (UI::IsItemHovered()) UI::SetTooltip("Include all verbose steps (very spammy!)");
            UI::TextDisabled("Step logs write per-operation entries to the Openplanet log.");
            if (S_DiagVerbose) {
                UI::Text("\\$fa0" + Icons::ExclamationTriangle + " Verbose mode active \\$888- expect heavy log output.\\$z");
            }
        }

        void _RenderDiagnosticsRequestPumpTab() {
            int policy = UiNav::Dump::GetRequestPumpPolicy();
            const string[] policyLabels = {"Disabled", "Dev-only", "Always"};
            const string[] policyColors = {"\\$888", "\\$fd8", "\\$9fd"};

            UI::SetNextItemWidth(200.0f);
            policy = UI::SliderInt("##diag-rp-slider", policy, 0, 2);
            UiNav::Dump::SetRequestPumpPolicy(policy);
            if (policy >= 0 && policy < int(policyLabels.Length)) {
                UI::SameLine();
                UI::Text(policyColors[policy] + policyLabels[policy] + "\\$z");
            }

            bool pumpActive = UiNav::Dump::RequestPumpEnabledNow();
            UI::Text("Pump: " + (pumpActive ? "\\$9fd" + Icons::Play + " Active\\$z" : "\\$888" + Icons::Stop + " Inactive\\$z"));
        }

        void _RenderDiagnosticsPanel() {
            string bcIndicator = S_DiagBreadcrumbFile ? " \\$9fd" + Icons::Play + "\\$z" : " \\$888" + Icons::Stop + "\\$z";
            string trCountLabel = " \\$888[" + UiNav::Trace::EntryCount() + "/" + UiNav::Trace::MaxEntries() + "]\\$z";
            string trIndicator = UiNav::Trace::Enabled() ? " \\$9fd" + Icons::Play + "\\$z" : " \\$888" + Icons::Stop + "\\$z";
            string slIndicator = S_DiagStepLogs ? " \\$9fd" + Icons::Play + "\\$z" : " \\$888" + Icons::Stop + "\\$z";

            UI::Text(Icons::Wrench + " Crash Breadcrumbs" + bcIndicator);
            _RenderDiagnosticsBreadcrumbsTab();
            UI::Separator();

            UI::Text(Icons::Refresh + " Trace Ring Buffer" + trIndicator + trCountLabel);
            _RenderDiagnosticsTraceTab();
            UI::Separator();

            UI::Text(Icons::Cog + " Step Logging" + slIndicator);
            _RenderDiagnosticsStepLogsTab();
            UI::Separator();

            UI::Text(Icons::PlayCircleO + " Integration Fixtures");
            RenderIntegrationFixturesUI();
            UI::Separator();

            UI::Text(Icons::Exchange + " Request Pump Policy");
            _RenderDiagnosticsRequestPumpTab();
        }

    }
}
