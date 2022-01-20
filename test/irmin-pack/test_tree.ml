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

module Hash = Irmin.Hash.SHA1

type ('key, 'value) op =
  | Add of 'key * 'value
  | Del of 'key
  | Find of 'key
  | Find_tree of 'key

module Make (Conf : Irmin_pack.Conf.S) = struct
  module Store = struct
    module P = Irmin.Path.String_list
    module M = Irmin.Metadata.None
    module XNode = Irmin.Private.Node.Make
    module XCommit = Irmin.Private.Commit.Make

    include
      Irmin_pack.Make_ext (Irmin_pack.Version.V2) (Conf) (XNode) (XCommit) (M)
        (Irmin.Contents.String)
        (P)
        (Irmin.Branch.String)
        (Hash)
  end

  let config ?(readonly = false) ?(fresh = true) root =
    Irmin_pack.config ~readonly ?index_log_size ~fresh root

  let info () = Irmin.Info.empty

  module Tree = Store.Tree

  type context = { repo : Store.repo; tree : Store.tree }

  let persist_tree tree =
    let* repo = Store.Repo.v (config root) in
    let* store = Store.empty repo in
    let* () = Store.set_tree_exn ~info store [] tree in
    let+ tree = Store.tree store in
    { repo; tree }

  let close { repo; _ } = Store.Repo.close repo

  let fold ~order t ~init ~f =
    Tree.fold ~order ~force:`True ~cache:false ~uniq:`False
      ~contents:(fun k _v acc -> if k = [] then Lwt.return acc else f k acc)
      t init

  let init_bindings n =
    let zero = String.make 10 '0' in
    List.init n (fun n ->
        let h = Store.Contents.hash (string_of_int n) in
        let h = Irmin.Type.to_string Store.Hash.t h in
        ([ h ], zero))

  let init_tree bindings =
    let tree = Tree.empty () in
    let* tree =
      Lwt_list.fold_left_s (fun tree (k, v) -> Tree.add tree k v) tree bindings
    in
    persist_tree tree

  let find_tree tree k =
    let+ t = Tree.find_tree tree k in
    match t with None -> tree | Some t -> t

  let find tree k =
    let+ _ = Tree.find tree k in
    tree

  let run_one tree = function
    | Add (k, v) -> Tree.add tree k v
    | Del k -> Tree.remove tree k
    | Find k -> find tree k
    | Find_tree k -> find_tree tree k

  let run ops tree =
    let+ t = Lwt_list.fold_left_s run_one tree ops in
    (t, ())

  let proof_of_ops repo hash ops : _ Lwt.t =
    let+ t, () = Store.Tree.produce_proof repo hash (run ops) in
    t

  let tree_proof_t = Tree.Proof.t Tree.Proof.tree_t
  let bin_of_proof = Irmin.Type.(unstage (to_bin_string tree_proof_t))
  let proof_of_bin = Irmin.Type.(unstage (of_bin_string tree_proof_t))
end

module Default = Make (Conf)
open Default

type bindings = string list list [@@deriving irmin]

let equal_ordered_slist ~msg l1 l2 = Alcotest.check_repr bindings_t msg l1 l2

let equal_slist ~msg l1 l2 =
  Alcotest.(check (slist (list string) Stdlib.compare)) msg l1 l2

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

let some_steps = [ "0g"; "1g"; "0h"; "2g"; "1h"; "2h" ]

let some_random_steps =
  [ [ "2g" ]; [ "1h" ]; [ "0h" ]; [ "2h" ]; [ "0g" ]; [ "1g" ] ]

let another_random_steps =
  [ [ "1g" ]; [ "2h" ]; [ "1h" ]; [ "0g" ]; [ "0h" ]; [ "2g" ] ]

let zero = String.make 10 '0'
let bindings steps = List.map (fun x -> ([ x ], zero)) steps

let test_fold ~order bindings expected =
  let tree = Tree.empty () in
  let* tree =
    Lwt_list.fold_left_s (fun tree (k, v) -> Tree.add tree k v) tree bindings
  in
  let* ctxt = persist_tree tree in
  let* keys =
    fold ~order ctxt.tree ~init:[] ~f:(fun k acc -> Lwt.return (k :: acc))
  in
  let keys = List.rev keys in
  let msg, equal_lists =
    match order with
    | `Sorted -> ("sorted", equal_ordered_slist)
    | `Random _ -> ("random", equal_ordered_slist)
    | `Undefined -> ("undefined", equal_slist)
  in
  equal_lists ~msg:(Fmt.str "Visit elements in %s order" msg) expected keys;
  close ctxt

let test_fold_sorted () =
  let bindings = bindings steps in
  let expected = List.map fst bindings in
  test_fold ~order:`Sorted bindings expected

