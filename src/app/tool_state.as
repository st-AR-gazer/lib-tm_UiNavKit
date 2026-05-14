namespace UiNavKit {

    enum Mode {
        ML = 0,
        ControlTree = 1
    }

    class MlStyleCaptureEntry {
        string name;
        string type;
        string controlId;
        string selector;
        string selectorIdChain;
        string selectorMixedChain;
        string indexPath;
        string uiPath;
        int layerIx = -1;
        int appKind = 0;
        string snapshotJson;
    }

    class MlLayerFavorite {
        int appKind = 0;
        string layerId;
        int layerIx = -1;
        string label;
    }

    class MlValueLock {
        string id;
        bool enabled = true;
        int appKind = 0;
        int layerIx = -1;
        string path;
        int valueKind = 0;  // 1 = label, 2 = entry
        string lockedValue;
        string label;
    }

    class MlBrowserEntry {
        string url;
        string source;
        string kind;
    }

    class MlFlatRow {
        bool isLayer = false;
        int depth = 0;
        int layerIx = -1;
        string path;
        string uiPath;
        string label;
        bool hasChildren = false;
        bool visible = true;
        string tag;
    }

    class ControlTreeFlatRow {
        int depth = 0;
        int rootIx = -1;
        string relPath;
        string displayPath;
        string uiPath;
        string label;
        bool hasChildren = false;
        bool visible = true;
    }

    class ControlTreeOverlayRootsCacheEntry {
        uint epoch = 0;
        uint mobilsLen = 0;
        uint scanIx = 0;
        bool complete = false;
        array<int> rootIxs;
        uint hiddenNoiseRoots = 0;
        uint hiddenDuplicateRoots = 0;
        dictionary anonRootSignatures;
    }

    Mode g_Mode = Mode::ML;

    string g_MlSearch = "";
    bool g_MlPickMode = false;
    bool g_MlPickNextClick = false;
    int g_MlViewLayerIndex = -1;
    int g_MlTreeHeight = 600;
    int g_MlTreeWidth = 420;
    bool g_MlCollapseAll = false;
    bool g_MlNodeFocusActive = false;
    int g_MlNodeFocusAppKind = 0;
    int g_MlNodeFocusLayerIx = -1;
    string g_MlNodeFocusPath = "";
    string g_MlNodeFocusUiPath = "";
    string g_MlNodeFocusStatus = "";
    bool g_MlSplitterDragging = false;
    float g_MlSplitterLastX = 0.0f;
    CGameManialinkControl@ g_SelectedMlNode = null;
    string g_SelectedMlUiPath = "";
    string g_SelectedMlPath = "";
    int g_SelectedMlLayerIx = -1;
    int g_MlActiveAppKind = 0;  // 0 = playground, 1 = menu
    int g_SelectedMlAppKind = 0;
    uint g_MlTreeOpenEpoch = 0;
    uint g_MlSearchCacheEpoch = 0;
    uint g_MlSubtreeCacheLastClearMs = 0;
    uint g_MlInspectableCacheEpoch = 0;
    uint g_MlInspectableCacheStampMs = 0;
    bool g_MlInspectableCacheValid = false;
    bool g_MlInspectablePlayground = false;
    bool g_MlInspectableMenu = false;
    bool g_MlInspectableEditor = false;
    array<MlLayerFavorite@> g_MlLayerFavorites;
    bool g_MlLayerFavoritesLoaded = false;
    string g_MlLayerFavoritesStatus = "";
    array<MlValueLock@> g_MlValueLocks;
    bool g_MlValueLocksLoaded = false;
    string g_MlValueLocksStatus = "";
    string g_MlValueLockDraft = "";
    string g_MlValueLockDraftKey = "";
    array<MlBrowserEntry@> g_MlBrowserEntries;
    string g_MlBrowserSelectedUrl = "";
    string g_MlBrowserSearch = "";
    string g_MlBrowserStatus = "";
    uint g_MlBrowserLastRefreshMs = 0;
    bool g_MlBrowserSplitterDragging = false;
    float g_MlBrowserSplitterLastX = 0.0f;
    dictionary g_MlBrowserResolvedPathCache;
    UI::Texture@ g_MlBrowserPreviewTexture = null;
    string g_MlBrowserPreviewTextureUrl = "";
    string g_MlBrowserPreviewError = "";
    bool g_MlBrowserLoadPreviewRequested = false;
    array<string> g_MlBrowserFavorites;
    bool g_MlBrowserFavoritesLoaded = false;
    array<MlFlatRow@> g_MlFlatRows;
    bool g_MlFlatDirty = true;
    string g_MlFlatFilterKey = "";
    int g_MlFlatViewLayer = -9999;
    int g_MlFlatAppKind = -1;
    uint g_MlFlatEpoch = 0;
    uint g_MlFlatLastBuildMs = 0;
    bool g_MlFlatRowsTruncated = false;

    string g_ControlTreeSearch = "";
    bool g_ControlTreePickMode = false;
    bool g_ControlTreePickNextClick = false;
    int g_ControlTreeOverlay = -1;
    int g_ControlTreeTreeHeight = 600;
    int g_ControlTreeTreeWidth = 420;
    bool g_ControlTreeCollapseAll = false;
    bool g_ControlTreeNodeFocusActive = false;
    uint g_ControlTreeNodeFocusOverlay = 16;
    int g_ControlTreeNodeFocusRootIx = -1;
    string g_ControlTreeNodeFocusPath = "";
    string g_ControlTreeNodeFocusUiPath = "";
    bool g_ControlTreeSplitterDragging = false;
    float g_ControlTreeSplitterLastX = 0.0f;
    CControlBase@ g_SelectedControlTreeNode = null;
    string g_SelectedControlTreeUiPath = "";
    int g_SelectedControlTreeRootIx = -1;
    uint g_SelectedControlTreeOverlayAtSel = 16;
    string g_SelectedControlTreePath = "";
    string g_SelectedControlTreeDisplayPath = "";
    uint g_ControlTreeSearchCacheEpoch = 0;
    uint g_ControlTreeSubtreeCacheLastClearMs = 0;
    array<ControlTreeFlatRow@> g_ControlTreeFlatRows;
    bool g_ControlTreeFlatDirty = true;
    string g_ControlTreeFlatFilterKey = "";
    uint g_ControlTreeFlatOverlay = 0;
    string g_ControlTreeFlatStartPath = "";
    uint g_ControlTreeFlatEpoch = 0;
    uint g_ControlTreeFlatLastBuildMs = 0;
    bool g_ControlTreeFlatRowsTruncated = false;

    string g_MlSnippetKey = "";
    string g_MlSnippetEdit = "";
    string g_ControlTreeSnippetKey = "";
    string g_ControlTreeSnippetEdit = "";

    dictionary g_ControlTreeOverlayRootsCache;

    [Setting hidden name="UiNav debug ML tree width"]
    int S_MlTreeWidth = 420;

    [Setting hidden name="UiNav debug ControlTree tree width"]
    int S_ControlTreeTreeWidth = 420;

    [Setting hidden name="UiNav debug search cache refresh ms"]
    uint S_DebugSearchCacheRefreshMs = 800;

    [Setting hidden name="UiNav debug ML search global"]
    bool S_MlSearchGlobal = false;

    [Setting hidden name="UiNav debug tree node cache ttl ms"]
    uint S_DebugTreeNodeCacheTtlMs = 0;

    [Setting hidden name="UiNav debug tree inline text"]
    bool S_DebugTreeInlineText = false;

    [Setting hidden name="UiNav debug tree row budget (0 = unlimited)"]
    int S_DebugTreeRowBudget = 800;

    [Setting hidden name="UiNav debug ControlTree hide empty roots"]
    bool S_ControlTreeHideEmptyRoots = true;

    [Setting hidden name="UiNav debug ControlTree hide duplicate anonymous roots"]
    bool S_ControlTreeHideDuplicateAnonymousRoots = true;

    [Setting hidden name="UiNav debug ControlTree overlay root scan budget"]
    uint S_ControlTreeOverlayRootScanBudget = 2048;

    bool g_WidthsInit = false;

    int g_MlRowsRendered = 0;
    bool g_MlRowsTruncated = false;
    int g_ControlTreeRowsRendered = 0;
    bool g_ControlTreeRowsTruncated = false;

    [Setting hidden name="UiNav debug notes file path"]
    string S_MlNotesPath = IO::FromStorageFolder("UiNavMlNotes.cfg");

    [Setting hidden name="UiNav debug favorite layers"]
    string S_MlFavoriteLayers = "";

    [Setting hidden name="UiNav debug ML value locks"]
    string S_MlValueLocks = "";

    [Setting hidden name="UiNav debug ML browser include live layers"]
    bool S_MlBrowserIncludeLiveLayers = true;

    [Setting hidden name="UiNav debug ML browser include filesystem"]
    bool S_MlBrowserIncludeFilesystem = true;

    [Setting hidden name="UiNav debug ML browser include Nadeo Fids tree"]
    bool S_MlBrowserIncludeNadeoFidsTree = true;

    [Setting hidden name="UiNav debug ML browser assets root"]
    string S_MlBrowserAssetsRoot = "";

    [Setting hidden name="UiNav debug ML browser recursive"]
    bool S_MlBrowserRecursive = true;

    [Setting hidden name="UiNav debug ML browser max files"]
    int S_MlBrowserMaxFiles = 6000;

    [Setting hidden name="UiNav debug ML browser max Nadeo Fids files"]
    int S_MlBrowserMaxNadeoFidsFiles = 50000;

    [Setting hidden name="UiNav debug ML browser verbose logs"]
    bool S_MlBrowserVerboseLogs = true;

    [Setting hidden name="UiNav debug ML browser use Fids resolution"]
    bool S_MlBrowserUseFidsResolution = false;

    [Setting hidden name="UiNav debug ML browser allow Fids extraction"]
    bool S_MlBrowserAllowFidExtract = true;

    [Setting hidden name="UiNav debug ML browser use DDS decoder fallback"]
    bool S_MlBrowserUseDdsDecoder = true;

    [Setting hidden name="UiNav debug ML browser auto preview on select"]
    bool S_MlBrowserAutoPreview = false;

    [Setting hidden name="UiNav debug ML browser list width"]
    int S_MlBrowserListWidth = 420;

    [Setting hidden name="UiNav debug ML browser favorites"]
    string S_MlBrowserFavorites = "";

    [Setting hidden name="UiNav debug snapshot file path"]
    string S_MlSnapshotPath = IO::FromStorageFolder("Exports/ManiaLinks/uinav_ml_snapshot.json");

    [Setting hidden name="UiNav debug snapshot include children"]
    bool S_MlSnapshotIncludeChildren = true;

    [Setting hidden name="UiNav debug snapshot max depth"]
    int S_MlSnapshotMaxDepth = 2;

    [Setting hidden name="UiNav debug snapshot apply include children"]
    bool S_MlSnapshotApplyChildren = false;

    string g_MlSnapshotApplySelector = "";
    string g_MlSnapshotStatus = "";

    [Setting hidden name="UiNav debug style pack file path"]
    string S_MlStylePackPath = IO::FromStorageFolder("Exports/ManiaLinks/uinav_ml_style_pack.json");

    [Setting hidden name="UiNav debug style pack include children"]
    bool S_MlStylePackIncludeChildren = false;

    [Setting hidden name="UiNav debug style pack max depth"]
    int S_MlStylePackMaxDepth = 1;

    [Setting hidden name="UiNav debug style pack include text values"]
    bool S_MlStylePackIncludeTextValues = false;

    [Setting hidden name="UiNav debug style pack apply children"]
    bool S_MlStylePackApplyChildren = false;

    array<MlStyleCaptureEntry@> g_MlStylePackEntries;
    string g_MlStylePackStatus = "";

    [Setting hidden name="ML dump file path"]
    string S_MlDumpPath = IO::FromStorageFolder("Exports/Dumps/uinav_ml_dump.txt");

    [Setting hidden name="ML dump depth"]
    int S_MlDumpDepth = 8;

    [Setting hidden name="ML dump layer index (-1 = all)"]
    int S_MlDumpLayerIndex = -1;

    [Setting hidden name="ML dump selector chains"]
    string S_MlDumpSelectorChains = "";

    [Setting hidden name="ML dump selector children only"]
    bool S_MlDumpSelectorChildrenOnly = true;

    [Setting hidden name="ML dump only open paths"]
    bool S_MlDumpOnlyOpenPaths = false;

    [Setting hidden name="ControlTree dump file path"]
    string S_ControlTreeDumpPath = IO::FromStorageFolder("Exports/Dumps/uinav_control_tree_dump.txt");

    [Setting hidden name="ControlTree dump overlay"]
    uint S_ControlTreeDumpOverlay = 16;

    [Setting hidden name="ControlTree dump depth"]
    int S_ControlTreeDumpDepth = 6;

    [Setting hidden name="ControlTree dump start path"]
    string S_ControlTreeDumpStartPath = "";

    string g_LastMlDumpStatus = "";
    string g_LastMlDumpPath = "";
    uint g_LastMlDumpLines = 0;

    string g_LastMlPageDumpStatus = "";
    string g_LastMlPageDumpPath = "";
    uint g_LastMlPageDumpChars = 0;

    string g_LastControlTreeDumpStatus = "";
    string g_LastControlTreeDumpPath = "";
    uint g_LastControlTreeDumpLines = 0;

    string g_UiNavOwnedLayerCleanupStatus = "";
}
