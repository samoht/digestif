let () = Printexc.record_backtrace true

type _ s =
  | Bytes : Bytes.t s
  | String : String.t s
  | Bigstring : bigstring s
and bigstring = (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

let title
  : type a k. [ `HMAC | `Digest ] -> k Digestif.hash -> a s -> string
  = fun computation hash input ->
  let pp_computation ppf = function
    | `HMAC -> Fmt.string ppf "hmac"
    | `Digest -> Fmt.string ppf "digest" in
  let pp_hash : type k. k Digestif.hash Fmt.t = fun ppf -> function
    | Digestif.MD5 -> Fmt.string ppf "md5"
    | Digestif.SHA1 -> Fmt.string ppf "sha1"
    | Digestif.RMD160 -> Fmt.string ppf "rmd160"
    | Digestif.SHA224 -> Fmt.string ppf "sha224"
    | Digestif.SHA256 -> Fmt.string ppf "sha256"
    | Digestif.SHA384 -> Fmt.string ppf "sha384"
    | Digestif.SHA512 -> Fmt.string ppf "sha512"
    | Digestif.BLAKE2B _ -> Fmt.string ppf "blake2b"
    | Digestif.BLAKE2S _ -> Fmt.string ppf "blake2s" in
  let pp_input : type a. a s Fmt.t = fun ppf -> function
    | Bytes -> Fmt.string ppf "bytes"
    | String -> Fmt.string ppf "string"
    | Bigstring -> Fmt.string ppf "bigstring" in
  Fmt.strf "%a:%a:%a"
    pp_computation computation
    pp_hash hash
    pp_input input

let bytes = Bytes
let string = String
let bigstring = Bigstring

let test_hmac
  : type k a. a s -> k Digestif.hash -> a -> a -> k Digestif.t -> unit
  = fun kind hash key input expect ->
    let title = title `HMAC hash kind in
    let test_hash = Alcotest.testable (Digestif.pp hash) (Digestif.eq hash) in

    match kind with
    | Bytes ->
      let result = Digestif.hmaci_bytes hash ~key (fun f -> f input) in
      Alcotest.(check test_hash) title expect result
    | String ->
      let result = Digestif.hmaci_string hash ~key (fun f -> f input) in
      Alcotest.(check test_hash) title expect result
    | Bigstring ->
      let result = Digestif.hmaci_bigstring hash ~key (fun f -> f input) in
      Alcotest.(check test_hash) title expect result

let test_digest
  : type k a. a s -> k Digestif.hash -> a -> k Digestif.t -> unit
  = fun kind hash input expect ->
    let title = title `Digest hash kind in
    let test_hash = Alcotest.testable (Digestif.pp hash) (Digestif.eq hash) in

    match kind with
    | Bytes ->
      let result = Digestif.digesti_bytes hash (fun f -> f input) in
      Alcotest.(check test_hash) title expect result
    | String ->
      let result = Digestif.digesti_string hash (fun f -> f input) in
      Alcotest.(check test_hash) title expect result
    | Bigstring ->
      let result = Digestif.digesti_bigstring hash (fun f -> f input) in
      Alcotest.(check test_hash) title expect result

let make_hmac
  : type a k. name:string -> a s -> k Digestif.hash -> a -> a -> k Digestif.t -> unit Alcotest.test_case
  = fun ~name kind hash key input expect ->
    name, `Slow, (fun () -> test_hmac kind hash key input expect)

let make_digest
  : type a k. name:string -> a s -> k Digestif.hash -> a -> k Digestif.t -> unit Alcotest.test_case
  = fun ~name kind hash input expect ->
    name, `Slow, (fun () -> test_digest kind hash input expect)

let combine a b c =
  let rec aux r a b c = match a, b, c with
    | xa :: ra, xb :: rb, xc :: rc ->
      aux ((xa, xb, xc) :: r) ra rb rc
    | [], [], [] -> List.rev r
    | _ -> raise (Invalid_argument "combine")
  in
  aux [] a b c

let makes ~name kind hash keys inputs expects =
  List.map (fun (key, input, expect) -> make_hmac ~name kind hash key input expect)
    (combine keys inputs expects)

let to_bigstring s =
  let ln = Bytes.length s in
  let bi = Bigarray.Array1.create Bigarray.Char Bigarray.c_layout ln in

  for i = 0 to ln - 1
  do Bigarray.Array1.set bi i (Bytes.get s i) done; bi

let split3 lst =
  let rec go (ax, ay, az) = function
    | (x, y, z) :: r -> go (x :: ax, y :: ay, z :: az) r
    | [] -> List.rev ax, List.rev ay, List.rev az in
  go ([], [], []) lst

let keys_by, keys_st, keys_bi =
  [ "Salut"
  ; "Jefe"
  ; "Lorenzo"
  ; "Le son qui fait plaiz'"
  ; "La c'est un peu chaud en vrai"]
  |> List.map (fun s -> Bytes.unsafe_of_string s, s, to_bigstring (Bytes.unsafe_of_string s))
  |> split3

let inputs_by, inputs_st, inputs_bi =
  [ "Hi There"
  ; "what do ya want for nothing?"
  ; "C'est Lolo je bois de l'Ice Tea quand j'suis fonsde"
  ; "Mes pecs dansent le flamenco, Lolo l'empereur du sale, dans le deal on \
    m'surnomme Joe La Crapule"
  ; "Y'a un pack de douze a cote du cadavre dans le coffre. Pourquoi t'etais \
    Charlie mais t'etais pas Jean-Pierre Coffe. Ca sniffe tellement la coke, \
    mes crottes de nez c'est d'la MD. J'deteste juste les keufs, j'aime bien \
    les obeses et les pedes. Mamene finira dans le dico'. J'ai qu'un reuf: le \
    poto Rico. Ca rotte-ca l'argent des clodos. C'est moi qu'ecrit tous les \
    pornos. Cite-moi en controle de philo'. Toutes les miss grimpent aux \
    rideaux." ]
  |> List.map (fun s -> Bytes.unsafe_of_string s, s, to_bigstring (Bytes.unsafe_of_string s))
  |> split3

let results_md5 =
  [ "689e721d493b6eeea482947be736c808"
  ; "750c783e6ab0b503eaa86e310a5db738"
  ; "1cdd24eef6163afee7adc7c53dd6c9df"
  ; "0316ebcad933675e84a81850e24d55b2"
  ; "9ee938a2659d546ccc2e5993601964eb" ]
  |> List.map (Digestif.of_hex Digestif.md5)

let results_sha1 =
  [ "b0a6490a6fcb9479a7aa2306ecb56730d6225dba"
  ; "effcdf6ae5eb2fa2d27416d5f184df9c259a7c79"
  ; "d80589525b1cc9f5e5ffd48ffd73d710ac89a3f1"
  ; "0a5212b295e11a1de5c71873e70ce54f45119516"
  ; "deaf6465e5945a0d04cba439c628ee9f47b95aef" ]
  |> List.map (Digestif.of_hex Digestif.sha1)

let results_sha224 =
  [ "9a26f1380aae8c580441676891765c8a647ddf16a7d12fa427090901"
  ; "a30e01098bc6dbbf45690f3a7e9e6d0f8bbea2a39e6148008fd05e44"
  ; "b94a09654fc749ae6cb21c7765bf4938ff9af03e13d83fbf23342ce7"
  ; "7c66e4c7297a22ca80e2e1db9774afea64b1e086be366d2da3e6bc83"
  ; "438dc3311243cd54cc7ee24c9aac8528a1750abc595f06e68a331d2a" ]
  |> List.map (Digestif.of_hex Digestif.sha224)

let results_sha256 =
  [ "2178f5f21b4311607bf9347bcde5f6552edb9ec5aa13b954d53de2fbfd8b75de"
  ; "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
  ; "aa36cd61caddefe26b07ba1d3d07ea978ed575c9d1f921837dff9f73e019713e"
  ; "a7c8b53d68678a8e6e4d403c6b97cf0f82c4ef7b835c41039c0a73aa4d627d05"
  ; "b2a83b628f7e0da71c3879b81075775072d0d35935c62cc6c5a79b337ccccca1" ]
  |> List.map (Digestif.of_hex Digestif.sha256)

let results_sha384 =
  [ "43e75797c1d875c5e5e7e90d0525061703d6b95b6137461566c2d067304458e62c144bbe12c0b741dcfaa38f7d41575e"
  ; "af45d2e376484031617f78d2b58a6b1b9c7ef464f5a01b47e42ec3736322445e8e2240ca5e69e2c78b3239ecfab21649"
  ; "bd3b5c82edcd0f206aadff7aa89dbbc3a7655844ffc9f8f9fa17c90eb36b13ec7828fba7252c3f5d90cff666ea44d557"
  ; "16461c2a44877c69fb38e4dce2edc822d68517917fc84d252de64132bd43c7cbe3310b7e8661741b7728000e8abf51e0"
  ; "2c3751d1dc792344514928fad94672a256cf2f66344e4df96b0cc4cc3f6800aa5a628e9becf5f65672e1acf013284893" ]
  |> List.map (Digestif.of_hex Digestif.sha384)

let results_sha512 =
  [ "5f26752be4a1282646ed8c6a611d4c621e22e3fa96e9e6bc9e19a86deaacf0315151c46f779c3184632ab5793e2ddcb2ff87ca11cc886130f033364b08aef4e2"
  ; "164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea2505549758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737"
  ; "c2f2077f538171d7c6cbee0c94948f82987117a50229fb0b48a534e3c63553a9a9704cdb460c597c8b46b631e49c22a9d2d46bded40f8a77652f754ec725e351"
  ; "89d7284e89642ec195f7a8ef098ef4e411fa3df17a07724cf13033bc6b7863968aad449cee973df9b92800d803ba3e14244231a86253cfacd1de882a542e945f"
  ; "f6ecfca37d2abcff4b362f1919629e784c4b618af77e1061bb992c11d7f518716f5df5978b0a1455d68ceeb10ced9251306d2f26181407be76a219d48c36b592" ]
  |> List.map (Digestif.of_hex Digestif.sha512)

let results_blake2b =
  [ "aba2eef053923ba3a671b54244580ca7c8dfa9c487431c3437e1a8504e166ed894778045a5c6a314fadee110a5254f6f370e9db1d3093a62e0448a5e91b1d4c6"
  ; "6ff884f8ddc2a6586b3c98a4cd6ebdf14ec10204b6710073eb5865ade37a2643b8807c1335d107ecdb9ffeaeb6828c4625ba172c66379efcd222c2de11727ab4"
  ; "42aadab231ff4edbdad29a18262bbb6ba74cf0850f40b64a92dc62a92608a65f06af850aa1988cd1e379cf9cc9a8f64d61125d7b3def292ae57e537bc202e812"
  ; "4abf562dc64f4062ea59ae9b4e2061a7a6c1a75af74b3663fd05aa4437420b8deea657e395a7dbac02aef7b7d70dc8b8a8db99aa8db028961a5ee66bac22b0f0"
  ; "69f9e4236cd0c50204e4f8b86dc1751d37cc195835e9db25c9b366f41e1d86cdeec6a8702dfed1bc0ed0d6a1e2c5af275c331ec91f884c979021fb64021915de" ]
  |> List.map (Digestif.of_hex (Digestif.blake2b Digestif.BLAKE2B.digest_size))

let results_rmd160 =
  [ "65b3cb3360881842a0d454bd6e7bc1bfe838b384"
  ; "dda6c0213a485a9e24f4742064a7f033b43c4069"
  ; "f071dcd2514fd89de78a5a2db1128dfa3e54d503"
  ; "bda5511e63389385218a8d902a70f2d8dc4dc074"
  ; "6c2486f169432281b6d71ae5b6765239c3cc1ea6" ]
  |> List.map (Digestif.of_hex Digestif.rmd160)

let results_blake2s =
  [ "5bb23bbe41678b23e6d38881d2515fdf5df253dd2e9a80075ea759c93e1bca3a"
  ; "90b6281e2f3038c9056af0b4a7e763cae6fe5d9eb4386a0ec95237890c104ff0"
  ; "5d0064cb2848ab5dc948876a6be3e5685301a744735c25858c0bd283a7940eb7"
  ; "6903efd2383b13adaa985d00ca271ccb420ab8f953841081c9c15a2dfebf866c"
  ; "b8e167de23a5f136dc26bf06da0d724ebf7310903c2f702403b66810a230d622" ]
  |> List.map (Digestif.of_hex (Digestif.blake2s Digestif.BLAKE2S.digest_size))

module BLAKE2 =
struct
  let input_blake2b_file = "./blake2b.test"
  let input_blake2s_file = "./blake2s.test"

  let fold_s f a s =
    let r = ref a in
    String.iter (fun x -> r := f !r x) s; !r

  let of_hex len hex =
    let code x = match x with
      | '0' .. '9' -> Char.code x - 48
      | 'A' .. 'F' -> Char.code x - 55
      | 'a' .. 'z' -> Char.code x - 87
      | _ -> raise (Invalid_argument "of_hex") in

    let wsp = function ' ' | '\t' | '\r' | '\n' -> true | _ -> false in

    fold_s
      (fun (res, i, acc) -> function
         | chr when wsp chr -> (res, i, acc)
         | chr ->
           match acc, code chr with
           | None, x -> (res, i, Some (x lsl 4))
           | Some y, x -> Bytes.set res i (Char.unsafe_chr (x lor y)); (res, succ i, None))
      (Bytes.create len, 0, None)
      hex
    |> (function
        | (_, _, Some _)  -> invalid_arg "of_hex"
        | (res, i, _) ->
           if i = len
           then res
           else (for i = i to len - 1
                 do Bytes.set res i '\000' done; res))
    |> Bytes.unsafe_to_string

  let downcast : type k. k Digestif.t -> string = fun x -> (x :> string)

  let parse kind ic =
    ignore @@ input_line ic;
    ignore @@ input_line ic;

    let rec loop state acc = match state, input_line ic with
      | `In, line ->
        let i = ref "" in
        Scanf.sscanf line "in:\t%s" (fun v -> i := of_hex (String.length v / 2) v);
        loop (`Key !i) acc
      | `Key i, line ->
        let k = ref None in
        Scanf.sscanf line "key:\t%s" (fun v -> k := Some (downcast @@ Digestif.of_hex kind v));
        (match !k with Some k -> loop (`Hash (i, (k :> string))) acc | None -> loop `In acc)
      | `Hash (i, k), line ->
        let h = ref None in
        Scanf.sscanf line "hash:\t%s" (fun v -> h := Some (Digestif.of_hex kind v));
        (match !h with Some h -> loop (`Res (i, k, h)) acc | None -> loop `In acc)
      | `Res v, "" ->
        loop `In (v :: acc)
      | `Res v, _ -> (* avoid malformed line *)
        loop (`Res v) acc
      | exception End_of_file -> List.rev acc in

    loop `In []

  let test_mac
    : type k a. a s -> k Digestif.hash -> (module Digestif.MAC) -> a -> a -> k Digestif.t -> unit
    = fun kind hash (module Mac) key input expect ->
    let title = title `HMAC hash kind in
    let check (result : Mac.t) =
      Alcotest.(check string)
        title
        (expect :> string)
        (result :> string)
    in
    match kind with
    | Bytes -> check @@ Mac.maci_bytes ~key (fun f -> f input)
    | String -> check @@ Mac.maci_string ~key (fun f -> f input)
    | Bigstring -> check @@ Mac.maci_bigstring ~key (fun f -> f input)

  let make_keyed_blake m ~name kind hash key input expect =
  name, `Slow, (fun () -> test_mac kind hash m key input expect)

  let tests m  kind filename =
    let ic = open_in filename in
    let tests = parse kind ic in

    close_in ic;
    List.map
      (fun (input, key, expect) -> make_keyed_blake m ~name:"blake2{b,s}" string kind key input expect)
      tests

  let tests_blake2s =
    tests
      (module Digestif.BLAKE2S.Keyed)
      Digestif.(blake2s BLAKE2S.digest_size)
      input_blake2s_file

  let tests_blake2b =
    tests
      (module Digestif.BLAKE2B.Keyed)
      Digestif.(blake2b BLAKE2B.digest_size)
      input_blake2b_file
end

module RMD160 =
struct
  let inputs =
    [ ""
    ; "a"
    ; "abc"
    ; "message digest"
    ; "abcdefghijklmnopqrstuvwxyz"
    ; "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    ; "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    ; "12345678901234567890123456789012345678901234567890123456789012345678901234567890" ]

  let expects =
    [ "9c1185a5c5e9fc54612808977ee8f548b2258d31"
    ; "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe"
    ; "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
    ; "5d0689ef49d2fae572b881b123a85ffa21595f36"
    ; "f71c27109c692c1b56bbdceb5b9d2865b3708dbc"
    ; "12a053384a9c0c88e405a06c27dcf49ada62eb2b"
    ; "b0e20b6e3116640286ed3a87a5713079b21f5189"
    ; "9b752e45573d4b39f4dbd3323cab82bf63326bfb" ]

  let million : type t. expect:[ `RMD160 ] Digestif.t -> unit Alcotest.test_case
    = fun ~expect ->
      let iter n f =
        let rec go = function
          | 0 -> ()
          | n -> f "a"; go (n - 1) in
        go n in
      let result = Digestif.digesti_string Digestif.rmd160 (iter 1_000_000) in
      let test_hash = Alcotest.testable Digestif.(pp rmd160) Digestif.(eq rmd160) in

      "give me a million", `Slow, (fun () -> Alcotest.(check test_hash) "rmd160" expect result)

  let tests =
    let expect_million = Digestif.of_hex Digestif.rmd160 "52783243c1697bdbe16d37f97f68f08325dc1528" in

    List.map (fun (input, expect) -> make_digest ~name:"rmd160" string Digestif.rmd160 input expect)
      (List.combine inputs (List.map Digestif.(of_hex rmd160) expects))
    @ [ million ~expect:expect_million ]
end

let tests () =
  Alcotest.run "digestif"
    [ "md5",                 makes ~name:"md5"     bytes     Digestif.md5     keys_by inputs_by results_md5
    ; "md5 (bigstring)",     makes ~name:"md5"     bigstring Digestif.md5     keys_bi inputs_bi results_md5
    ; "sha1",                makes ~name:"sha1"    bytes     Digestif.sha1    keys_by inputs_by results_sha1
    ; "sha1 (bigstring)",    makes ~name:"sha1"    bigstring Digestif.sha1    keys_bi inputs_bi results_sha1
    ; "sha224",              makes ~name:"sha224"  bytes     Digestif.sha224  keys_by inputs_by results_sha224
    ; "sha224 (bigstring)",  makes ~name:"sha224"  bigstring Digestif.sha224  keys_bi inputs_bi results_sha224
    ; "sha256",              makes ~name:"sha256"  bytes     Digestif.sha256  keys_by inputs_by results_sha256
    ; "sha256 (bigstring)",  makes ~name:"sha256"  bigstring Digestif.sha256  keys_bi inputs_bi results_sha256
    ; "sha384",              makes ~name:"sha384"  bytes     Digestif.sha384  keys_by inputs_by results_sha384
    ; "sha384 (bigstring)",  makes ~name:"sha384"  bigstring Digestif.sha384  keys_bi inputs_bi results_sha384
    ; "sha512",              makes ~name:"sha512"  bytes     Digestif.sha512  keys_by inputs_by results_sha512
    ; "sha512 (bigstring)",  makes ~name:"sha512"  bigstring Digestif.sha512  keys_bi inputs_bi results_sha512
    ; "blake2b",             makes ~name:"blake2b" bytes     Digestif.(blake2b BLAKE2B.digest_size) keys_by inputs_by results_blake2b
    ; "blake2b (bigstring)", makes ~name:"blake2b" bigstring Digestif.(blake2b BLAKE2B.digest_size) keys_bi inputs_bi results_blake2b
    ; "rmd160",              makes ~name:"rmd160"  bytes     Digestif.rmd160  keys_by inputs_by results_rmd160
    ; "rmd160 (bigstring)",  makes ~name:"rmd160"  bigstring Digestif.rmd160  keys_bi inputs_bi results_rmd160
    ; "blake2s",             makes ~name:"blake2s" bytes     Digestif.(blake2s BLAKE2S.digest_size) keys_by inputs_by results_blake2s
    ; "blake2s (bigstring)", makes ~name:"blake2s" bigstring Digestif.(blake2s BLAKE2S.digest_size) keys_bi inputs_bi results_blake2s
    ; "blake2s (keyed, input file)", BLAKE2.tests_blake2s
    ; "blake2b (keyed, input file)", BLAKE2.tests_blake2b
    ; "ripemd160", RMD160.tests ]

let () = tests ()
