(*
 * Copyright (c) 2018-2021 Tarides <contact@tarides.com>
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

open! Import
open Common

let root = Filename.concat "_build" "test-tree"

module Store = struct
  module Maker = Irmin_pack.Maker (Irmin_pack.Version.V2) (Conf)
  include Maker.Make (Schema)
end

let config ?(readonly = false) ?(fresh = true) root =
  Irmin_pack.config ~readonly ?index_log_size ~fresh root

let info () = Store.Info.empty

module Tree = Store.Tree

type bindings = string list list [@@deriving irmin]

let equal_string_list_list ~msg l1 l2 = Alcotest.check_repr bindings_t msg l1 l2

let persist_tree tree =
  let* store = Store.Repo.v (config root) >>= Store.empty in
  let* () = Store.set_tree_exn ~info:Store.Info.none store [] tree in
  Store.tree store

let fold ?depth t k ~init ~f =
  Tree.find_tree t k >>= function
  | None -> Lwt.return init
  | Some t ->
      Tree.fold ?depth ~force:`True ~cache:false ~uniq:`False
        ~node:(fun k v acc -> f k (Store.Tree.of_node v) acc)
        ~contents:(fun k v acc ->
          if k = [] then Lwt.return acc else f k (Store.Tree.of_contents v) acc)
        t init

let kind t =
  match Tree.destruct t with `Contents _ -> `Value | `Node _ -> `Tree

let fold_keys s root ~init ~f =
  fold s root ~init ~f:(fun k v acc ->
      match kind v with `Value -> f (root @ k) acc | `Tree -> Lwt.return acc)

let steps =
  ["00"; "01"; "02"; "03"; "05"; "06"; "07"; "09"; "0a"; "0b"; "0c";
   "0e"; "0f"; "10"; "11"; "12"; "13"; "14"; "15"; "16"; "17"; "19";
   "1a"; "1b"; "1c"; "1d"; "1e"; "1f"; "20"; "22"; "23"; "25"; "26";
   "27"; "28"; "2a"; "2b"; "2f"; "30"; "31"; "32"; "33"; "35"; "36";
   "37"; "3a"; "3b"; "3c"; "3d"; "3e"; "3f"; "40"; "42"; "43"; "45";
   "46"; "47"; "48"; "4a"; "4b"; "4c"; "4e"; "4f"; "50"; "52"; "53";
   "54"; "55"; "56"; "57"; "59"; "5b"; "5c"; "5f"; "60"; "61"; "62";
   "63"; "64"; "65"; "66"; "67"; "69"; "6b"; "6c"; "6d"; "6e"; "6f";
   "71"; "72"; "73"; "74"; "75"; "78"; "79"; "7a"; "7b"; "7c"; "7d";
   "7e"; "80"; "82"; "83"; "84"; "85"; "86"; "88"; "8b"; "8c"; "8d";
   "8f"; "92"; "93"; "94"; "96"; "97"; "99"; "9a"; "9b"; "9d"; "9e";
   "9f"; "a0"; "a1"; "a2"; "a3"; "a4"; "a5"; "a6"; "a7"; "a8"; "aa";
   "ab"; "ac"; "ad"; "ae"; "af"; "b0"; "b1"; "b2"; "b3"; "b4"; "b6";
   "b8"; "b9"; "bb"; "bc"; "bf"; "c0"; "c1"; "c2"; "c3"; "c4"; "c5";
   "c8"; "c9"; "cb"; "cc"; "cd"; "ce"; "d0"; "d1"; "d2"; "d4"; "d5";
   "d7"; "d8"; "d9"; "da"; "e0"; "e3"; "e6"; "e8"; "e9"; "ea"; "ec";
   "ee"; "ef"; "f0"; "f1"; "f5"; "f7"; "f8"; "f9"; "fb"; "fc"; "fd";
   "fe"; "ff"; "g0"; "g1"; "g2"; "g3"; "g4"; "g5"; "g6"; "g7"; "g8";
   "h0"; "h1"; "h2"; "h3"; "h4"; "h5"; "h6"; "h7"; "h8"; "h9"; "ha";
   "i0"; "i1"; "i2"; "i3"; "i4"; "i5"; "i6"; "i7"; "i8"; "i9"; "ia";
   "j0"; "j1"; "j2"; "j3"; "j4"; "j5"; "j6"; "j7"; "j8"; "j9"; "ja";
   "k0"; "k1"; "k2"; "k3"; "k4"; "k5"; "k6"; "k7"; "k8"; "k9"; "ka";
   "l0"; "l1"; "l2"; "l3"; "l4"; "l5"; "l6"; "l7"; "l8"; "l9"; "la";
   "m0"; "m1"; "m2"; "m3"; "m4"; "m5"; "m6"; "m7"; "m8"; "m9"; "ma";
   "n0"; "n1"; "n2"; "n3"; "n4"; "n5"; "n6"; "n7"; "n8"; "n9"; "na";
   "p0"; "p1"; "p2"; "p3"; "p4"; "p5"; "p6"; "p7"; "p8"; "p9"; "pa";
   "q0"; "q1"; "q2"; "q3"; "q4"; "q5"; "q6"; "q7"; "q8"; "q9"; "qa";
   "r0"; "r1"; "r2"; "r3"; "r4"; "r5"; "r6"; "r7"; "r8"; "r9"; "ra";]
[@@ocamlformat "disable"]

let bindings =
  let zero = String.make 10 '0' in
  List.map (fun x -> ([ "data"; "root"; x ], zero)) steps

let test_fold_keys () =
  let ctxt = Tree.empty in
  Lwt_list.fold_left_s (fun ctxt (k, v) -> Tree.add ctxt k v) ctxt bindings
  >>= fun ctxt ->
  persist_tree ctxt >>= fun ctxt ->
  fold_keys ctxt [ "data"; "root" ] ~init:[] ~f:(fun k acc ->
      Lwt.return (k :: acc))
  >>= fun bs ->
  let bs = List.rev bs in
  equal_string_list_list ~msg:"Visit elements in lexicographical order"
    (List.map fst bindings) bs;
  Lwt.return_unit

let tests =
  [
    Alcotest.test_case "test fold keys" `Quick (fun () ->
        Lwt_main.run (test_fold_keys ()));
  ]
