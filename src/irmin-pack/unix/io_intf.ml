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

module Errors = struct
  exception
    Io_error of
      [ `Double_close
      | `File_exists
      | `Invalid_parent_directory
      | `No_such_file_or_directory
      | `Not_a_file
      | `Read_on_closed
      | `Read_out_of_bounds
      | `Ro_not_allowed
      | `Write_on_closed
      | `Invalid_argument ]
end

module type S = sig
  (** Low level IO abstraction. A typical implementation is unix.

      This abstraction is meant to be dead simple. Not a lot of documentation is
      required.

      It is not resistant to race condictions. There should not be concurrent
      modifications of the files. *)

  type t

  (** {1 Errors} *)

  type misc_error
  (** An abstract error type that contains the IO-backend specific errors. (e.g.
      [Unix.error]) *)

  type create_error = [ `Io_misc of misc_error | `File_exists ]

  type open_error =
    [ `Io_misc of misc_error | `No_such_file_or_directory | `Not_a_file ]

  type read_error =
    [ `Io_misc of misc_error
    | `Read_out_of_bounds
    | `Read_on_closed
    | `Invalid_argument ]

  type write_error =
    [ `Io_misc of misc_error | `Ro_not_allowed | `Write_on_closed ]

  type close_error = [ `Io_misc of misc_error | `Double_close ]
  type move_file_error = [ `Io_misc of misc_error ]

  type mkdir_error =
    [ `Io_misc of misc_error
    | `File_exists
    | `No_such_file_or_directory
    | `Invalid_parent_directory ]

  include module type of Errors

  (** {1 Safe Functions}

      None of the functions in this section raise exceptions. They may however
      perform effects that are always continued.

      {2 Life Cycle} *)

  val create : path:string -> overwrite:bool -> (t, [> create_error ]) result
  val open_ : path:string -> readonly:bool -> (t, [> open_error ]) result
  val close : t -> (unit, [> close_error ]) result

  (** {2 Write Functions} *)

  val write_string : t -> off:int63 -> string -> (unit, [> write_error ]) result
  (** [write_string t ~off s] writes [s] at [offset] in [t]. *)

  val fsync : t -> (unit, [> write_error ]) result
  (** [fsync t] persists to the file system the effects of previous [create] or
      write. *)

  val move_file :
    src:string -> dst:string -> (unit, [> move_file_error ]) result

  val mkdir : string -> (unit, [> mkdir_error ]) result

  (** {2 Read Functions} *)

  val read_to_string :
    t -> off:int63 -> len:int -> (string, [> read_error ]) result
  (** [read_to_string t ~off ~len] are the [len] bytes of [t] at [off]. *)

  val read_size : t -> (int63, [> read_error ]) result
  (** [read_size t] is the number of bytes of the file handled by [t].

      This function is expensive in the unix implementation because it performs
      syscalls. *)

  val classify_path :
    string -> [> `File | `Directory | `No_such_file_or_directory | `Other ]

  (** {1 MISC.} *)

  val readonly : t -> bool
  val path : t -> string
  val page_size : int

  (** {1 Unsafe Functions}

      These functions are equivalents to exising safe ones, but using exceptions
      instead of the result monad for performances reasons. *)

  val read_exn : t -> off:int63 -> len:int -> bytes -> unit
  (** [read_exn t ~off ~len b] reads the [len] bytes of [t] at [off] to [b].

      Raises [Io_error].

      Also raises backend-specific exceptions (e.g. [Unix.Unix_error] for the
      unix backend). *)

  val write_exn : t -> off:int63 -> string -> unit
  (** [write_exn t ~off b] writes [b] to [t] at offset [off].

      Raises [Io_error]

      Also raises backend-specific exceptions (e.g. [Unix.Unix_error] for the
      unix backend). *)
end

module type Sigs = sig
  include module type of Errors

  module type S = S

  module Unix : S with type misc_error = Unix.error * string * string
end
