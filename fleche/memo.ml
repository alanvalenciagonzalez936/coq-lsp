module CS = Stats

module Stats = struct
  type 'a t =
    { res : 'a
    ; cache_hit : bool
    ; memory : int
    ; time : float
    }

  let make ?(cache_hit = false) ~time res =
    (* This is quite slow! *)
    (* let memory = Obj.magic res |> Obj.reachable_words in *)
    let memory = 0 in
    { res; cache_hit; memory; time }
end

module CacheStats = struct
  let nhit, ntotal = (ref 0, ref 0)

  let reset () =
    nhit := 0;
    ntotal := 0

  let hit () =
    incr nhit;
    incr ntotal

  let miss () = incr ntotal

  let stats () =
    if !ntotal = 0 then "no stats"
    else
      let hit_rate =
        Stdlib.Float.of_int !nhit /. Stdlib.Float.of_int !ntotal *. 100.0
      in
      Format.asprintf "cache hit rate: %3.2f" hit_rate
end

module MemoTable = struct
  module type S = sig
    (* Stronger than Hashtbl.S due to the more advanced cache *)
    type key
    type !'a t

    val create : int -> 'a t
    val find_opt : 'a t -> key -> 'a option

    (* Clears the cache *)
    val clear : 'a t -> unit

    val add_execution :
      ('a, 'l) Coq.Protect.E.t t -> key -> ('a, 'l) Coq.Protect.E.t -> unit

    val add_execution_loc :
         ('v * ('a, 'l) Coq.Protect.E.t) t
      -> key
      -> 'v * ('a, 'l) Coq.Protect.E.t
      -> unit

    (** sorted *)
    val all_freqs : unit -> int list
  end

  module Make (H : Hashtbl.HashedType) : S with type key = H.t = struct
    include Hashtbl.Make (H)

    (* Number of times a value has been found *)
    let count = create 1000

    let clear t =
      clear count;
      clear t

    let add t k v =
      replace count k 0;
      add t k v

    let find_opt t k =
      match find_opt t k with
      | None -> None
      | Some res ->
        replace count k (find count k + 1);
        Some res

    let all_freqs () =
      to_seq_values count |> List.of_seq
      |> List.sort (fun x y -> -Int.compare x y)

    let add_execution t k ({ Coq.Protect.E.r; _ } as v) =
      match r with
      | Coq.Protect.R.Interrupted -> ()
      | _ -> add t k v

    let add_execution_loc t k ((_, { Coq.Protect.E.r; _ }) as v) =
      match r with
      | Coq.Protect.R.Interrupted -> ()
      | _ -> add t k v
  end
end

(* XXX: Move elsewhere *)
module Loc_utils : sig
  val adjust_offset :
       stm_loc:Loc.t
    -> cached_loc:Loc.t
    -> ('a, Loc.t) Coq.Protect.E.t
    -> ('a, Loc.t) Coq.Protect.E.t
end = struct
  let loc_offset (l1 : Loc.t) (l2 : Loc.t) =
    let line_offset = l2.line_nb - l1.line_nb in
    let bol_offset = l2.bol_pos - l1.bol_pos in
    let line_last_offset = l2.line_nb_last - l1.line_nb_last in
    let bol_last_offset = l2.bol_pos_last - l1.bol_pos_last in
    let bp_offset = l2.bp - l1.bp in
    let ep_offset = l2.ep - l1.ep in
    ( line_offset
    , bol_offset
    , line_last_offset
    , bol_last_offset
    , bp_offset
    , ep_offset )

  let loc_apply_offset
      ( line_offset
      , bol_offset
      , line_last_offset
      , bol_last_offset
      , bp_offset
      , ep_offset ) (loc : Loc.t) =
    { loc with
      line_nb = loc.line_nb + line_offset
    ; bol_pos = loc.bol_pos + bol_offset
    ; line_nb_last = loc.line_nb_last + line_last_offset
    ; bol_pos_last = loc.bol_pos_last + bol_last_offset
    ; bp = loc.bp + bp_offset
    ; ep = loc.ep + ep_offset
    }

  let adjust_offset ~stm_loc ~cached_loc res =
    let offset = loc_offset cached_loc stm_loc in
    let f = loc_apply_offset offset in
    Coq.Protect.E.map_loc ~f res
end

module type EvalType = sig
  include Hashtbl.HashedType

  type output

  val eval : token:Coq.Limits.Token.t -> t -> (output, Loc.t) Coq.Protect.E.t
  val input_info : t -> string
end

(** Flèche memo / cache tables, with some advanced features *)
module type S = sig
  type input
  type output

  (** [eval i] Eval an input [i] *)
  val eval :
    token:Coq.Limits.Token.t -> input -> (output, Loc.t) Coq.Protect.E.t

  (** [eval i] Eval an input [i] and produce stats *)
  val evalS :
    token:Coq.Limits.Token.t -> input -> (output, Loc.t) Coq.Protect.E.t Stats.t

  (** [size ()] Return the cache size in words, expensive *)
  val size : unit -> int

  (** [freqs ()]: (sorted) histogram *)
  val all_freqs : unit -> int list

  (** debug data for input *)
  val input_info : input -> string

  (** clears the cache *)
  val clear : unit -> unit
end

module SEval (E : EvalType) :
  S with type input = E.t and type output = E.output = struct
  type input = E.t
  type output = E.output

  module HC = MemoTable.Make (E)

  let cache = HC.create 1000
  let size () = Obj.reachable_words (Obj.magic cache)
  let input_info i = E.input_info i
  let all_freqs = HC.all_freqs
  let clear () = HC.clear cache

  let eval ~token v =
    match HC.find_opt cache v with
    | None ->
      let res = E.eval ~token v in
      HC.add_execution cache v res;
      res
    | Some cached_res -> cached_res

  let in_cache i =
    let kind = CS.Kind.Hashing in
    CS.record ~kind ~f:(HC.find_opt cache) i

  let evalS ~token i =
    match in_cache i with
    | Some cached_res, time -> Stats.make ~cache_hit:true ~time cached_res
    | None, time_hash ->
      let kind = CS.Kind.Exec in
      let f i = E.eval ~token i in
      let res, time_interp = CS.record ~kind ~f i in
      let () = HC.add_execution cache i res in
      let time = time_hash +. time_interp in
      Stats.make ~cache_hit:false ~time res
end

module type LocEvalType = sig
  include EvalType

  val loc_of_input : t -> Loc.t
end

module CEval (E : LocEvalType) = struct
  type input = E.t
  type output = E.output

  module HC = MemoTable.Make (E)

  module Result = struct
    (* We store the location as to compute an offset for cached results *)
    type t = Loc.t * (E.output, Loc.t) Coq.Protect.E.t
  end

  type cache = Result.t HC.t

  let cache : cache = HC.create 1000

  (* This is very expensive *)
  let size () = Obj.reachable_words (Obj.magic cache)
  let all_freqs = HC.all_freqs
  let input_info = E.input_info
  let clear () = HC.clear cache

  let in_cache i =
    let kind = CS.Kind.Hashing in
    CS.record ~kind ~f:(HC.find_opt cache) i

  let evalS ~token i : _ Stats.t =
    let stm_loc = E.loc_of_input i in
    match in_cache i with
    | Some (cached_loc, res), time ->
      if Debug.cache then Io.Log.trace "memo" "cache hit";
      CacheStats.hit ();
      let res = Loc_utils.adjust_offset ~stm_loc ~cached_loc res in
      Stats.make ~cache_hit:true ~time res
    | None, time_hash ->
      if Debug.cache then Io.Log.trace "memo" "cache miss";
      CacheStats.miss ();
      let kind = CS.Kind.Exec in
      let res, time_interp = CS.record ~kind ~f:(E.eval ~token) i in
      let () = HC.add_execution_loc cache i (stm_loc, res) in
      let time = time_hash +. time_interp in
      Stats.make ~time res

  let eval ~token i = (evalS ~token i).res
end

module VernacEval = struct
  type t = Coq.State.t * Coq.Ast.t

  (* This crutially relies on our ppx to ignore the CAst location *)
  let equal (st1, v1) (st2, v2) =
    if Coq.Ast.compare v1 v2 = 0 then
      if Coq.State.compare st1 st2 = 0 then true else false
    else false

  let hash (st, v) = Hashtbl.hash (Coq.Ast.hash v, Coq.State.hash st)
  let loc_of_input (_, stm) = Coq.Ast.loc stm |> Option.get

  let input_info (st, v) =
    Format.asprintf "stm: %d | st %d" (Coq.Ast.hash v) (Hashtbl.hash st)

  type output = Coq.State.t

  let eval ~token (st, stm) = Coq.Interp.interp ~token ~st stm
end

module Interp = CEval (VernacEval)

module RequireEval = struct
  type t = Coq.State.t * Coq.Files.t * Coq.Ast.Require.t

  (* This crutially relies on our ppx to ignore the CAst location *)
  let equal (st1, f1, r1) (st2, f2, r2) =
    if
      Coq.Ast.Require.compare r1 r2 = 0
      && Coq.Files.compare f1 f2 = 0
      && Coq.State.compare st1 st2 = 0
    then true
    else false

  let hash (st, f, v) =
    Hashtbl.hash (Coq.Ast.Require.hash v, Coq.Files.hash f, Coq.State.hash st)

  let input_info (st, f, v) =
    Format.asprintf "stm: %d | st %d | f %d" (Coq.Ast.Require.hash v)
      (Hashtbl.hash st) (Coq.Files.hash f)

  let loc_of_input (_, _, stm) = Option.get stm.Coq.Ast.Require.loc

  type output = Coq.State.t

  let eval ~token (st, files, stm) =
    Coq.Interp.Require.interp ~token ~st files stm
end

module Require = CEval (RequireEval)

module Admit = SEval (struct
  include Coq.State

  type output = Coq.State.t

  let input_info st = Format.asprintf "st %d" (Hashtbl.hash st)
  let eval ~token st = Coq.State.admit ~token ~st
end)

module InitEval = struct
  type t = Coq.State.t * Coq.Workspace.t * Lang.LUri.File.t

  let equal (s1, w1, u1) (s2, w2, u2) : bool =
    if Lang.LUri.File.compare u1 u2 = 0 then
      if Coq.Workspace.compare w1 w2 = 0 then
        if Coq.State.compare s1 s2 = 0 then true else false
      else false
    else false

  let hash (st, w, uri) =
    Hashtbl.hash
      (Coq.State.hash st, Coq.Workspace.hash w, Lang.LUri.File.hash uri)

  type output = Coq.State.t

  let eval ~token (root_state, workspace, uri) =
    Coq.Init.doc_init ~token ~root_state ~workspace ~uri

  let input_info (st, ws, file) =
    Format.asprintf "st %d | ws %d | file %s" (Hashtbl.hash st)
      (Hashtbl.hash ws)
      (Lang.LUri.File.to_string_file file)
end

module Init = SEval (InitEval)

let all_size () =
  Init.size () + Interp.size () + Require.size () + Admit.size ()