let test_fold_random () =
  let bindings = bindings some_steps in
  let state = Random.State.make [| 0 |] in
  let* () = test_fold ~order:(`Random state) bindings some_random_steps in
  let state = Random.State.make [| 1 |] in
  test_fold ~order:(`Random state) bindings another_random_steps

let test_fold_undefined () =
  let bindings = bindings steps in
  let expected = List.map fst bindings in
  test_fold ~order:`Undefined bindings expected

let proof_of_bin s =
  match proof_of_bin s with Ok s -> s | Error (`Msg e) -> Alcotest.fail e

let check_equivalence tree proof op =
  match op with
  | Add (k, v) ->
      let* tree = Tree.add tree k v in
      let+ proof = Tree.add proof k v in
      Alcotest.(check_repr Store.Hash.t)
        (Fmt.str "same hash add %a" Fmt.(Dump.list string) k)
        (Tree.hash tree) (Tree.hash proof);
      (tree, proof)
  | Del k ->
      let* tree = Tree.remove tree k in
      let+ proof = Tree.remove proof k in
      Alcotest.(check_repr Store.Hash.t)
        (Fmt.str "same hash del %a" Fmt.(Dump.list string) k)
        (Tree.hash tree) (Tree.hash proof);
      (tree, proof)
  | Find k ->
      let* v_tree = Tree.find tree k in
      let+ v_proof = Tree.find proof k in
      Alcotest.(check (option string))
        (Fmt.str "same value at %a" Fmt.(Dump.list string) k)
        v_tree v_proof;
      (tree, proof)
  | Find_tree k ->
      let* v_tree = Tree.find_tree tree k in
      let+ v_proof = Tree.find_tree tree k in
      Alcotest.(check_repr [%typ: Store.tree option])
        (Fmt.str "same tree at %a" Fmt.(Dump.list string) k)
        v_tree v_proof;
      (tree, proof)

let test_proofs ctxt ops =
  let tree = ctxt.tree in
  let hash = Tree.hash tree in

  (* Create a compressed parital Merle proof for ops *)
  let* proof = proof_of_ops ctxt.repo (`Node hash) ops in

  (* test encoding *)
  let enc = bin_of_proof proof in
  let dec = proof_of_bin enc in
  Alcotest.(check_repr tree_proof_t) "same proof" proof dec;

  (* test equivalence *)
  let tree_proof = Tree.Proof.to_tree proof in

  Alcotest.(check_repr Store.Hash.t)
    "same initial hash" hash (Tree.hash tree_proof);

  let* _ =
    Lwt_list.fold_left_s
      (fun (tree, proof) op -> check_equivalence tree proof op)
      (tree, tree_proof)
      [
        Add ([ "00" ], "0");
        Add ([ "00" ], "1");
        Del [ "00" ];
        Find [ "00" ];
        Add ([ "00" ], "0");
        Add ([ "00" ], "1");
        Find [ "00" ];
        Find_tree [ "01" ];
        Find_tree [ "z"; "o"; "o" ];
      ]
  in
  Lwt.return_unit

let test_large_inode () =
  let bindings = bindings steps in
  let* ctxt = init_tree bindings in
  let ops = [ Add ([ "00" ], "3"); Del [ "01" ] ] in
  test_proofs ctxt ops

let fewer_steps =
["00"; "01"; "02"; "03"; "05"; "06"; "07"; "09"; "0a"; "0b"; "0c";
"0e"; "0f"; "10"; "11"; "12"; "13"; "14"; "15"; "16"; "17"; "19";
"1a"; "1b"; "1c"; "1d"; "1e"; "1f"; "20"; "22"; "23"; "25"; "26";
"27"; "28"; "2a"; ][@@ocamlformat "disable"]

let test_small_inode () =
  let bindings = bindings fewer_steps in
  let* ctxt = init_tree bindings in
  let ops = [ Add ([ "00" ], ""); Del [ "01" ] ] in
  test_proofs ctxt ops

let test_deeper_proof () =
  let* ctxt =
    let tree = Tree.empty () in
    let* level_one =
      let bindings = bindings fewer_steps in
      Lwt_list.fold_left_s (fun tree (k, v) -> Tree.add tree k v) tree bindings
    in
    let* level_two =
      let* tree = Tree.add_tree tree [ "0g" ] level_one in
      let bindings = bindings steps in
      Lwt_list.fold_left_s (fun tree (k, v) -> Tree.add tree k v) tree bindings
    in
    let* level_three =
      let* tree = Tree.add_tree tree [ "1g" ] level_two in
      let bindings = bindings fewer_steps in
      Lwt_list.fold_left_s (fun tree (k, v) -> Tree.add tree k v) tree bindings
    in
    persist_tree level_three
  in
  let ops =
    [
      Find [ "1g"; "0g"; "00" ];
      Del [ "1g"; "0g"; "01" ];
      Find [ "02" ];
      Find_tree [ "1g"; "02" ];
    ]
  in
  test_proofs ctxt ops

module Binary = Make (struct
  let entries = 2
  let stable_hash = 2
  let inode_child_order = `Hash_bits
end)

