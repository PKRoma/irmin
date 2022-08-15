(*
 * Copyright (c) 2022-2022 Tarides <contact@tarides.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Import

module type S = sig
  (** Abstraction that governs the lifetime of the various files that are part
      of a pack store (except the branch store).

      The file manager handles the files one by one and makes explicit all the
      interactions between them (except the index which is handled at a high
      level). *)

  module Io : Io.S
  module Control : Control_file.S with module Io = Io
  module Dict : Append_only_file.S with module Io = Io
  module Suffix : Append_only_file.S with module Io = Io
  module Index : Pack_index.S
  module Errs : Io_errors.S with module Io = Io
  module Mapping_file : Mapping_file.S with module Io = Io

  type t

  val control : t -> Control.t
  val dict : t -> Dict.t
  val suffix : t -> Suffix.t
  val index : t -> Index.t
  val mapping : t -> Mapping_file.t option
  val prefix : t -> Io.t option

  type create_error :=
    [ Io.create_error
    | Io.write_error
    | Io.open_error
    | Io.mkdir_error
    | `Corrupted_mapping_file of string
    | `Not_a_directory of string
    | `Index_failure of string ]

  val create_rw :
    overwrite:bool -> Irmin.Backend.Conf.t -> (t, [> create_error ]) result
  (** Note on SWMR consistency: It is undefined for a reader to attempt an
      opening before [create_rw] is over.

      Note on crash consistency: Crashing during [create_rw] leaves the storage
      in an undefined state.

      Note on errors: If [create_rw] returns an error, the storage is left in an
      undefined state and some file descriptors might not be closed. *)

  type open_rw_error :=
    [ `Corrupted_control_file
    | `Corrupted_mapping_file of string
    | `Double_close
    | `Closed
    | `File_exists of string
    | `Index_failure of string
    | `Invalid_argument
    | `Invalid_layout
    | `Io_misc of Control.Io.misc_error
    | `Migration_needed
    | `No_such_file_or_directory
    | `Not_a_directory of string
    | `Not_a_file
    | `Read_out_of_bounds
    | `Ro_not_allowed
    | `Sys_error of string
    | `V3_store_from_the_future
    | `Only_minimal_indexing_strategy_allowed
    | `Unknown_major_pack_version of string
    | `Index_failure of string
    | `Sys_error of string
    | `Inconsistent_store ]

  val open_rw : Irmin.Backend.Conf.t -> (t, [> open_rw_error ]) result
  (** Note on SWMR consistency: It is undefined for a reader to attempt and
      opening during an [open_rw].

      Note on crash consistency: If [open_rw] crashes during
      [open_rw_migrate_from_v1_v2], the storage is left in an undefined state.
      Otherwise the storage is unaffected.

      Note on errors: If [open_rw] returns an error during
      [open_rw_migrate_from_v1_v2], the storage is left in an undefined state.
      Otherwise the storage is unaffected. Anyhow, some file descriptors might
      not be closed. *)

  type open_ro_error :=
    [ `Corrupted_control_file
    | `Corrupted_mapping_file of string
    | `File_exists of string
    | `Io_misc of Io.misc_error
    | `Migration_needed
    | `No_such_file_or_directory
    | `Not_a_file
    | `Closed
    | `V3_store_from_the_future
    | `Index_failure of string
    | `Unknown_major_pack_version of string
    | `Inconsistent_store
    | `Invalid_argument
    | `Read_out_of_bounds
    | `Ro_not_allowed ]

  val open_ro : Irmin.Backend.Conf.t -> (t, [> open_ro_error ]) result
  (** Note on SWMR consistency: TODO: doc

      Note on crash consistency: The storage is never mutated.

      Note on errors: The storage is never mutated. Some file descriptors might
      not be closed. *)

  type close_error :=
    [ `Double_close
    | `Index_failure of string
    | `Io_misc of Io.misc_error
    | `Pending_flush
    | `Ro_not_allowed ]

  val close : t -> (unit, [> close_error ]) result
  (** Close all the files.

      This call fails if the append buffers are not in a flushed stated. This
      situation will most likely never occur because the append buffers will
      contain data only during the scope of a batch function.

      After *)

  type flush_error :=
    [ `Index_failure of string
    | `Io_misc of Io.misc_error
    | `Ro_not_allowed
    | `Closed ]

  type flush_stages := [ `After_dict | `After_suffix ]
  type 'a hook := 'a -> unit

  val flush : ?hook:flush_stages hook -> t -> (unit, [> flush_error ]) result

  type reload_stages := [ `After_index | `After_control | `After_suffix ]

  val reload : ?hook:reload_stages hook -> t -> (unit, [> Errs.t ]) result

  val register_mapping_consumer :
    t -> after_reload:(unit -> (unit, Errs.t) result) -> unit

  val register_dict_consumer :
    t -> after_reload:(unit -> (unit, Errs.t) result) -> unit

  val register_suffix_consumer : t -> after_flush:(unit -> unit) -> unit

  type version_error :=
    [ `Corrupted_control_file
    | `Corrupted_legacy_file
    | `Invalid_layout
    | `Io_misc of Io.misc_error
    | `No_such_file_or_directory
    | `Not_a_directory of string
    | `Unknown_major_pack_version of string ]

  val version : root:string -> (Import.Version.t, [> version_error ]) result
  (** [version ~root] is the version of the files at [root]. *)

  val swap :
    t ->
    generation:int ->
    right_start_offset:int63 ->
    right_end_offset:int63 ->
    (unit, [> Errs.t ]) result

  type write_gc_output_error :=
    [ `Double_close
    | `File_exists of string
    | `Io_misc of Io.misc_error
    | `Ro_not_allowed
    | `Closed ]

  val write_gc_output :
    root:string ->
    generation:int ->
    (int63, Errs.t) result ->
    (unit, [> write_gc_output_error ]) result
  (** Used by the gc process at the end to write its output in
      store.<generation>.out. *)

  type read_gc_output_error =
    [ `Corrupted_gc_result_file of string | `Gc_process_error of string ]
  [@@deriving irmin]

  val read_gc_output :
    root:string -> generation:int -> (int63, [> read_gc_output_error ]) result
  (** Used by the main process, after the gc process finished, to read
      store.<generation>.out. *)

  val readonly : t -> bool
  val generation : t -> int
  val gc_allowed : t -> bool
end

module type Sigs = sig
  module type S = S

  module Make
      (Control : Control_file.S with module Io = Io.Unix)
      (Dict : Append_only_file.S with module Io = Control.Io)
      (Suffix : Append_only_file.S with module Io = Control.Io)
      (Index : Pack_index.S)
      (Errs : Io_errors.S with module Io = Control.Io) :
    S
      with module Io = Control.Io
       and module Control = Control
       and module Dict = Dict
       and module Suffix = Suffix
       and module Index = Index
end