(************************************************************************)
(* Coq Language Server Protocol                                         *)
(* Copyright 2019 MINES ParisTech -- LGPL 2.1+                          *)
(* Copyright 2019-2023 Inria -- LGPL 2.1+                               *)
(* Written by: Emilio J. Gallego Arias                                  *)
(************************************************************************)

module Pp = JCoq.Pp

module Point = struct
  type t = [%import: Lang.Point.t] [@@deriving yojson]
end

module Range = struct
  type t = [%import: (Lang.Range.t[@with Lang.Point.t := Point.t])]
  [@@deriving yojson]
end

module LUri = struct
  module File = struct
    type t = Lang.LUri.File.t

    let to_yojson uri = `String (Lang.LUri.File.to_string_uri uri)
    let invalid_uri msg obj = raise (Yojson.Safe.Util.Type_error (msg, obj))

    let of_yojson uri =
      match uri with
      | `String uri as obj -> (
        let uri = Lang.LUri.of_string uri in
        match Lang.LUri.File.of_uri uri with
        | Result.Ok t -> Result.Ok t
        | Result.Error msg -> invalid_uri ("failed to parse uri: " ^ msg) obj)
      | obj -> invalid_uri "expected uri string, got json object" obj
  end
end

module Qf = struct
  type 'l t = [%import: 'l Lang.Qf.t] [@@deriving yojson]
end

module Diagnostic = struct
  module Libnames = Serlib.Ser_libnames

  module FailedRequire = struct
    type t = [%import: Lang.Diagnostic.FailedRequire.t] [@@deriving yojson]
  end

  module Data = struct
    module Lang = struct
      module Range = Range
      module Qf = Qf
      module FailedRequire = FailedRequire
      module Diagnostic = Lang.Diagnostic
    end

    type t = [%import: Lang.Diagnostic.Data.t] [@@deriving yojson]
  end

  (* LSP Ranges, a bit different from Fleche's ranges as points don't include
     offsets *)
  module Point = struct
    type t =
      { line : int
      ; character : int
      }
    [@@deriving yojson]

    let conv { Lang.Point.line; character; offset = _ } = { line; character }
    let vnoc { line; character } = { Lang.Point.line; character; offset = -1 }
  end

  module Range = struct
    type t =
      { start : Point.t
      ; end_ : Point.t [@key "end"]
      }
    [@@deriving yojson]

    let conv { Lang.Range.start; end_ } =
      let start = Point.conv start in
      let end_ = Point.conv end_ in
      { start; end_ }

    let vnoc { start; end_ } =
      let start = Point.vnoc start in
      let end_ = Point.vnoc end_ in
      { Lang.Range.start; end_ }
  end

  (* Current Flèche diagnostic is not LSP-standard compliant, this one is *)
  type t = Lang.Diagnostic.t

  type _t =
    { range : Range.t
    ; severity : int
    ; message : string
    ; data : Data.t option [@default None]
    }
  [@@deriving yojson]

  let to_yojson { Lang.Diagnostic.range; severity; message; data } =
    let range = Range.conv range in
    let message = Pp.to_string message in
    _t_to_yojson { range; severity; message; data }

  let of_yojson json =
    match _t_of_yojson json with
    | Ok { range; severity; message; data } ->
      let range = Range.vnoc range in
      let message = Pp.str message in
      Ok { Lang.Diagnostic.range; severity; message; data }
    | Error err -> Error err
end

module Stdlib = JStdlib

module With_range = struct
  type 'a t = [%import: ('a Lang.With_range.t[@with Lang.Range.t := Range.t])]
  [@@deriving yojson]
end

module Ast = struct
  module Name = struct
    type t = [%import: Lang.Ast.Name.t] [@@deriving yojson]
  end

  module Info = struct
    type t =
      [%import:
        (Lang.Ast.Info.t
        [@with
          Lang.Range.t := Range.t;
          Lang.With_range.t := With_range.t])]
    [@@deriving yojson]
  end
end
