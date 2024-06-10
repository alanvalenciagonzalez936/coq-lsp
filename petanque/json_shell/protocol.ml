open Lang
open Petanque

(* Serialization for agent types *)
open JAgent

(* RPC-side server mappings, internal; we could split this in a different module
   eventually as to make this clearer. *)
module HType = struct
  type ('p, 'r) t =
    | Immediate of (token:Coq.Limits.Token.t -> 'p -> 'r R.t)
    | FullDoc of
        { uri_fn : 'p -> LUri.File.t
        ; handler : token:Coq.Limits.Token.t -> doc:Fleche.Doc.t -> 'p -> 'r R.t
        }
end

module type Handler = sig
  (* Server-side RPC specification *)
  module Params : sig
    type t [@@deriving of_yojson]
  end

  (* Server-side RPC specification *)
  module Response : sig
    type t [@@deriving to_yojson]
  end

  val handler : (Params.t, Response.t) HType.t
end

(* Note that here we follow JSON-RPC / LSP capitalization conventions *)
module Request = struct
  module type S = sig
    val method_ : string

    (* Protocol params specification *)
    module Params : sig
      type t [@@deriving yojson]
    end

    (* Protocol response specification *)
    module Response : sig
      type t [@@deriving yojson]
    end

    module Handler : Handler
  end
end

(* start RPC *)
module Start = struct
  let method_ = "petanque/start"

  module Params = struct
    type t =
      { uri : Lsp.JLang.LUri.File.t
      ; pre_commands : string option [@default None]
      ; thm : string
      }
    [@@deriving yojson]
  end

  module Response = struct
    type t = int [@@deriving yojson]
  end

  module Handler = struct
    module Params = struct
      type t =
        { uri : Lsp.JLang.LUri.File.t
        ; pre_commands : string option [@default None]
        ; thm : string
        }
      [@@deriving yojson]
    end

    module Response = struct
      type t = State.t [@@deriving yojson]
    end

    let handler =
      HType.FullDoc
        { uri_fn = (fun { Params.uri; _ } -> uri)
        ; handler =
            (fun ~token ~doc { Params.uri = _; pre_commands; thm } ->
              Agent.start ~token ~doc ?pre_commands ~thm ())
        }
  end
end

(* run_tac RPC *)
module RunTac = struct
  let method_ = "petanque/run"

  module Params = struct
    type t =
      { memo : bool option
            [@default None] (* Whether to memoize the execution, server-side *)
      ; st : int
      ; tac : string
      }
    [@@deriving yojson]
  end

  module Response = struct
    type t = int Run_result.t [@@deriving yojson]
  end

  module Handler = struct
    module Params = struct
      type t =
        { memo : bool option
              [@default None] (* Whether to memoize the execution *)
        ; st : State.t
        ; tac : string
        }
      [@@deriving yojson]
    end

    module Response = struct
      type t = State.t Run_result.t [@@deriving yojson]
    end

    let handler =
      HType.Immediate
        (fun ~token { Params.memo; st; tac } ->
          Agent.run ~token ?memo ~st ~tac ())
  end
end

(* goals RPC *)
module Goals = struct
  let method_ = "petanque/goals"

  module Params = struct
    type t = { st : int } [@@deriving yojson]
  end

  module Response = struct
    type t = Goals.t [@@deriving yojson]
  end

  module Handler = struct
    module Params = struct
      type t = { st : State.t } [@@deriving yojson]
    end

    module Response = Response

    let handler =
      HType.Immediate (fun ~token { Params.st } -> Agent.goals ~token ~st)
  end
end

(* premises RPC *)
module Premises = struct
  let method_ = "petanque/premises"

  module Params = struct
    type t = { st : int } [@@deriving yojson]
  end

  module Response = struct
    type t = Premise.t list [@@deriving yojson]
  end

  module Handler = struct
    module Params = struct
      type t = { st : State.t } [@@deriving yojson]
    end

    module Response = Response

    let handler =
      HType.Immediate (fun ~token { Params.st } -> Agent.premises ~token ~st)
  end
end
