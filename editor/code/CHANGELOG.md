# coq-lsp 0.1.8: Trick-or-treat
-------------------------------

 - Update VSCode client dependencies, should bring some performance
   improvements to goal pretty printing (@ejgallego, #530)
 - Update goal display colors for light mode so they are actually
   readable now. (@bhaktishh, #539, fixes #532)
 - Added link to Python coq-lsp client by Pedro Carrot and Nuno
   Saavedra (@Nfsaavedra, #536)
 - Properly concatenate warnings from _CoqProject (@ejgallego,
   reported by @mituharu, #541, fixes #540)
 - Fix broken `coq/saveVo` and `coq/getDocument` requests due to a
   parsing problem with extra fields in their requests (@ejgallego,
   #547, reported by @Zimmi48)
 - `fcc` now understands the `--coqlib`, `--coqcorelib`,
   `--ocamlpath`, `-Q` and `-R` arguments (@ejgallego, #555)
 - Describe findlib status in `Workspace.describe`, which is printed
   in the output windows (@ejgallego, #556)
 - `coq-lsp` plugin loader will now be strict in case of a plugin
   failure, the previous loose behavior was more convenient for the
   early releases, but it doesn't make sense now and made things
   pretty hard to debug on the Windows installer (@ejgallego, #557)
 - Add pointers to Windows installers (@ejgallego, #559)
 - Recognize `Goal` and `Definition $id : ... .` as proof starters
   (@ejgallego, #561, reported by @Zimmi48, fixes #548)
 - Provide basic notation information on hover. This is intended for
   people to build their own more refined notation feedback systems
   (@ejgallego, #562)
 - Hover request can now be extended by plugins (@ejgallego, #562)
 - Updated LSP and JS client libs, notably to vscode-languageclient 9
   (@ejgallego, #565)
 - Implement a LIFO document scheduler, this is heavier in the
   background as more documents will be checked, but provides a few
   usability improvements (@ejgallego, #566, fixes #563, reported by
   Ali Caglayan)
 - New lexical qed detection error recovery rule; this makes a very
   large usability difference in practice when editing inside proofs.
   (@ejgallego, #567, fixes #33)
 - `coq-lsp` is now supported by the `coq-nix-toolbox` (@Zimmi48,
   @CohenCyril, #572, via
   https://github.com/coq-community/coq-nix-toolbox/pull/164 )
 - Support for `-rifrom` in `_CoqProject` and in command line
   (`--rifrom`). Thanks to Lasse Blaauwbroek for the report.
   (@ejgallego, #581, fixes #579)
 - Export Query Goals API in VSCode client; this way other extensions
   can implement their own commands that query Coq goals (@amblafont,
   @ejgallego, #576, closes #558)
 - New `pretac` field for preprocessing of goals with a tactic using
   speculative execution, this is experimental for now (@amblafont,
   @ejgallego, #573, helps with #558)
 - Implement `textDocument/selectionRange` request, that will return
   the range of the Coq sentence underlying the cursor. In VSCode,
   this is triggered by the "Expand Selection" command. The
   implementation is partial: we only take into account the first
   position, and we only return a single range (Coq sentence) without
   parents. (@ejgallego, #582)
 - Be more robust to mixed-separator windows paths in workspace
   detection (@ejgallego, #583, fixes #569)
 - Adjust printing breaks in error and message panels (@ejgallego,
   @Alizter, #586, fixes #457 , fixes #458 , fixes #571)

# coq-lsp 0.1.7: Just-in-time
-----------------------------

- Enable web extension support (worker server will happen in next release)
- Improvements and clenaups on hover display, in particular we don't
  print repeated `Notation` strings.
- Fix bug that prevented "Goal after tactic" from working properly.
- Fix "Error message browser becomes non-visible when there are many
  goals" by using a fixed-position separated error display.
- Display the list of pending obligations in info panel.
- Preliminary panel to display document performance data.
- Fix keybinding for the "Show Goals at Point" command
- Hook coq-lsp to ViZX extension
- Warnings settings from `_CoqProject` files are now applied
- Limit the number of messages displayed in the goal window to 101,
  as to workaround slow render of Coq's pretty printing format. This
  is an issue for example in Search where we can get thousand of
  results. We also speed up the rendering a bit by not hashing twice,
  and fix a parameter-passing bug in the React setup.

# coq-lsp 0.1.6: Peek
----------------------

- The information / goal view now uses a new layout-aware printer; the
  if you find any problem the old printer can be enabled in the
  extension options.
- Completion tweaks, for example now ' will trigger end of completion.
- When activating the extension, coq-lsp add to workspace
  configuration an auto-ignore for Coq object files such as .vo, .aux,
  etc...
- Multiple workspace support, use "Add folder to workspace" to handle
  projects with multiple `_CoqProject` files.
- New VS Code commands: start / stop server, save .vo file,
  get serialized version of document.
- `vscode-languageclient` updated to 8.1.0
- New status bar button to toggle server run status
- Scroll active goal into view automatically
- Info on memory and time is now disabled by default, use option
  `coq-lsp.stats_on_hover_option` to re-enable it
- Server greatly improved, see server changelog for more information.

# coq-lsp 0.1.5: Form
----------------------

 - General bugfix and quality-of-life release.
 - Markdown Coq code blocks now must specify "coq" as a language
 - Improved syntax highlighting of Coq markdown files
 - Info panel has been greatly improved
 - Bugfix on message display after the port to React
 - Hover will display type of identifier at point
 - Jump to definition support
 - Goal display handles background goals better, showing preview,
   goals stack, and focusing information
 - The goal display now numbers goals starting with 1 instead of 0
 - Hypotheses with bodies are now correctly displayed
 - Support unicode characters in filenames
 - Stop checking documents after a maximum number of errors (user configurable)
 - Goal view now supports find
 - Display Coq warnings, info and debug messages in info panel
 - Improved outline view, with more details and types
 - Server greatly improved with better error heuristics, see server
   changelog for more information

# coq-lsp 0.1.4: View
----------------------

- The keybinding alt+enter in VSCode is now correctly scoped to be
  only active on Coq files.
- Display an error message when the VSCoq extension is detected to be
  active, as `coq-lsp` and VSCoq don't work well together.
- Display an error message when the client and server versions don't
  match.
- [server-side] Support Unicode files
- [server-side] Unicode completion on `\`, configurable in settings.
- New infoview panel based on React.
- New option in settings to enable Coq Debug mode (and backtraces)
- Fixes a bug that made some `CoqProject` files not to be properly
  detected.

# coq-lsp 0.1.3: Event
----------------------

- Requires coq-lsp server 0.1.3, see full changelog at
  https://github.com/ejgallego/coq-lsp/releases/tag/0.1.3
- Default "show goals" setting is now on cursor movement, thanks to
  upgrade server request serving this is no viable.
- VsCodeVim should work with coq-lsp goal following now (be sure to
  pick the "Command" option in settings)

# coq-lsp 0.1.2: Message
------------------------

- Requires coq-lsp server 0.1.2, see full changelog at
  https://github.com/ejgallego/coq-lsp/releases/tag/0.1.2
- Extension will now enforce that server has the correct version
- The Coq LSP server output window will now show trace information
- Coq Info Panel will now show messages coming from commands such as
  `About` or `Search`
- Coq Info Panel will now show detailed error information.

# coq-lsp 0.1.1: Location
-------------------------

- Requires coq-lsp server 0.1.1, see full changelog at
  https://github.com/ejgallego/coq-lsp/releases/tag/0.1.1%2Bv8.16
- Server greatly improved in terms of responsiveness
- Improved goal panel and interaction mode
- Many new configuration options
- Code will now show a "Coq LSP Server" output window

# coq-lsp 0.1.0: Memory
-----------------------

- First public release: minimal LSP client, with support for a goal panel
