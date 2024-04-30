(************************************************************************)
(*         *   The Coq Proof Assistant / The Coq Development Team       *)
(*  v      *   INRIA, CNRS and contributors - Copyright 1999-2018       *)
(* <O___,, *       (see CREDITS file for the list of authors)           *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

(************************************************************************)
(* Coq Language Server Protocol                                         *)
(* Copyright 2019 MINES ParisTech -- Dual License LGPL 2.1 / GPL3+      *)
(* Copyright 2019-2022 Inria      -- Dual License LGPL 2.1 / GPL3+      *)
(* Written by: Emilio J. Gallego Arias                                  *)
(************************************************************************)

let coq_interp ~st cmd =
  let st = State.to_coq st in
  let cmd = Ast.to_coq cmd in
  Vernacinterp.interp ~st cmd |> State.of_coq

let interp ~token ~st cmd = Protect.eval ~token cmd ~f:(coq_interp ~st)

module Require = struct
  (* We could improve this Coq upstream by making the API a bit more
     orthogonal *)
  let interp ~st _files
      { Ast.Require.from; export; mods; loc = _; attrs; control } =
    let () = Vernacstate.unfreeze_interp_state (State.to_coq st) in
    let fn () = Vernacentries.vernac_require from export mods in
    (* Check generic attributes *)
    let fn () =
      Attributes.unsupported_attributes attrs;
      fn ()
    in
    (* Execute control commands *)
    let () = Utils.with_control ~fn ~control ~st in
    Vernacstate.freeze_interp_state ~marshallable:false |> State.of_coq

  let interp ~token ~st files cmd =
    Protect.eval ~token ~f:(interp ~st files) cmd
end