(* test large compressed proofs *)
let test_large_proofs () =
  (* Build a proof on a large store (branching factor = 32) *)
  let bindings = init_bindings 100_000 in
  let ops n =
    bindings
    |> List.to_seq
    |> Seq.take n
    |> Seq.map (fun (s, _) -> Find_tree s)
    |> List.of_seq
  in
  let* ctxt = init_tree bindings in

  let compare_proofs n =
    let ops = ops n in
    let* proof = proof_of_ops ctxt.repo (`Node (Tree.hash ctxt.tree)) ops in
    let enc_32 = bin_of_proof proof in

    (* Build a proof on a large store (branching factor = 2) *)
    let* ctxt = Binary.init_tree bindings in
    let* proof =
      Binary.proof_of_ops ctxt.repo (`Node (Binary.Tree.hash ctxt.tree)) ops
    in
    let enc_2 = Binary.bin_of_proof proof in

    Lwt.return (n, String.length enc_32 / 1024, String.length enc_2 / 1024)
  in
  let* a = compare_proofs 1 in
  let* b = compare_proofs 100 in
  let* c = compare_proofs 1_000 in
  let+ d = compare_proofs 10_000 in
  List.iter
    (fun (n, k32, k2) ->
      Fmt.pr "Size of Merkle proof for %d operations:\n" n;
      Fmt.pr "- Merkle B-trees (32 children): %dkB\n%!" k32;
      Fmt.pr "- binary Merkle trees         : %dkB\n%!" k2)
    [ a; b; c; d ]

