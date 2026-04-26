namespace UiNavKit {
namespace Debug {

    enum IntegrationFixtureOutcome {
        Pass = 0,
        Fail = 1,
        Skip = 2
    }

    enum IntegrationFixtureCategory {
        SelfContainedWrite = 0,
        ControlTreeRead = 1,
        ConsumerFlow = 2
    }

    class IntegrationFixtureLine {
        string id;
        string title;
        IntegrationFixtureCategory category = IntegrationFixtureCategory::SelfContainedWrite;
        IntegrationFixtureOutcome outcome = IntegrationFixtureOutcome::Pass;
        string detail;
    }

    array<IntegrationFixtureLine@> g_IntegrationFixtureLines;
    string g_IntegrationFixtureStatus = "Integration fixtures not run yet.";
    bool g_IntegrationFixturesLastRunOk = false;
    bool g_IntegrationFixturesRunning = false;
    uint g_IntegrationFixturesLastRunMs = 0;
    string g_IntegrationFixturesLastRunLabel = "";

    void _PushIntegrationFixture(const string &in id, const string &in title, IntegrationFixtureCategory category,
        IntegrationFixtureOutcome outcome, const string &in detail)
    {
        auto line = IntegrationFixtureLine();
        line.id = id;
        line.title = title;
        line.category = category;
        line.outcome = outcome;
        line.detail = detail;
        g_IntegrationFixtureLines.InsertLast(line);
    }

    string _IntegrationCategoryLabel(IntegrationFixtureCategory category) {
        if (category == IntegrationFixtureCategory::SelfContainedWrite) return "Write";
        if (category == IntegrationFixtureCategory::ControlTreeRead) return "CT Read";
        return "Consumer";
    }

    string _IntegrationOutcomeLabel(IntegrationFixtureOutcome outcome) {
        if (outcome == IntegrationFixtureOutcome::Pass) return "PASS";
        if (outcome == IntegrationFixtureOutcome::Fail) return "FAIL";
        return "SKIP";
    }

    vec4 _IntegrationOutcomeColor(IntegrationFixtureOutcome outcome) {
        if (outcome == IntegrationFixtureOutcome::Pass) return vec4(0.30f, 0.85f, 0.45f, 1.0f);
        if (outcome == IntegrationFixtureOutcome::Fail) return vec4(0.95f, 0.35f, 0.35f, 1.0f);
        return vec4(0.90f, 0.78f, 0.38f, 1.0f);
    }

    string _FixtureOpSummary(const OpResult@ res) {
        if (res is null) return "null result";
        string summary = res.code.Length > 0 ? res.code : ("status=" + tostring(int(res.status)));
        if (res.reason.Length > 0) summary += " | " + res.reason;
        if (res.detail.Length > 0 && res.detail != res.reason) summary += " | " + res.detail;
        return summary;
    }

    Target@ _NewCtFixtureTarget(const string &in name, uint overlay, const string &in selector,
        bool anyRoot = false, bool requireVisible = true)
    {
        return UiNav::Targets::ControlTree(name, overlay, selector, anyRoot, 0, 24, requireVisible);
    }

    Target@ _NewMlFixtureTarget(const string &in name, ManiaLinkSource source, const string &in pageNeedle,
        const string &in rootControlId, const string &in selector)
    {
        return UiNav::Targets::ManiaLink(name, source, pageNeedle, selector, rootControlId);
    }

    bool _FixtureOwnedMlWriteRoundtrip(string &out detail, bool &out skipped) {
        skipped = false;
        detail = "";

        const string key = "UiNavIntegrationFixtureWrite";
        const string pageNeedle = "UiNavIntegrationFixtureWrite";
        const string page =
            "<manialink name=\"" + pageNeedle + "\">"
            + "<frame id=\"FixtureRoot\" pos=\"0 0\" size=\"80 24\">"
            + "<entry id=\"FixtureEntry\" default=\"seed\" pos=\"0 0\" size=\"70 6\" />"
            + "<label id=\"FixtureLabel\" text=\"Fixture\" pos=\"0 10\" size=\"70 6\" />"
            + "</frame>"
            + "</manialink>";

        UiNav::ML::Layers::DestroyOwned(key);
        auto layer = UiNav::ML::Layers::EnsureOwned(key, page, ManiaLinkSource::CurrentApp, true);
        if (layer is null) {
            detail = "EnsureOwned returned null for the self-contained owned layer.";
            return false;
        }

        auto target = _NewMlFixtureTarget("Integration fixture owned entry", ManiaLinkSource::CurrentApp, pageNeedle, "FixtureRoot", "#FixtureEntry");
        UiNav::PrepareTarget(target);

        auto ready = UiNav::WaitForTargetEx(target, 1500, 33);
        if (!ready.Ok()) {
            UiNav::ML::Layers::DestroyOwned(key);
            detail = "Owned entry was not ready: " + _FixtureOpSummary(ready);
            return false;
        }

        auto set = UiNav::SetTextEx(target, "fixture-roundtrip");
        if (!set.Ok()) {
            UiNav::ML::Layers::DestroyOwned(key);
            detail = "SetTextEx failed: " + _FixtureOpSummary(set);
            return false;
        }

        auto read = UiNav::ReadTextEx(target);
        UiNav::ML::Layers::DestroyOwned(key);
        if (!read.Ok()) {
            detail = "ReadTextEx failed after roundtrip: " + _FixtureOpSummary(read);
            return false;
        }
        if (read.text != "fixture-roundtrip") {
            detail = "Roundtrip text mismatch: expected fixture-roundtrip, got \"" + read.text + "\".";
            return false;
        }

        detail = "Owned ML layer mounted, entry resolved, text written, and text read back successfully.";
        return true;
    }

    bool _FixturePlayerSearchFilterFlow(string &out detail, bool &out skipped) {
        skipped = false;
        detail = "";

        const string key = "UiNavIntegrationFixturePlayerSearch";
        const string pageNeedle = "UiNavIntegrationFixturePlayerSearch";
        const string page =
            "<manialink name=\"" + pageNeedle + "\">"
            + "<frame id=\"PlayerSearchFixtureRoot\" pos=\"0 0\" size=\"110 24\">"
            + "<label id=\"PlayerSearchFixtureTitle\" text=\"Player Search\" pos=\"0 0\" size=\"60 6\" />"
            + "<entry id=\"PlayerSearchFixtureFilter\" default=\"\" pos=\"0 8\" size=\"95 6\" />"
            + "</frame>"
            + "</manialink>";

        UiNav::ML::Layers::DestroyOwned(key);
        auto layer = UiNav::ML::Layers::EnsureOwned(key, page, ManiaLinkSource::CurrentApp, true);
        if (layer is null) {
            detail = "EnsureOwned returned null for the PlayerSearch-style fixture layer.";
            return false;
        }

        auto target = UiNav::Targets::ManiaLink(
            "PlayerSearchOnServers.FilterEntry",
            ManiaLinkSource::CurrentApp,
            pageNeedle,
            "#PlayerSearchFixtureFilter",
            "PlayerSearchFixtureRoot"
        );
        if (target is null) {
            UiNav::ML::Layers::DestroyOwned(key);
            detail = "UiNav::Targets::ManiaLink returned null.";
            return false;
        }

        UiNav::PrepareTarget(target);

        auto ready = UiNav::WaitForTargetEx(target, 1500, 33);
        if (!ready.Ok()) {
            UiNav::ML::Layers::DestroyOwned(key);
            detail = "Prepared PlayerSearch target was not ready: " + _FixtureOpSummary(ready);
            return false;
        }

        auto set1 = UiNav::SetTextEx(target, "neo");
        if (!set1.Ok()) {
            UiNav::ML::Layers::DestroyOwned(key);
            detail = "First filter write failed: " + _FixtureOpSummary(set1);
            return false;
        }
        auto read1 = UiNav::ReadTextEx(target);
        if (!read1.Ok() || read1.text != "neo") {
            UiNav::ML::Layers::DestroyOwned(key);
            detail = "First filter readback failed: " + _FixtureOpSummary(read1);
            return false;
        }

        layer.IsVisible = false;
        auto hiddenProbe = UiNav::WaitForTargetEx(target, 0, 33);
        if (hiddenProbe.Ok()) {
            layer.IsVisible = true;
            UiNav::ML::Layers::DestroyOwned(key);
            detail = "Hidden layer still reported the filter target as ready.";
            return false;
        }

        layer.IsVisible = true;
        UiNav::InvalidateTargetPlan(target);
        auto readyAgain = UiNav::WaitForTargetEx(target, 1500, 33);
        if (!readyAgain.Ok()) {
            UiNav::ML::Layers::DestroyOwned(key);
            detail = "Target did not recover after layer visibility returned: " + _FixtureOpSummary(readyAgain);
            return false;
        }

        auto set2 = UiNav::SetTextEx(target, "ar");
        if (!set2.Ok()) {
            UiNav::ML::Layers::DestroyOwned(key);
            detail = "Second filter write failed: " + _FixtureOpSummary(set2);
            return false;
        }
        auto read2 = UiNav::ReadTextEx(target);
        UiNav::ML::Layers::DestroyOwned(key);
        if (!read2.Ok() || read2.text != "ar") {
            detail = "Second filter readback failed: " + _FixtureOpSummary(read2);
            return false;
        }

        detail = "PlayerSearch-style filter target survived prepare, repeated writes, a hidden-layer miss, and a post-recovery write.";
        return true;
    }

    bool _FixtureAutoManiaCloseItemEditor(string &out detail, bool &out skipped) {
        skipped = false;
        detail = "";

        auto app = GetApp();
        if (app is null || cast<CGameEditorItem>(app.Editor) is null) {
            skipped = true;
            detail = "Item Editor is not open; open it to validate AutoMania-style close-button discovery.";
            return true;
        }

        auto exitButton = _NewCtFixtureTarget("AutoMania close button", 2, "0/4/0/0/2/0");
        auto ready = UiNav::IsReadyEx(exitButton);
        if (!ready.Ok()) {
            detail = "Exit button target did not resolve: " + _FixtureOpSummary(ready);
            return false;
        }
        if (ready.ref is null || !UiNav::CT::CanClick(ready.ref.controlTree)) {
            detail = "Exit button resolved but is not clickable through the advanced CT surface.";
            return false;
        }

        string extra = "Exit button resolved and is clickable.";
        auto dialogLabel = _NewCtFixtureTarget("AutoMania unsaved dialog label", 16, "1/0/2/0");
        auto dialogState = UiNav::IsReadyEx(dialogLabel);
        if (dialogState.Ok() && dialogState.ref !is null) {
            if (!UiNav::CT::HasReadableText(dialogState.ref.controlTree)) {
                detail = "Unsaved dialog label resolved but is not readable through UiNav::CT::ReadText.";
                return false;
            }
            extra += " Dialog visible with text \"" + UiNav::CleanUiFormatting(UiNav::CT::ReadText(dialogState.ref.controlTree)) + "\".";
        } else {
            extra += " Unsaved dialog not open, which is fine for this fixture.";
        }

        detail = extra;
        return true;
    }

    bool _FixtureAutoManiaIconChooser(string &out detail, bool &out skipped) {
        skipped = false;
        detail = "";

        auto titleTarget = _NewCtFixtureTarget("AutoMania icon dialog title", 14, "0/0/3/1");
        auto titleState = UiNav::IsReadyEx(titleTarget);
        if (!titleState.Ok()) {
            skipped = true;
            detail = "Icon chooser dialog is not open on overlay 14; open it to validate icon-dialog discovery.";
            return true;
        }
        if (titleState.ref is null || !UiNav::CT::HasReadableText(titleState.ref.controlTree)) {
            detail = "Icon chooser title resolved but is not readable through UiNav::CT::ReadText.";
            return false;
        }

        string title = UiNav::CleanUiFormatting(UiNav::CT::ReadText(titleState.ref.controlTree));
        string titleCmp = UiNav::NormalizeForCompare(title).ToLower();
        if (titleCmp.IndexOf("icon") < 0) {
            detail = "Icon chooser title did not contain an icon-related label: \"" + title + "\".";
            return false;
        }

        auto rowTarget = _NewCtFixtureTarget("AutoMania icon chooser row", 14, "0/0/2/1/0");
        auto rowState = UiNav::IsReadyEx(rowTarget);
        if (!rowState.Ok()) {
            detail = "Icon chooser row target did not resolve: " + _FixtureOpSummary(rowState);
            return false;
        }
        if (rowState.ref is null || !UiNav::CT::CanClick(rowState.ref.controlTree)) {
            detail = "Icon chooser row resolved but is not clickable through the advanced CT surface.";
            return false;
        }

        detail = "Icon chooser title was readable and the first grid row resolved as clickable.";
        return true;
    }

    void _RunIntegrationFixturesTask() {
        g_IntegrationFixtureLines.Resize(0);
        g_IntegrationFixtureStatus = "Running integration fixtures...";
        g_IntegrationFixturesLastRunOk = false;

        int passed = 0;
        int failed = 0;
        int skipped = 0;

        try {
            bool wasSkipped = false;
            string detail = "";

            bool ok = _FixtureOwnedMlWriteRoundtrip(detail, wasSkipped);
            if (wasSkipped) {
                _PushIntegrationFixture("IF-UINAV-001", "Owned ML write roundtrip", IntegrationFixtureCategory::SelfContainedWrite, IntegrationFixtureOutcome::Skip, detail);
                skipped++;
            } else if (ok) {
                _PushIntegrationFixture("IF-UINAV-001", "Owned ML write roundtrip", IntegrationFixtureCategory::SelfContainedWrite, IntegrationFixtureOutcome::Pass, detail);
                passed++;
            } else {
                _PushIntegrationFixture("IF-UINAV-001", "Owned ML write roundtrip", IntegrationFixtureCategory::SelfContainedWrite, IntegrationFixtureOutcome::Fail, detail);
                failed++;
            }

            ok = _FixturePlayerSearchFilterFlow(detail, wasSkipped);
            if (wasSkipped) {
                _PushIntegrationFixture("IF-CONS-001", "PlayerSearch filter flow", IntegrationFixtureCategory::ConsumerFlow, IntegrationFixtureOutcome::Skip, detail);
                skipped++;
            } else if (ok) {
                _PushIntegrationFixture("IF-CONS-001", "PlayerSearch filter flow", IntegrationFixtureCategory::ConsumerFlow, IntegrationFixtureOutcome::Pass, detail);
                passed++;
            } else {
                _PushIntegrationFixture("IF-CONS-001", "PlayerSearch filter flow", IntegrationFixtureCategory::ConsumerFlow, IntegrationFixtureOutcome::Fail, detail);
                failed++;
            }

            ok = _FixtureAutoManiaCloseItemEditor(detail, wasSkipped);
            if (wasSkipped) {
                _PushIntegrationFixture("IF-CT-001", "AutoMania close item editor", IntegrationFixtureCategory::ControlTreeRead, IntegrationFixtureOutcome::Skip, detail);
                skipped++;
            } else if (ok) {
                _PushIntegrationFixture("IF-CT-001", "AutoMania close item editor", IntegrationFixtureCategory::ControlTreeRead, IntegrationFixtureOutcome::Pass, detail);
                passed++;
            } else {
                _PushIntegrationFixture("IF-CT-001", "AutoMania close item editor", IntegrationFixtureCategory::ControlTreeRead, IntegrationFixtureOutcome::Fail, detail);
                failed++;
            }

            ok = _FixtureAutoManiaIconChooser(detail, wasSkipped);
            if (wasSkipped) {
                _PushIntegrationFixture("IF-CT-002", "AutoMania icon chooser", IntegrationFixtureCategory::ControlTreeRead, IntegrationFixtureOutcome::Skip, detail);
                skipped++;
            } else if (ok) {
                _PushIntegrationFixture("IF-CT-002", "AutoMania icon chooser", IntegrationFixtureCategory::ControlTreeRead, IntegrationFixtureOutcome::Pass, detail);
                passed++;
            } else {
                _PushIntegrationFixture("IF-CT-002", "AutoMania icon chooser", IntegrationFixtureCategory::ControlTreeRead, IntegrationFixtureOutcome::Fail, detail);
                failed++;
            }
        } catch {
            _PushIntegrationFixture("IF-UINAV-ERR", "Integration fixtures runner", IntegrationFixtureCategory::ConsumerFlow, IntegrationFixtureOutcome::Fail, "Unhandled exception while executing integration fixtures.");
            failed++;
        }

        g_IntegrationFixturesRunning = false;
        g_IntegrationFixturesLastRunOk = failed == 0;
        g_IntegrationFixturesLastRunMs = Time::Now;
        g_IntegrationFixturesLastRunLabel = Time::FormatString("%Y-%m-%d %H:%M:%S");
        g_IntegrationFixtureStatus = "Integration fixtures: passed " + tostring(passed) + ", failed " + tostring(failed) + ", skipped " + tostring(skipped) + ".";
    }

    bool _FixtureCategoryHasPass(IntegrationFixtureCategory category) {
        for (uint i = 0; i < g_IntegrationFixtureLines.Length; ++i) {
            auto line = g_IntegrationFixtureLines[i];
            if (line is null || line.category != category) continue;
            if (line.outcome == IntegrationFixtureOutcome::Pass) return true;
        }
        return false;
    }

    string _ReleaseValidationCoverageLine(const string &in label, bool ok) {
        return (ok ? "\\$9fdPASS\\$z " : "\\$f66MISS\\$z ") + label;
    }

    void RunIntegrationFixtures() {
        if (g_IntegrationFixturesRunning) return;
        g_IntegrationFixturesRunning = true;
        g_IntegrationFixtureStatus = "Starting integration fixtures...";
        startnew(_RunIntegrationFixturesTask);
    }

    void RenderIntegrationFixturesUI() {
        if (UI::Button(Icons::Play + " Run integration fixtures##diag-fixtures")) {
            RunIntegrationFixtures();
        }
        UI::SameLine();
        if (g_IntegrationFixturesRunning) {
            UI::Text("\\$fd8Running...\\$z");
        } else if (g_IntegrationFixturesLastRunLabel.Length > 0) {
            UI::TextDisabled("Last run at " + g_IntegrationFixturesLastRunLabel);
        } else {
            UI::TextDisabled("Not run yet.");
        }

        UI::Text(g_IntegrationFixtureStatus);
        UI::TextDisabled("Behavior-level release validation for write-heavy, read-heavy ControlTree, and migrated consumer scenarios.");
        UI::TextDisabled("Reader fixtures intentionally skip when the required Nadeo UI state is not open.");

        bool hasWrite = _FixtureCategoryHasPass(IntegrationFixtureCategory::SelfContainedWrite);
        bool hasCtRead = _FixtureCategoryHasPass(IntegrationFixtureCategory::ControlTreeRead);
        bool hasConsumer = _FixtureCategoryHasPass(IntegrationFixtureCategory::ConsumerFlow);
        bool releaseCoverageOk = hasWrite && hasCtRead && hasConsumer;

        UI::Separator();
        UI::Text("Release Validation Coverage");
        UI::Text(_ReleaseValidationCoverageLine("Self-contained write-heavy regression", hasWrite));
        UI::Text(_ReleaseValidationCoverageLine("Read-heavy ControlTree regression", hasCtRead));
        UI::Text(_ReleaseValidationCoverageLine("Migrated real consumer flow", hasConsumer));
        UI::Text(releaseCoverageOk
            ? "\\$9fdRelease behavior coverage satisfied for this run.\\$z"
            : "\\$fd8Release behavior coverage is incomplete for this run.\\$z");

        if (g_IntegrationFixtureLines.Length == 0) return;

        if (UI::BeginTable("##diag-fixtures-table", 5, UI::TableFlags::RowBg | UI::TableFlags::BordersOuter | UI::TableFlags::BordersInnerH | UI::TableFlags::SizingStretchProp)) {
            UI::TableSetupColumn("Status", UI::TableColumnFlags::WidthFixed, 70.0f);
            UI::TableSetupColumn("Id", UI::TableColumnFlags::WidthFixed, 105.0f);
            UI::TableSetupColumn("Category", UI::TableColumnFlags::WidthFixed, 95.0f);
            UI::TableSetupColumn("Scenario", UI::TableColumnFlags::WidthFixed, 220.0f);
            UI::TableSetupColumn("Detail", UI::TableColumnFlags::WidthStretch);
            UI::TableHeadersRow();

            for (uint i = 0; i < g_IntegrationFixtureLines.Length; ++i) {
                auto line = g_IntegrationFixtureLines[i];
                if (line is null) continue;

                UI::TableNextRow();
                UI::TableNextColumn();
                UI::PushStyleColor(UI::Col::Text, _IntegrationOutcomeColor(line.outcome));
                UI::Text(_IntegrationOutcomeLabel(line.outcome));
                UI::PopStyleColor();
                UI::TableNextColumn();
                UI::Text(line.id);
                UI::TableNextColumn();
                UI::Text(_IntegrationCategoryLabel(line.category));
                UI::TableNextColumn();
                UI::Text(line.title);
                UI::TableNextColumn();
                UI::TextWrapped(line.detail);
            }

            UI::EndTable();
        }
    }

}
}

