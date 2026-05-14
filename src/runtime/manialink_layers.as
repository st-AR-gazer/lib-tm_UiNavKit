namespace UiNavKit {
    namespace Runtime {

        CTrackMania@ GetTmApp() {
            return cast<CTrackMania>(GetApp());
        }

        CGameManiaApp@ GetManiaApp() {
            auto app = GetApp();
            auto ma = cast<CGameManiaApp>(app);
            if (ma !is null) return ma;

            auto tm = cast<CTrackMania>(app);
            if (tm !is null && tm.Network !is null && tm.Network.ClientManiaAppPlayground !is null) {
                @ma = cast<CGameManiaApp>(tm.Network.ClientManiaAppPlayground);
                if (ma !is null) return ma;
            }
            return null;
        }

        CGameManiaApp@ GetManiaAppPlayground() {
            auto tm = GetTmApp();
            if (tm !is null && tm.Network !is null && tm.Network.ClientManiaAppPlayground !is null) {
                return cast<CGameManiaApp>(tm.Network.ClientManiaAppPlayground);
            }
            return null;
        }

        CGameManiaApp@ GetManiaAppMenu() {
            auto tm = GetTmApp();
            if (tm !is null && tm.MenuManager !is null && tm.MenuManager.MenuCustom_CurrentManiaApp !is null) {
                auto menuMa = cast<CGameManiaApp>(tm.MenuManager.MenuCustom_CurrentManiaApp);
                if (menuMa !is null) return menuMa;
            }

            auto app = GetApp();
            auto ma = cast<CGameManiaApp>(app);
            if (ma !is null) return ma;
            return null;
        }

        string ExtractManialinkName(const string &in pageRaw) {
            if (pageRaw.Length == 0) return "";
            string page = pageRaw;
            if (page.Length > 8192) page = page.SubStr(0, 8192);

            string lower = page.ToLower();
            int mlIx = lower.IndexOf("<manialink");
            if (mlIx < 0) return "";

            string tail = page.SubStr(mlIx);
            int headEndRel = tail.IndexOf(">");
            if (headEndRel < 0) return "";

            string head = tail.SubStr(0, headEndRel);
            string headLower = head.ToLower();
            int nameIx = headLower.IndexOf("name=");
            if (nameIx < 0) return "";

            int pos = nameIx + 5;
            int headLen = int(head.Length);
            while (pos < headLen) {
                string ch = head.SubStr(pos, 1);
                if (ch == " " || ch == "\t" || ch == "\r" || ch == "\n") {
                    pos++;
                    continue;
                }
                break;
            }
            if (pos >= headLen) return "";

            string quote = head.SubStr(pos, 1);
            if (quote != "\"" && quote != "'") return "";

            int valStart = pos + 1;
            int valEndRel = head.SubStr(valStart).IndexOf(quote);
            if (valEndRel < 0) return "";
            return head.SubStr(valStart, valEndRel);
        }

        UiNav::ManiaLinkSource _SourceFromApp(CGameManiaApp@ app) {
            auto menu = GetManiaAppMenu();
            if (menu !is null && app is menu) return UiNav::ManiaLinkSource::Menu;
            auto pg = GetManiaAppPlayground();
            if (pg !is null && app is pg) return UiNav::ManiaLinkSource::Playground;
            return UiNav::ManiaLinkSource::CurrentApp;
        }

        CGameUILayer@ Ensure(
            const string &in key,
            const string &in page,
            bool visible = true,
            bool persistAcrossReloads = false
        ) {
            return UiNav::ML::Layers::EnsureOwned(
                key,
                page,
                UiNav::ManiaLinkSource::CurrentApp,
                visible,
                persistAcrossReloads
            );
        }

        CGameUILayer@ EnsureAtApp(
            const string &in key,
            const string &in page,
            CGameManiaApp@ app,
            bool visible = true,
            bool persistAcrossReloads = false
        ) {
            if (app is null) return Ensure(key, page, visible, persistAcrossReloads);
            return UiNav::ML::Layers::EnsureOwned(key, page, _SourceFromApp(app), visible, persistAcrossReloads);
        }

        bool Destroy(const string &in key) {
            return UiNav::ML::Layers::DestroyOwned(key);
        }

        void DestroyAllOwnedGlobal() {
            UiNav::ML::Layers::DestroyAllOwned();
        }

        uint LastDestroyAllOwnedSweepCount() {
            return UiNav::ML::Layers::LastDestroyAllOwnedSweepCount();
        }

    }
}
