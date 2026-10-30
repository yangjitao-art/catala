(* An independent implementation of the Bindlib API, version 6.0.0, written
   against the public interface and documented observable behaviour. It is a
   drop-in replacement: the module name, signatures, naming policy, identifier
   allocation and evaluation strategy all follow the reference semantics. *)

let reset_counter, fresh_key =
  let counter = ref (-1) in
  ( (fun () -> counter := -1),
    fun () ->
      incr counter;
      !counter )

module Int_key = struct
  type t = int

  let compare x y = x - y
end

module IMap = Map.Make (Int_key)
module SMap = Map.Make (String)

(* Heterogeneous environment used while substituting variables. Each cell is
   written and read at a single type, which makes the use of [Obj] safe. *)

module Env = struct
  type t = {slots : Obj.t array; mutable next_free : int}

  let create next_free size = {slots = Array.make size (Obj.repr ()); next_free}
  let set env i v = Array.set env.slots i (Obj.repr v)
  let get i env = Obj.obj (Array.get env.slots i)
  let blit src dst len = Array.blit src.slots 0 dst.slots 0 len
  let copy env = {slots = Array.copy env.slots; next_free = env.next_free}
  let get_next_free env = env.next_free
  let set_next_free env i = env.next_free <- i
end

type varpos = int IMap.t
type 'a closure = varpos -> Env.t -> 'a

type 'a box =
  | Box of 'a
  | Env of any_var list * int * 'a closure

and 'a var = {
  var_key : int;
  var_name : string;
  var_mkfree : 'a var -> 'a;
  var_box : 'a box;
}

and any_var = V : 'a var -> any_var
[@@unboxed]

let map_closure f cl vp =
  let g = cl vp in
  fun env -> f (g env)

let app_closure cl a vp =
  let f = cl vp in
  fun env -> f env a

let ( <*> ) cf ca vp =
  let f = cf vp and a = ca vp in
  fun env -> f env (a env)