module Custom = Make (struct
  let entries = 2
  let stable_hash = 2

  let index ~depth step =
    let ascii_code = Bytes.get step depth |> Char.code in
    ascii_code - 48

  let inode_child_order = `Custom index
end)

module P = Custom.Tree.Proof

let pp_proof = Irmin.Type.pp (P.t P.tree_t)
let pp_stream = Irmin.Type.pp (P.t P.stream_t)

let check_hash h s =
  let s' = Irmin.Type.(to_string Hash.t) h in
  Alcotest.(check string) "check hash" s s'

let check_contents_hash h s =
  match h with
  | `Node _ -> Alcotest.failf "Expected kinded hash to be contents"
  | `Contents (h, ()) ->
      let s' = Irmin.Type.(to_string Hash.t) h in
      Alcotest.(check string) "check hash" s s'

let bindings = [ ([ "00000" ], "x"); ([ "00001" ], "y"); ([ "00010" ], "z") ]

let test_extenders () =
  let bindings2 = ([ "10000" ], "x1") :: bindings in
  let bindings3 = ([ "10001" ], "y") :: bindings2 in

  let f t =
    let+ v = Custom.Tree.get t [ "00000" ] in
    Alcotest.(check string) "00000" "x" v;
    (t, ())
  in

  let check_proof bindings =
    let* ctxt = Custom.init_tree bindings in
    let hash = `Node (Custom.Tree.hash ctxt.tree) in
    let* p, () = Custom.Tree.produce_proof ctxt.repo hash f in
    Logs.debug (fun l -> l "Verifying proof %a" pp_proof p);
    let+ r = Custom.Tree.verify_proof p f in
    match r with
    | Ok (_, ()) -> ()
    | Error (`Msg e) -> Alcotest.failf "check_proof: %s" e
  in
  let* () = Lwt_list.iter_s check_proof [ bindings; bindings2; bindings3 ] in

  let check_stream bindings =
    let* ctxt = Custom.init_tree bindings in
    let hash = `Node (Custom.Tree.hash ctxt.tree) in
    let* p, () = Custom.Tree.produce_stream ctxt.repo hash f in
    Logs.debug (fun l -> l "Verifying stream %a" pp_stream p);
    let+ r = Custom.Tree.verify_stream p f in
    match r with
    | Ok (_, ()) -> ()
    | Error (`Msg e) -> Alcotest.failf "check_stream: %s" e
  in
  Lwt_list.iter_s check_stream [ bindings; bindings2; bindings3 ]

let test_hardcoded_stream () =
  let fail elt =
    Alcotest.failf "Unexpected elt in stream %a" (Irmin.Type.pp P.elt_t) elt
  in
  let* ctxt = Custom.init_tree bindings in
  let hash = `Node (Custom.Tree.hash ctxt.tree) in
  let f t =
    let+ v = Custom.Tree.get t [ "00000" ] in
    Alcotest.(check string) "00000" "x" v;
    (t, ())
  in
  let* p, () = Custom.Tree.produce_stream ctxt.repo hash f in
  let state = P.state p in
  let counter = ref 0 in
  Seq.iter
    (fun elt ->
      (match !counter with
      | 0 -> (
          match elt with
          | P.Inode_extender { length; segments = [ 0; 0; 0 ]; proof = h }
            when length = 3 ->
              check_hash h "77f92acef70dd91a9f5b260dc0bf249e6644d76b"
          | _ -> fail elt)
      | 1 -> (
          match elt with
          | P.Inode { length; proofs = [ (0, h1); (1, h0) ] } when length = 3 ->
              check_hash h0 "4295267989ab4c4a036eb78f0610a57042e2b49f";
              check_hash h1 "59fcb82bd392247a02237c716df77df35e885699"
          | _ -> fail elt)
      | 2 -> (
          match elt with
          | P.Node [ ("00000", h0); ("00001", h1) ] ->
              check_contents_hash h0 "11f6ad8ec52a2984abaafd7c3b516503785c2072";
              check_contents_hash h1 "95cb0bfd2977c761298d9624e4b4d4c72a39974a"
          | _ -> fail elt)
      | 3 -> ( match elt with P.Contents "x" -> () | _ -> fail elt)
      | _ -> fail elt);
      incr counter)
    state;
  if !counter <> 4 then Alcotest.fail "Not enough elements in the stream";
  Lwt.return_unit

let test_hardcoded_proof () =
  let fail_with_tree elt =
    Alcotest.failf "Unexpected elt in proof %a" (Irmin.Type.pp P.tree_t) elt
  in
  let fail_with_inode_tree elt =
    Alcotest.failf "Unexpected elt in proof %a"
      (Irmin.Type.pp P.inode_tree_t)
      elt
  in
  let* ctxt = Custom.init_tree bindings in
  let hash = `Node (Custom.Tree.hash ctxt.tree) in
  let f t =
    let+ v = Custom.Tree.get t [ "00000" ] in
    Alcotest.(check string) "00000" "x" v;
    (t, ())
  in
  let* p, () = Custom.Tree.produce_proof ctxt.repo hash f in
  let state = P.state p in

  let check_depth_2 = function
    | P.Inode_values
        [ ("00000", Contents ("x", ())); ("00001", Blinded_contents (h1, ())) ]
      ->
        check_hash h1 "95cb0bfd2977c761298d9624e4b4d4c72a39974a"
    | t -> fail_with_inode_tree t
  in
  let check_depth_1 = function
    | P.Inode_tree { length = 3; proofs = [ (0, t); (1, P.Blinded_inode h1) ] }
      ->
        check_hash h1 "4295267989ab4c4a036eb78f0610a57042e2b49f";
        check_depth_2 t
    | t -> fail_with_inode_tree t
  in
  let () =
    match (state : P.tree) with
    | P.Extender { length = 3; segments = [ 0; 0; 0 ]; proof = t } ->
        check_depth_1 t
    | _ -> fail_with_tree state
  in
  Lwt.return_unit

let tests =
  [
    Alcotest.test_case "fold over keys in sorted order" `Quick (fun () ->
        Lwt_main.run (test_fold_sorted ()));
    Alcotest.test_case "fold over keys in random order" `Quick (fun () ->
        Lwt_main.run (test_fold_random ()));
    Alcotest.test_case "fold over keys in undefined order" `Quick (fun () ->
        Lwt_main.run (test_fold_undefined ()));
    Alcotest.test_case "test Merkle proof for large inodes" `Quick (fun () ->
        Lwt_main.run (test_large_inode ()));
    Alcotest.test_case "test Merkle proof for small inodes" `Quick (fun () ->
        Lwt_main.run (test_small_inode ()));
    Alcotest.test_case "test deeper Merkle proof" `Quick (fun () ->
        Lwt_main.run (test_deeper_proof ()));
    Alcotest.test_case "test large Merkle proof" `Slow (fun () ->
        Lwt_main.run (test_large_proofs ()));
    Alcotest.test_case "test extenders in stream proof" `Quick (fun () ->
        Lwt_main.run (test_extenders ()));
    Alcotest.test_case "test hardcoded stream proof" `Quick (fun () ->
        Lwt_main.run (test_hardcoded_stream ()));
    Alcotest.test_case "test hardcoded proof" `Quick (fun () ->
        Lwt_main.run (test_hardcoded_proof ()));
  ]