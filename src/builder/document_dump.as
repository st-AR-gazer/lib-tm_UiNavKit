namespace UiNavKit {
    namespace Builder {

        string _DbgIndent(int depth) {
            if (depth <= 0) return "";
            string outS = "";
            for (int i = 0; i < depth; ++i) outS += "  ";
            return outS;
        }

        string _DbgTrunc(const string &in s, int maxLen = 240) {
            if (maxLen < 8) maxLen = 8;
            if (s.Length <= maxLen) return s;
            return s.SubStr(0, maxLen - 3) + "...";
        }

        void _DbgAppend(array<string> &inout lines, const string &in s) {
            lines.InsertLast(s);
        }

        string DumpBuilderDocumentToText(const UiNav::Builder::BuilderDocument@ doc, bool includeExportXml = true) {
            array<string> lines;
            _DbgAppend(lines, "=== UiNav Builder Debug Dump ===");
            _DbgAppend(lines, "t_ms=" + Time::Now);

            if (doc is null) {
                _DbgAppend(lines, "<null doc>");
                string outS = "";
                for (uint i = 0; i < lines.Length; ++i) outS += (i == 0 ? "" : "\n") + lines[i];
                return outS;
            }

            int roots = 0;
            for (uint i = 0; i < doc.nodes.Length; ++i) if (doc.nodes[i] !is null && doc.nodes[i].parentIx < 0) roots++;

            _DbgAppend(lines, "doc.format=" + doc.format);
            _DbgAppend(lines, "doc.schemaVersion=" + doc.schemaVersion);
            _DbgAppend(lines, "doc.name=" + doc.name);
            _DbgAppend(lines, "doc.sourceKind=" + doc.sourceKind);
            _DbgAppend(lines, "doc.sourceLabel=" + doc.sourceLabel);
            _DbgAppend(lines, "doc.nodes=" + doc.nodes.Length + " roots=" + roots);
            _DbgAppend(lines, "doc.diagnostics=" + doc.diagnostics.Length);
            _DbgAppend(lines, "selectedNodeIx=" + g_SelectedNodeIx);
            _DbgAppend(lines, "baselineXmlLen=" + g_BaselineXml.Length);

            _DbgAppend(lines, "");
            _DbgAppend(lines, "Last preview:");
            _DbgAppend(lines, "  atMs=" + g_LastPreviewAtMs);
            _DbgAppend(lines, "  key=" + g_LastPreviewLayerKey);
            _DbgAppend(lines, "  app=" + g_LastPreviewAppLabel + " layerIx=" + g_LastPreviewLayerIx);
            _DbgAppend(lines, "  xmlLen=" + g_LastPreviewXmlLen);
            _DbgAppend(lines, "  boundsHas=" + (g_LastPreviewBoundsHas ? "1" : "0"));
            if (g_LastPreviewBoundsHas) {
                _DbgAppend(lines, "  boundsMin=" + _FmtVec2(g_LastPreviewBoundsMin));
                _DbgAppend(lines, "  boundsMax=" + _FmtVec2(g_LastPreviewBoundsMax));
            }

            if (g_LastPreviewDiagText.Length > 0) {
                _DbgAppend(lines, "");
                _DbgAppend(lines, "Last preview diag text:");
                auto diagLines = g_LastPreviewDiagText.Split("\n");
                for (uint i = 0; i < diagLines.Length; ++i) {
                    _DbgAppend(lines, "  " + diagLines[i]);
                }
            }

            if (doc.diagnostics.Length > 0) {
                _DbgAppend(lines, "");
                _DbgAppend(lines, "Document diagnostics:");
                for (uint i = 0; i < doc.diagnostics.Length; ++i) {
                    auto d = doc.diagnostics[i];
                    if (d is null) continue;
                    _DbgAppend(
                        lines,
                        "  [" + d.severity + "] " + d.code + (d.nodeUid.Length > 0 ? (" node=" + d.nodeUid) : "")
                    );
                    _DbgAppend(lines, "    " + d.message);
                }
            }

            _DbgAppend(lines, "");
            _DbgAppend(lines, "Nodes:");
            for (uint i = 0; i < doc.nodes.Length; ++i) {
                auto n = doc.nodes[i];
                if (n is null) continue;
                string hdr = "[" + i + "] uid=" + n.uid
                    + " kind=" + n.kind
                    + " tag=" + n.tagName
                    + " id=" + (n.controlId.Length > 0 ? n.controlId : "<none>")
                    + " parent=" + n.parentIx
                    + " children=" + n.childIx.Length
                    + " fidelity=" + n.fidelity.level;
                _DbgAppend(lines, hdr);

                if (n.classes.Length > 0) {
                    string cls = "";
                    for (uint c = 0; c < n.classes.Length; ++c) cls += (c == 0 ? "" : " ") + n.classes[c];
                    _DbgAppend(lines, "  classes=" + cls);
                }
                if (n.scriptEvents) _DbgAppend(lines, "  scriptevents=1");

                if (n.typed is null) {
                    _DbgAppend(lines, "  typed=<null>");
                } else {
                    _DbgAppend(
                        lines,
                        "  typed.pos=" + _FmtVec2(n.typed.pos) + " size=" + _FmtVec2(n.typed.size) + " z=" + n.typed.z + " scale=" + n.typed.scale + " rot=" + n.typed.rot + " visible=" + (n.typed.visible ? "1" : "0") + " halign=" + n.typed.hAlign + " valign=" + n.typed.vAlign
                    );

                    if (n.kind == "frame") {
                        _DbgAppend(
                            lines,
                            "  frame.clipActive=" + (n.typed.clipActive ? "1" : "0") + " clipPos=" + _FmtVec2(n.typed.clipPos) + " clipSize=" + _FmtVec2(n.typed.clipSize)
                        );
                    } else if (n.kind == "quad") {
                        _DbgAppend(
                            lines,
                            "  quad.opacity=" + n.typed.opacity + " bgcolor=" + n.typed.bgColor + " style=" + n.typed.style + " substyle=" + n.typed.subStyle
                        );
                        if (n.typed.image.Length > 0) _DbgAppend(lines, "  quad.image=" + _DbgTrunc(n.typed.image));
                        if (n.typed.imageFocus.Length > 0) _DbgAppend(
                            lines,
                            "  quad.imageFocus=" + _DbgTrunc(n.typed.imageFocus)
                        );
                    } else if (n.kind == "label") {
                        _DbgAppend(
                            lines,
                            "  label.opacity=" + n.typed.opacity + " textSize=" + n.typed.textSize + " textColor=" + n.typed.textColor + " style=" + n.typed.style + " substyle=" + n.typed.subStyle
                        );
                        if (n.typed.text.Length > 0) _DbgAppend(lines, "  label.text=" + n.typed.text);
                        if (n.typed.textPrefix.Length > 0) _DbgAppend(
                            lines,
                            "  label.textPrefix=" + n.typed.textPrefix
                        );
                    } else if (n.kind == "entry" || n.kind == "textedit") {
                        _DbgAppend(
                            lines,
                            "  input.opacity=" + n.typed.opacity + " textSize=" + n.typed.textSize + " textColor=" + n.typed.textColor + " maxLen=" + n.typed.maxLength + " maxLine=" + n.typed.maxLine
                        );
                        if (n.typed.value.Length > 0) _DbgAppend(lines, "  input.value=" + n.typed.value);
                    }
                }

                array<string> rawKeys = n.rawAttrs.GetKeys();
                if (rawKeys.Length > 0) {
                    rawKeys.SortAsc();
                    _DbgAppend(lines, "  rawAttrs=" + rawKeys.Length);
                    for (uint r = 0; r < rawKeys.Length; ++r) {
                        string v = "";
                        n.rawAttrs.Get(rawKeys[r], v);
                        _DbgAppend(lines, "    " + rawKeys[r] + "=\"" + v + "\"");
                    }
                }

                if (n.fidelity.reasons.Length > 0) {
                    string rs = "";
                    for (uint r = 0; r < n.fidelity.reasons.Length; ++r) rs += (r == 0 ? "" : ", ") + n.fidelity.reasons[r];
                    _DbgAppend(lines, "  fidelity.reasons=" + rs);
                }
            }

            if (doc.stylesheetBlock !is null && doc.stylesheetBlock.raw.Length > 0) {
                _DbgAppend(lines, "");
                _DbgAppend(lines, "Stylesheet block (" + doc.stylesheetBlock.raw.Length + " chars):");
                auto sheetLines = doc.stylesheetBlock.raw.Split("\n");
                for (uint i = 0; i < sheetLines.Length; ++i) _DbgAppend(lines, "  " + sheetLines[i]);
            }

            if (doc.scriptBlock !is null && doc.scriptBlock.raw.Length > 0) {
                _DbgAppend(lines, "");
                _DbgAppend(lines, "Script block (" + doc.scriptBlock.raw.Length + " chars):");
                auto scriptLines = doc.scriptBlock.raw.Split("\n");
                for (uint i = 0; i < scriptLines.Length; ++i) _DbgAppend(lines, "  " + scriptLines[i]);
            }

            if (includeExportXml) {
                string xml = ExportToXml(doc);
                _DbgAppend(lines, "");
                _DbgAppend(lines, "Export XML (" + xml.Length + " chars):");
                _DbgAppend(lines, xml);
            }

            string outS = "";
            for (uint i = 0; i < lines.Length; ++i) outS += (i == 0 ? "" : "\n") + lines[i];
            return outS;
        }

        bool CopyBuilderDumpToClipboard(bool includeExportXml = true) {
            _EnsureDoc();
            string dump = DumpBuilderDocumentToText(g_Doc, includeExportXml);
            IO::SetClipboard(dump);
            g_Status = "Copied Builder dump to clipboard (" + dump.Length + " chars).";
            return true;
        }

    }
}