let name_of x = x.var_name
let names_of xs = Array.map name_of xs
let hash_var x = Hashtbl.hash (`HVar, x.var_key)
let box_var x = x.var_box
let compare_vars x y = y.var_key - x.var_key
let eq_vars x y = x.var_key = y.var_key
let uid_of x = x.var_key
let uids_of xs = Array.map uid_of xs

type 'a mvar = 'a var array

(* The free-variable lists carried by [Env] are sorted by identifier and
   duplicate-free. *)

let merge_uniq l1 l2 =
  let rec go acc l1 l2 =
    match l1, l2 with
    | [], _ -> List.rev_append acc l2
    | _, [] -> List.rev_append acc l1
    | (V x as vx) :: xs, (V y as vy) :: ys ->
      if x.var_key = y.var_key then go (vx :: acc) xs ys
      else if x.var_key < y.var_key then go (vx :: acc) xs l2
      else go (vy :: acc) l1 ys
  in
  go [] l1 l2

let remove x vs =
  let rec go acc = function
    | (V y as v) :: rest when y.var_key < x.var_key -> go (v :: acc) rest
    | (V y) :: rest when y.var_key = x.var_key -> List.rev_append acc rest
    | _ -> raise Not_found
  in
  go [] vs

(* [minimize vs n cl] re-normalises a closure so that it only depends on the
   variables of [vs], placed in the first slots of a fresh environment that
   also reserves [n] trailing slots. *)

let minimize vs n cl =
  if n = 0 then cl
  else
    fun vp ->
      let size = List.length vs in
      let slots = Array.make size 0 in
      let contiguous = ref true in
      let gather (new_vp, i) (V x) =
        let j = IMap.find x.var_key vp in
        if i <> j then contiguous := false;
        slots.(i) <- j;
        (IMap.add x.var_key i new_vp, i + 1)
      in
      let new_vp, _ = List.fold_left gather (IMap.empty, 0) vs in
      let body = cl new_vp in
      if !contiguous then
        fun env ->
          let new_env = Env.create size (size + n) in
          Env.blit env new_env size;
          body new_env
      else
        fun env ->
          let new_env = Env.create size (size + n) in
          Array.iteri (fun i j -> Env.set new_env i (Env.get j env)) slots;
          body new_env

let box x = Box x

let apply_box f a =
  match f, a with
  | Box f, Box a -> Box (f a)
  | Box f, Env (va, na, ta) -> Env (va, na, map_closure f ta)
  | Env (vf, nf, tf), Box a -> Env (vf, nf, app_closure tf a)
  | Env (vf, nf, tf), Env (va, na, ta) ->
    Env (merge_uniq vf va, 0, minimize vf nf tf <*> minimize va na ta)

let occur v b =
  match b with
  | Box _ -> false
  | Env (vs, _, _) -> List.exists (fun (V x) -> x.var_key = v.var_key) vs

let is_closed b = match b with Box _ -> true | Env _ -> false

let box_apply f a =
  match a with
  | Box a -> Box (f a)
  | Env (vs, n, t) -> Env (vs, n, map_closure f t)

let box_apply2 f a b = apply_box (box_apply f a) b
let box_apply3 f a b c = apply_box (box_apply2 f a b) c
let box_apply4 f a b c d = apply_box (box_apply3 f a b c) d
let box_pair x y = box_apply2 (fun x y -> (x, y)) x y
let box_triple x y z = box_apply3 (fun x y z -> (x, y, z)) x y z

let box_opt = function
  | None -> box None
  | Some e -> box_apply (fun e -> Some e) e

let dummy_box : 'a box = Env ([], 0, fun _ -> failwith "Invalid use of dummy_box")

let unbox b =
  match b with
  | Box t -> t
  | Env (vs, n, t) ->
    let k = List.length vs in
    let env = Env.create k (k + n) in
    let next = ref 0 in
    let store vp (V x) =
      let i = !next in
      incr next;
      Env.set env i (x.var_mkfree x);
      IMap.add x.var_key i vp
    in
    t (List.fold_left store IMap.empty vs) env

(* Combining several boxes into a container: gather the free variables and the
   number of reserved slots, then evaluate every component against a shared
   environment. *)

let no_data = (true, [], 0)

let gather_data data b =
  match b, data with
  | Box _, _ -> data
  | Env (vs, n, _), (_, ws, m) -> (false, merge_uniq ws vs, max m n)

let box_to_closure b =
  match b with Box t -> (fun _ _ -> t) | Env (vs, n, t) -> minimize vs n t

module type Map = sig
  type 'a t

  val map : ('a -> 'b) -> 'a t -> 'b t
end

module Lift (M : Map) = struct
  let apply_all m env = M.map (fun cl -> cl env) m

  let lift_box m =
    let data = ref no_data in
    let to_closure b =
      data := gather_data !data b;
      box_to_closure b
    in
    let closures = M.map to_closure m in
    let aux vp =
      let bound = M.map (fun cl -> cl vp) closures in
      apply_all bound
    in
    match !data with
    | true, _, _ -> Box (aux IMap.empty (Env.create 0 0))
    | _, vs, n -> Env (vs, n, minimize vs n aux)
end

module type Map2 = sig
  type ('a, 'b) t

  val map : ('a -> 'b) -> ('c -> 'd) -> ('a, 'c) t -> ('b, 'd) t
end

module Lift2 (M : Map2) = struct
  let apply_all m env =
    M.map (fun cl -> cl env) (fun cl -> cl env) m

  let lift_box m =
    let data = ref no_data in
    let to_closure b =
      data := gather_data !data b;
      box_to_closure b
    in
    let closures = M.map to_closure to_closure m in
    let aux vp =
      let bound = M.map (fun cl -> cl vp) (fun cl -> cl vp) closures in
      apply_all bound
    in
    match !data with
    | true, _, _ -> Box (aux IMap.empty (Env.create 0 0))
    | _, vs, n -> Env (vs, n, minimize vs n aux)
end

module Lift_list = Lift (struct
  type 'a t = 'a list

  let map = List.map
end)

module Lift_rev_list = Lift (struct
  type 'a t = 'a list

  let map = List.rev_map
end)

module Lift_array = Lift (struct
  type 'a t = 'a array

  let map = Array.map
end)

let box_list = Lift_list.lift_box
let box_rev_list = Lift_rev_list.lift_box
let box_array = Lift_array.lift_box

(* Binders *)

type ('a, 'b) binder = {
  b_name : string;
  b_bind : bool;
  b_rank : int;
  b_mkfree : 'a var -> 'a;
  b_value : 'a -> 'b;
}

let binder_name b = b.b_name
let subst b x = b.b_value x
let binder_occur b = b.b_bind
let binder_constant b = not b.b_bind
let binder_closed b = b.b_rank = 0
let binder_rank b = b.b_rank
let binder_compose b f = {b with b_value = (fun x -> f (b.b_value x))}

type ('a, 'b) mbinder = {
  mb_names : string array;
  mb_binds : bool array;
  mb_rank : int;
  mb_mkfree : 'a var -> 'a;
  mb_value : 'a array -> 'b;
}

let mbinder_arity b = Array.length b.mb_names
let mbinder_names b = b.mb_names
let msubst b xs = b.mb_value xs
let mbinder_occurs b = b.mb_binds
let mbinder_constant b = not (Array.fold_left ( || ) false b.mb_binds)
let mbinder_closed b = b.mb_rank = 0
let mbinder_rank b = b.mb_rank
let mbinder_compose b f = {b with mb_value = (fun x -> f (b.mb_value x))}

let raw_binder b_name b_bind b_rank b_mkfree b_value =
  {b_name; b_bind; b_rank; b_mkfree; b_value}

let raw_mbinder mb_names mb_binds mb_rank mb_mkfree mb_value =
  {mb_names; mb_binds; mb_rank; mb_mkfree; mb_value}

let bind_apply b arg = box_apply2 subst b arg
let mbind_apply b args = box_apply2 msubst b args

(* Variables *)

let build_var_aux key vp = Env.get (IMap.find key vp)

let build_var var_key var_mkfree name =
  let rec x =
    let var_box = Env ([V x], 0, build_var_aux var_key) in
    {var_key; var_name = name; var_mkfree; var_box}
  in
  x

let new_var mkfree name = build_var (fresh_key ()) mkfree name
let new_mvar mkfree names = Array.map (fun n -> new_var mkfree n) names
let copy_var x mkfree name = build_var x.var_key mkfree name

let unbind b =
  let x = new_var b.b_mkfree b.b_name in
  (x, subst b (b.b_mkfree x))

let unbind2 b1 b2 =
  let x = new_var b1.b_mkfree b1.b_name in
  let v = b1.b_mkfree x in
  (x, subst b1 v, subst b2 v)

let eq_binder eq f g =
  f == g ||
  let _, t, u = unbind2 f g in
  eq t u

let unmbind b =
  let xs = new_mvar b.mb_mkfree b.mb_names in
  (xs, msubst b (Array.map b.mb_mkfree xs))

let unmbind2 b1 b2 =
  if mbinder_arity b1 <> mbinder_arity b2 then
    invalid_arg "Arity mismatch in unmbind2";
  let xs = new_mvar b1.mb_mkfree b1.mb_names in
  let vs = Array.map b1.mb_mkfree xs in
  (xs, msubst b1 vs, msubst b2 vs)

let eq_mbinder eq f g =
  f == g
  || mbinder_arity f = mbinder_arity g
     &&
     let _, t, u = unmbind2 f g in
     eq t u

(* Single-variable binding *)

let build_binder x rank bind value =
  {
    b_name = x.var_name;
    b_rank = rank;
    b_bind = bind;
    b_value = value;
    b_mkfree = x.var_mkfree;
  }

let bind_var_aux1 n t arg =
  let env = Env.create 1 (n + 1) in
  Env.set env 0 arg;
  t env

let bind_var_aux2 rank t env arg =
  let next = Env.get_next_free env in
  if next = rank then begin
    Env.set_next_free env (next + 1);
    Env.set env next arg;
    t env
  end
  else begin
    let env = Env.copy env in
    Env.set_next_free env (rank + 1);
    for i = rank + 1 to next - 1 do
      Env.set env i 0
    done;
    Env.set env rank arg;
    t env
  end

let bind_var_aux3 x rank t env =
  let value = bind_var_aux2 rank t env in
  build_binder x rank true value

let bind_var_aux4 t env _ = t env

let bind_var_aux5 x rank t env =
  let value = bind_var_aux4 t env in
  build_binder x rank false value

let bind_var x b =
  match b with
  | Box t -> Box (build_binder x 0 false (fun _ -> t))
  | Env (vs, n, t) -> (
    try
      match vs with
      | [V y] when x.var_key = y.var_key ->
        let t = t (IMap.singleton x.var_key 0) in
        Box (build_binder x 0 true (bind_var_aux1 n t))
      | _ ->
        let vs = remove x vs in
        let rank = List.length vs in
        let cl vp =
          let t = t (IMap.add x.var_key rank vp) in
          bind_var_aux3 x rank t
        in
        Env (vs, n + 1, cl)
    with Not_found ->
      Env
        ( vs,
          n,
          fun vp ->
            let t = t vp in
            bind_var_aux5 x (List.length vs) t ))

let box_binder f b =
  if binder_closed b then box b
  else
    let x, t = unbind b in
    bind_var x (f t)

(* Multi-variable binding *)

let check_arity xs args =
  if Array.length xs <> Array.length args then invalid_arg "Bad arity in msubst"

let bind_mvar_aux0 xs t args =
  check_arity xs args;
  t

let bind_mvar_aux1 m xs binds t args =
  check_arity xs args;
  let env = Env.create 0 m in
  let pos = ref 0 in
  for i = 0 to Array.length xs - 1 do
    if binds.(i) then begin
      Env.set env !pos args.(i);
      incr pos
    end
  done;
  Env.set_next_free env !pos;
  t env

let bind_mvar_aux2 xs t env args =
  check_arity xs args;
  t env

let bind_mvar_aux3 xs t names rank binds mkfree env =
  let value = bind_mvar_aux2 xs t env in
  {
    mb_names = names;
    mb_rank = rank;
    mb_binds = binds;
    mb_value = value;
    mb_mkfree = mkfree;
  }

let bind_mvar_aux4 xs t rank binds env args =
  check_arity xs args;
  let next = Env.get_next_free env in
  let cur = ref rank in
  let fill env =
    for i = 0 to Array.length xs - 1 do
      if binds.(i) then begin
        Env.set env !cur args.(i);
        incr cur
      end
    done
  in
  if next = rank then begin
    fill env;
    Env.set_next_free env !cur;
    t env
  end
  else begin
    let env = Env.copy env in
    fill env;
    Env.set_next_free env !cur;
    for i = !cur to next - 1 do
      Env.set env i 0
    done;
    t env
  end

let bind_mvar_aux5 xs t names rank binds mkfree env =
  let value = bind_mvar_aux4 xs t rank binds env in
  {
    mb_names = names;
    mb_rank = rank;
    mb_binds = binds;
    mb_value = value;
    mb_mkfree = mkfree;
  }

let bind_mvar xs b =
  let arity = Array.length xs in
  let mkfree =
    if arity > 0 then xs.(0).var_mkfree else fun _ -> assert false
  in
  match b with
  | Box t ->
    let binds = Array.make arity false in
    let names = Array.map name_of xs in
    Box
      {
        mb_names = names;
        mb_rank = 0;
        mb_binds = binds;
        mb_value = bind_mvar_aux0 xs t;
        mb_mkfree = mkfree;
      }
  | Env (vs0, n, t) ->
    let keys = Array.make arity 0 in
    let vs = ref vs0 in
    let m = ref n in
    for i = arity - 1 downto 0 do
      let x = xs.(i) in
      match remove x !vs with
      | vs' ->
        vs := vs';
        incr m;
        keys.(i) <- x.var_key
      | exception Not_found -> keys.(i) <- -1
    done;
    let vs = !vs and m = !m in
    if vs = [] then begin
      let names = Array.map name_of xs in
      let cur = ref 0 in
      let vp = ref IMap.empty in
      let binds =
        Array.mapi
          (fun _ key ->
            if key >= 0 then begin
              vp := IMap.add key !cur !vp;
              incr cur;
              true
            end
            else false)
          keys
      in
      let t = t !vp in
      Box
        {
          mb_names = names;
          mb_rank = 0;
          mb_binds = binds;
          mb_value = bind_mvar_aux1 m xs binds t;
          mb_mkfree = mkfree;
        }
    end
    else if m = n then
      let cl vp =
        let rank = List.length vs in
        let binds = Array.make arity false in
        let names = Array.map name_of xs in
        let t = t vp in
        bind_mvar_aux3 xs t names rank binds mkfree
      in
      Env (vs, n, cl)
    else
      let cl vp =
        let rank = List.length vs in
        let names = Array.map name_of xs in
        let cur = ref rank in
        let vp = ref vp in
        let binds =
          Array.mapi
            (fun _ key ->
              if key >= 0 then begin
                vp := IMap.add key !cur !vp;
                incr cur;
                true
              end
              else false)
            keys
        in
        let t = t !vp in
        bind_mvar_aux5 xs t names rank binds mkfree
      in
      Env (vs, m, cl)

let box_mbinder f b =
  if b.mb_rank = 0 then box b
  else
    let xs, t = unmbind b in
    bind_mvar xs (f t)

(* Naming policies *)

module type Renaming = sig
  type ctxt

  val empty_ctxt : ctxt

  val reset_context_for_closed_terms : bool
  val skip_constant_binders : bool
  val constant_binder_name : string option

  val new_name : string -> ctxt -> string * ctxt
  val reserve_name : string -> ctxt -> ctxt
end

module Ctxt (R : Renaming) = struct
  include R

  let free_vars b =
    match b with
    | Box _ -> empty_ctxt
    | Env (vs, _, _) ->
      List.fold_left
        (fun c (V x) -> reserve_name (name_of x) c)
        empty_ctxt vs

  let new_var_in ctxt mkfree name =
    let fresh, ctxt = new_name name ctxt in
    (new_var mkfree fresh, ctxt)

  let new_mvar_in ctxt mkfree names =
    let ctxt = ref ctxt in
    let make name =
      let v, c = new_var_in !ctxt mkfree name in
      ctxt := c;
      v
    in
    (Array.map make names, !ctxt)

  let reset_ctxt closed ctxt =
    if reset_context_for_closed_terms && closed then empty_ctxt else ctxt

  let unbind_var constant mkfree name ctxt =
    match constant, skip_constant_binders, constant_binder_name with
    | true, _, Some s -> (new_var mkfree s, ctxt)
    | true, true, None -> (fst (new_var_in ctxt mkfree name), ctxt)
    | _ -> new_var_in ctxt mkfree name

  let unbind_in ctxt b =
    let ctxt = reset_ctxt (binder_closed b) ctxt in
    let x, ctxt =
      unbind_var (binder_constant b) b.b_mkfree b.b_name ctxt
    in
    (x, subst b (b.b_mkfree x), ctxt)

  let unbind2_in ctxt b1 b2 =
    let ctxt = reset_ctxt (binder_closed b1 && binder_closed b2) ctxt in
    let x, ctxt =
      unbind_var
        (binder_constant b1 && binder_constant b2)
        b1.b_mkfree b1.b_name ctxt
    in
    let v = b1.b_mkfree x in
    (x, subst b1 v, subst b2 v, ctxt)

  let unmbind_in ctxt b =
    let ctxt = reset_ctxt (mbinder_closed b) ctxt in
    let ctxt = ref ctxt in
    let xs =
      Array.mapi
        (fun i name ->
          let constant = not b.mb_binds.(i) in
          let x, c = unbind_var constant b.mb_mkfree name !ctxt in
          ctxt := c;
          x)
        b.mb_names
    in
    (xs, msubst b (Array.map b.mb_mkfree xs), !ctxt)

  let unmbind2_in ctxt b1 b2 =
    let ctxt = reset_ctxt (mbinder_closed b1 && mbinder_closed b2) ctxt in
    let ctxt = ref ctxt in
    let binds2 = b2.mb_binds in
    let n2 = Array.length binds2 in
    let xs =
      Array.mapi
        (fun i name ->
          let constant =
            (not b1.mb_binds.(i)) && (i >= n2 || not binds2.(i))
          in
          let x, c = unbind_var constant b1.mb_mkfree name !ctxt in
          ctxt := c;
          x)
        b1.mb_names
    in
    let vs = Array.map b1.mb_mkfree xs in
    (xs, msubst b1 vs, msubst b2 vs, !ctxt)
end

(* Default renaming policy: names are split into a prefix and a decimal
   suffix, and suffixes are allocated monotonically per prefix. Leading zeroes
   belong to the prefix, so "v0042" is the pair ("v00", 42). *)

include Ctxt (struct
  type ctxt = int SMap.t

  let empty_ctxt = SMap.empty

  let reset_context_for_closed_terms = false
  let skip_constant_binders = false
  let constant_binder_name = None

  let split_name name =
    let len = String.length name in
    let is_digit c = c >= '0' && c <= '9' in
    let first_digit = ref len in
    let first_non_zero = ref len in
    while !first_digit > 0 && is_digit name.[!first_digit - 1] do
      decr first_digit;
      if name.[!first_digit] <> '0' then first_non_zero := !first_digit
    done;
    let i = !first_non_zero in
    if i = len then (name, 0)
    else (String.sub name 0 i, int_of_string (String.sub name i (len - i)))

  let get_suffix prefix suffix ctxt =
    let used = try SMap.find prefix ctxt with Not_found -> -1 in
    let suffix = if suffix > used then suffix else used + 1 in
    (suffix, SMap.add prefix suffix ctxt)

  let merge_name prefix suffix =
    if suffix > 0 then prefix ^ string_of_int suffix else prefix

  let new_name name ctxt =
    let prefix, suffix = split_name name in
    let suffix, ctxt = get_suffix prefix suffix ctxt in
    (merge_name prefix suffix, ctxt)

  let reserve_name name ctxt =
    let prefix, suffix = split_name name in
    match SMap.find_opt prefix ctxt with
    | Some used when suffix <= used -> ctxt
    | _ -> SMap.add prefix suffix ctxt
end)
