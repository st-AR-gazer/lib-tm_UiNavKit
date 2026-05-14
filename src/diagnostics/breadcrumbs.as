namespace UiNavKit {
    namespace Diagnostics {

        [Setting hidden name="UiNav debug: diag step logs"]
        bool S_DiagStepLogs = false;

        [Setting hidden name="UiNav debug: diag verbose (spammy)"]
        bool S_DiagVerbose = false;

        [Setting hidden name="UiNav debug: breadcrumb file enabled"]
        bool S_DiagBreadcrumbFile = false;

        [Setting hidden name="UiNav debug: breadcrumb file path"]
        string S_DiagBreadcrumbPath = IO::FromStorageFolder("Diagnostics/uinav_debug_breadcrumb.txt");

        [Setting hidden name="UiNav debug: breadcrumb throttle (ms, 0 = always)"]
        uint S_DiagBreadcrumbThrottleMs = 25;

        uint g_DiagBreadcrumbLastWriteMs = 0;
        string g_DiagBreadcrumbLastStep = "";
        string g_DiagBreadcrumbLastFn = "";

        void _DiagBreadcrumb(const string &in step, const string &in fn = "UiNavDebug", bool forceWrite = false) {
            g_DiagBreadcrumbLastStep = step;
            g_DiagBreadcrumbLastFn = fn;

            if (!S_DiagBreadcrumbFile) return;
            if (S_DiagBreadcrumbPath.Length == 0) return;

            uint now = Time::Now;
            if (!forceWrite && S_DiagBreadcrumbThrottleMs > 0) {
                uint delta = now - g_DiagBreadcrumbLastWriteMs;
                if (delta < S_DiagBreadcrumbThrottleMs) return;
            }

            g_DiagBreadcrumbLastWriteMs = now;

            string ts = Time::FormatString("%Y-%m-%d %H:%M:%S");
            string msg = ts + " | " + g_DiagBreadcrumbLastFn + " | " + g_DiagBreadcrumbLastStep + "\n";
            msg += "mode=" + (g_Mode == Mode::ML ? "ML" : "ControlTree")
                + " mlAppKind=" + g_MlActiveAppKind
                + " mlSearchLen=" + g_MlSearch.Length
                + " mlViewLayerIx=" + g_MlViewLayerIndex
                + " controlTreeOverlay=" + g_ControlTreeOverlay
                + " controlTreeSearchLen=" + g_ControlTreeSearch.Length
                + " selMl=" + g_SelectedMlUiPath
                + " selControlTree=" + g_SelectedControlTreeUiPath
                + "\n";
            _IO::File::WriteFile(S_DiagBreadcrumbPath, msg, false);
        }

        bool _DiagShouldLog(bool force = false) {
            if (!S_DiagStepLogs) return false;
            if (S_DiagVerbose) return true;
            return force;
        }

        void _DiagStep(const string &in step, const string &in fn = "UiNavDebug", bool force = false) {
            _DiagBreadcrumb(step, fn, force);
            if (!_DiagShouldLog(force)) return;
            log("UiNavDebug STEP " + step, LogLevel::Info, 61, "UiNavKit::Diagnostics::_DiagStep");
        }

    }
}
