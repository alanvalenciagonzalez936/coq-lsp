import {
  VersionedTextDocumentIdentifier,
  Position,
  Range,
} from "vscode-languageserver-types";

export interface Hyp<Pp> {
  names: Pp[];
  def?: Pp;
  ty: Pp;
}

export interface Goal<Pp> {
  ty: Pp;
  hyps: Hyp<Pp>[];
}

export interface GoalConfig<Pp> {
  goals: Goal<Pp>[];
  stack: [Goal<Pp>[], Goal<Pp>[]][];
  bullet?: Pp;
  shelf: Goal<Pp>[];
  given_up: Goal<Pp>[];
}

export interface Message<Pp> {
  range?: Range;
  level: number;
  text: Pp;
}

export type Id = ["Id", string];

// XXX: Only used in obligations, move them to Range
export interface Loc {
  fname: any;
  line_nb: number;
  bol_pos: number;
  line_nb_last: number;
  bol_pos_last: number;
  bp: number;
  ep: number;
}

export interface Obl {
  name: Id;
  loc?: Loc;
  status: [boolean, any];
  solved: boolean;
}

export interface OblsView {
  opaque: boolean;
  remaining: number;
  obligations: Obl[];
}

export type ProgramInfo = [Id, OblsView][];

export interface GoalAnswer<Pp> {
  textDocument: VersionedTextDocumentIdentifier;
  position: Position;
  goals?: GoalConfig<Pp>;
  program?: ProgramInfo;
  messages: Pp[] | Message<Pp>[];
  error?: Pp;
}

export interface GoalRequest {
  textDocument: VersionedTextDocumentIdentifier;
  position: Position;
  pp_format?: "Pp" | "Str";
  pretac?: string;
  command?: string;
  mode?: "Prev" | "After";
}

export type Pp =
  | ["Pp_empty"]
  | ["Pp_string", string]
  | ["Pp_glue", Pp[]]
  | ["Pp_box", any, Pp]
  | ["Pp_tag", any, Pp]
  | ["Pp_print_break", number, number]
  | ["Pp_force_newline"]
  | ["Pp_comment", string[]];

export type PpString = Pp | string;

export interface FlecheDocumentParams {
  textDocument: VersionedTextDocumentIdentifier;
}

// Status of the document, Yes if fully checked, range contains the last seen lexical token
interface CompletionStatus {
  status: ["Yes" | "Stopped" | "Failed"];
  range: Range;
}

// Implementation-specific span information, for now the serialized Ast if present.
type SpanInfo = any;

interface RangedSpan {
  range: Range;
  span?: SpanInfo;
}

export interface FlecheDocument {
  spans: RangedSpan[];
  completed: CompletionStatus;
}

export interface FlecheSaveParams {
  textDocument: VersionedTextDocumentIdentifier;
}

export interface PerfInfo {
  // Original Execution Time (when not cached)
  time: number;
  // Difference in words allocated in the heap using `Gc.quick_stat`
  memory: number;
  // Whether the execution was cached
  cache_hit: boolean;
  // Caching overhead
  time_hash: number;
}

export interface SentencePerfParams<R> {
  range: R;
  info: PerfInfo;
}

export interface DocumentPerfParams<R> {
  textDocument: VersionedTextDocumentIdentifier;
  summary: string;
  timings: SentencePerfParams<R>[];
}

// View messaging interfaces; should go on their own file
export interface RenderGoals {
  method: "renderGoals";
  params: GoalAnswer<PpString>;
}

export interface WaitingForInfo {
  method: "waitingForInfo";
  params: GoalRequest;
}

export interface ErrorData {
  textDocument: VersionedTextDocumentIdentifier;
  position: Position;
  message: string;
}

export interface InfoError {
  method: "infoError";
  params: ErrorData;
}

export type CoqMessagePayload = RenderGoals | WaitingForInfo | InfoError;

export interface CoqMessageEvent extends MessageEvent {
  data: CoqMessagePayload;
}

// For perf panel data
export interface PerfUpdate {
  method: "update";
  params: DocumentPerfParams<Range>;
}

export interface PerfReset {
  method: "reset";
}

export type PerfMessagePayload = PerfUpdate | PerfReset;

export interface PerfMessageEvent extends MessageEvent {
  data: PerfMessagePayload;
}

export interface ViewRangeParams {
  textDocument: VersionedTextDocumentIdentifier;
  range: Range;
}
