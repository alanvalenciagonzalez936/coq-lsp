(************************************************************************)
(* Flèche => document manager: Document                                 *)
(* Copyright 2019 MINES ParisTech -- Dual License LGPL 2.1 / GPL3+      *)
(* Copyright 2019-2024 Inria      -- Dual License LGPL 2.1 / GPL3+      *)
(* Written by: Emilio J. Gallego Arias & coq-lsp contributors           *)
(************************************************************************)

module Node : sig
  module Ast : sig
    type t =
      { v : Pure.Ast.t
      ; ast_info : Lang.Ast.Info.t list option
      }
  end

  module Info : sig
    type t =
      { parsing_time : float
      ; stats : Memo.Stats.t option
      ; global_stats : Stats.Global.t  (** Info about cumulative stats *)
      }

    val print : t -> string
  end

  module Message : sig
    type t = Lang.Range.t Pure.Message.t
  end

  type t = private
    { range : Lang.Range.t
    ; prev : t option
    ; ast : Ast.t option  (** Ast of node *)
    ; state : Pure.State.t  (** (Full) State of node *)
    ; diags : Lang.Diagnostic.t list  (** Diagnostics associated to the node *)
    ; messages : Message.t list
    ; info : Info.t
    }

  val range : t -> Lang.Range.t
  val ast : t -> Ast.t option
  val state : t -> Pure.State.t
  val diags : t -> Lang.Diagnostic.t list
  val messages : t -> Message.t list
  val info : t -> Info.t
end

module Completion : sig
  type t = private
    | Yes of Lang.Range.t  (** Location of the last token in the document *)
    | Stopped of Lang.Range.t  (** Location of the last valid token *)
    | Failed of Lang.Range.t  (** Critical failure, like an anomaly *)

  val is_completed : t -> bool
end

(** Enviroment external to the document, this includes for now the [init] Coq
    state and the [workspace], which are used to build the first state of the
    document, usually by importing the prelude and other libs implicitly. *)
module Env : sig
  type t = private
    { init : Pure.State.t
    ; workspace : Pure.Workspace.t
    ; files : Pure.Files.t
    }

  val make :
    init:Pure.State.t -> workspace:Pure.Workspace.t -> files:Pure.Files.t -> t

  (* val inject_requires : extra_requires:Pure.Workspace.Require.t list -> t -> t *)
end

module CString : sig
  module Map : Map.S with type key = string
end

(** A Flèche document is basically a [node list], which is a crude form of a
    meta-data map [Range.t -> data], where for now [data] is the contents of
    [Node.t]. *)
type t = private
  { uri : Lang.LUri.File.t  (** [uri] of the document *)
  ; version : int  (** [version] of the document *)
  ; contents : Contents.t  (** [contents] of the document *)
  ; nodes : Node.t list  (** List of document nodes *)
  ; completed : Completion.t
        (** Status of the document, usually either completed, suspended, or
            waiting for some IO / external event *)
  ; toc : Node.t CString.Map.t  (** table of contents *)
  ; env : Env.t  (** External document enviroment *)
  ; root : Pure.State.t
        (** [root] contains the first state document state, obtained by applying
            a workspace to Coq's initial state *)
  ; diags_dirty : bool  (** internal field *)
  }

(** Return the list of all asts in the doc *)
val asts : t -> Node.Ast.t list

(** Return the list of all diags in the doc *)
val diags : t -> Lang.Diagnostic.t list

(** Create a new Coq document, this is cached! Note that this operation always
    suceeds, but the document could be created in a `Failed` state if problems
    arise. *)
val create :
     token:Pure.Limits.Token.t
  -> env:Env.t
  -> uri:Lang.LUri.File.t
  -> version:int
  -> raw:string
  -> t

(** Update the contents of a document, updating the right structures for
    incremental checking. If the operation fails, the document will be left in
    `Failed` state. *)
val bump_version :
  token:Pure.Limits.Token.t -> version:int -> raw:string -> t -> t

(** Checking targets, this specifies what we expect check to reach *)
module Target : sig
  type t =
    | End
    | Position of int * int

  (** [reached ~range (line,col)] checks if [(line,col)] are before [range]'s
      end. *)
  val reached : range:Lang.Range.t -> int * int -> bool
end

(** [check ~io ~target ~doc ()], check document [doc], [target] will have Flèche
    stop after the point specified there has been reached. Output functions are
    in the [io] record, used to send partial updates. *)
val check :
     io:Io.CallBack.t
  -> token:Pure.Limits.Token.t
  -> target:Target.t
  -> doc:t
  -> unit
  -> t

(*
(** [save ~doc] will save [doc] .vo file. It will fail if proofs are open, or if
    the document completion status is not [Yes] *)
val save : token:Pure.Limits.Token.t -> doc:t -> (unit, Pure.Loc.t) Pure.Protect.E.t

(** [run ~token ?loc ?memo ~st cmds] run commands [cmds] starting on state [st],
    without commiting changes to the document. [loc] can be used to seed an
    initial location if desired, if not the locations will be considered
    relative to the initial location. [memo] controls if the execution is
    memoized, by default [true].

    This API is experimental, used for speculative execution
    [petanque
    and goals], the API is expected to change as to better adapt
    to users. *)
val run :
     token:Pure.Limits.Token.t
  -> ?loc:Pure.Loc.t
  -> ?memo:bool
  -> st:Pure.State.t
  -> string
  -> (Pure.State.t, Pure.Loc.t) Pure.Protect.E.t
*)
