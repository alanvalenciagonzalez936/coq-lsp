open Fleche

let is_in_dir ~dir ~file = CString.is_prefix dir file

let workspace_of_uri ~io ~uri ~workspaces ~default =
  let file = Lang.LUri.File.to_string_file uri in
  match List.find_opt (fun (dir, _) -> is_in_dir ~dir ~file) workspaces with
  | None ->
    let lvl = Io.Level.error in
    let message = "file not in workspace: " ^ file in
    Io.Report.message ~io ~lvl ~message;
    default
  | Some (_, Error err) ->
    let lvl = Io.Level.error in
    let message = "invalid workspace for: " ^ file ^ " " ^ err in
    Io.Report.message ~io ~lvl ~message;
    default
  | Some (_, Ok workspace) -> workspace

(** Move to a plugin *)
let save_diags_file ~(doc : Fleche.Doc.t) =
  let file = Lang.LUri.File.to_string_file doc.uri in
  let file = Filename.remove_extension file ^ ".diags" in
  let diags = Fleche.Doc.diags doc in
  Util.format_to_file ~file ~f:Output.pp_diags diags

(** Return: exit status for file:

    - 1: fatal error in checking (usually due to [max_errors=n]
    - 2: checking stopped
    - 102: file not scheduled
    - 222: Incorrect URI *)
let status_of_doc (doc : Doc.t) =
  match doc.completed with
  | Yes _ -> 0
  | Stopped _ -> 2
  | Failed _ | FailedPermanent _ -> 1

let compile_file ~cc file : int =
  let { Cc.io; root_state; workspaces; default; token } = cc in
  let lvl = Io.Level.info in
  let message = Format.asprintf "compiling file %s" file in
  Io.Report.message ~io ~lvl ~message;
  match Lang.LUri.(File.of_uri (of_string file)) with
  | Error _ -> 222
  | Ok uri -> (
    let workspace = workspace_of_uri ~io ~workspaces ~uri ~default in
    let files = Coq.Files.make () in
    let env = Doc.Env.make ~init:root_state ~workspace ~files in
    let raw = Util.input_all file in
    let () = Theory.create ~io ~token ~env ~uri ~raw ~version:1 in
    match Theory.Check.maybe_check ~io ~token with
    | None -> 102
    | Some (_, doc) ->
      save_diags_file ~doc;
      (* Vo file saving is now done by a plugin *)
      Theory.close ~uri;
      status_of_doc doc)

let compile ~cc =
  List.fold_left
    (fun status file -> if status = 0 then compile_file ~cc file else status)
    0
