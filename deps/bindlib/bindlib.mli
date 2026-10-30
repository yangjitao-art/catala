(** Free and bound variables for OCaml data structures.

    This module provides an API compatible with Bindlib 6.0.0, so that
    downstream code written against Bindlib can be linked against this
    implementation unchanged. The observable behaviour (fresh variable
    identifiers, names, replacement, alpha-equivalence, serialisation of
    names) is intended to match the reference implementation exactly. *)

(** {1 Variables} *)

type 'a var
(** A free variable whose injection into the term language has type ['a]. *)

type 'a mvar = 'a var array
(** An array of variables, used to bind several variables at once. *)

val name_of : 'a var -> string
(** Name attached to a variable (never changes after creation). *)

val names_of : 'a mvar -> string array
(** Names of an array of variables, in the same order. *)

val hash_var : 'a var -> int
(** Hash of a variable, consistent with {!eq_vars}. *)

val compare_vars : 'a var -> 'b var -> int
(** Total order over variables, consistent with {!eq_vars}. The order is
    intentionally descending on the internal identifier. *)

val eq_vars : 'a var -> 'b var -> bool
(** Identity of variables (based on their internal identifier). *)

val uid_of : 'a var -> int
(** Internal identifier of a variable. *)

val uids_of : 'a mvar -> int array
(** Internal identifiers of an array of variables. *)

val new_var : ('a var -> 'a) -> string -> 'a var
(** [new_var mkfree name] creates a variable with a fresh identifier, the
    given name, and the injection function [mkfree] used to turn the
    variable into a term. *)

val new_mvar : ('a var -> 'a) -> string array -> 'a mvar
(** [new_mvar mkfree names] creates one fresh variable per name. *)

val copy_var : 'b var -> ('a var -> 'a) -> string -> 'a var
(** [copy_var x mkfree name] creates a variable sharing the identifier of [x]
    but with a new name and injection function. *)

val reset_counter : unit -> unit
(** Resets the global identifier counter (mainly useful in tests). *)

(** {1 Boxes} *)

type +'a box
(** A term of type ['a] whose free variables are still available for binding.
    Boxes are built with {!box} and {!box_var}, combined with the [box_apply*]
    functions, and forced with {!unbox}. *)

val box : 'a -> 'a box
(** Wraps a closed value into a box. *)

val box_var : 'a var -> 'a box
(** The boxed representation of a variable. *)

val apply_box : ('a -> 'b) box -> 'a box -> 'b box
(** [apply_box f a] applies a boxed function to a boxed argument. *)

val box_apply : ('a -> 'b) -> 'a box -> 'b box
(** [box_apply f a] maps a function over a box. *)

val box_apply2 : ('a -> 'b -> 'c) -> 'a box -> 'b box -> 'c box

val box_apply3 :
  ('a -> 'b -> 'c -> 'd) -> 'a box -> 'b box -> 'c box -> 'd box

val box_apply4 :
  ('a -> 'b -> 'c -> 'd -> 'e) ->
  'a box ->
  'b box ->
  'c box ->
  'd box ->
  'e box

val box_pair : 'a box -> 'b box -> ('a * 'b) box
val box_triple : 'a box -> 'b box -> 'c box -> ('a * 'b * 'c) box
val box_opt : 'a box option -> 'a option box
val box_list : 'a box list -> 'a list box
val box_rev_list : 'a box list -> 'a list box
val box_array : 'a box array -> 'a array box

val unbox : 'a box -> 'a
(** Forces a box, substituting every free variable by its injected value. *)

val is_closed : 'a box -> bool
(** Whether the box is syntactically closed (constant-time check). *)

val occur : 'a var -> 'b box -> bool
(** Whether a variable is among the free variables of a box. *)

val dummy_box : 'a box
(** A box that fails when forced. *)

(** {1 Binders} *)

type ('a, 'b) binder
(** A term of type ['b] with one bound variable of type ['a]. *)

type ('a, 'b) mbinder
(** A term of type ['b] with several bound variables of type ['a]. *)

val bind_var : 'a var -> 'b box -> ('a, 'b) binder box
(** [bind_var x b] binds [x] in [b]. *)

val bind_mvar : 'a mvar -> 'b box -> ('a, 'b) mbinder box
(** [bind_mvar xs b] binds all variables in [xs] in [b]. *)

val unbind : ('a, 'b) binder -> 'a var * 'b
(** Opens a binder with a fresh variable. *)

val unbind2 : ('a, 'b) binder -> ('a, 'c) binder -> 'a var * 'b * 'c
(** Opens two binders in parallel with a common fresh variable. *)

val unmbind : ('a, 'b) mbinder -> 'a mvar * 'b
(** Opens a multi-binder with fresh variables. *)

val unmbind2 : ('a, 'b) mbinder -> ('a, 'c) mbinder -> 'a mvar * 'b * 'c
(** Opens two multi-binders in parallel with common fresh variables. *)

val subst : ('a, 'b) binder -> 'a -> 'b
(** [subst b v] replaces the bound variable of [b] by [v]. *)

val msubst : ('a, 'b) mbinder -> 'a array -> 'b
(** [msubst b vs] replaces the bound variables of [b] by [vs]. *)

val eq_binder : ('b -> 'b -> bool) -> ('a, 'b) binder -> ('a, 'b) binder -> bool
(** Alpha-equivalence of single binders. *)

val eq_mbinder :
  ('b -> 'b -> bool) -> ('a, 'b) mbinder -> ('a, 'b) mbinder -> bool
(** Alpha-equivalence of multi-binders. *)

val box_binder : ('b -> 'b box) -> ('a, 'b) binder -> ('a, 'b) binder box
(** Applies a boxed transformation under the binder. *)

val box_mbinder : ('b -> 'b box) -> ('a, 'b) mbinder -> ('a, 'b) mbinder box
(** Applies a boxed transformation under a multi-binder. *)

val bind_apply : ('a, 'b) binder box -> 'a box -> 'b box
val mbind_apply : ('a, 'b) mbinder box -> 'a array box -> 'b box

val binder_name : ('a, 'b) binder -> string
val binder_occur : ('a, 'b) binder -> bool
val binder_constant : ('a, 'b) binder -> bool
val binder_closed : ('a, 'b) binder -> bool
val binder_rank : ('a, 'b) binder -> int

val mbinder_arity : ('a, 'b) mbinder -> int
val mbinder_names : ('a, 'b) mbinder -> string array
val mbinder_occurs : ('a, 'b) mbinder -> bool array
val mbinder_constant : ('a, 'b) mbinder -> bool
val mbinder_closed : ('a, 'b) mbinder -> bool
val mbinder_rank : ('a, 'b) mbinder -> int

val raw_binder :
  string ->
  bool ->
  int ->
  ('a var -> 'a) ->
  ('a -> 'b) ->
  ('a, 'b) binder
(** Rebuilds a binder from its observable fields. *)

val raw_mbinder :
  string array ->
  bool array ->
  int ->
  ('a var -> 'a) ->
  ('a array -> 'b) ->
  ('a, 'b) mbinder
(** Rebuilds a multi-binder from its observable fields. *)

val binder_compose : ('a, 'b) binder -> ('b -> 'c) -> ('a, 'c) binder
val mbinder_compose : ('a, 'b) mbinder -> ('b -> 'c) -> ('a, 'c) mbinder

(** {1 Container lifting} *)

module type Map = sig
  type 'a t

  val map : ('a -> 'b) -> 'a t -> 'b t
end

module Lift (M : Map) : sig
  val lift_box : 'a box M.t -> 'a M.t box
end

module type Map2 = sig
  type ('a, 'b) t

  val map : ('a -> 'b) -> ('c -> 'd) -> ('a, 'c) t -> ('b, 'd) t
end

module Lift2 (M : Map2) : sig
  val lift_box : ('a box, 'b box) M.t -> ('a, 'b) M.t box
end

(** {1 Naming contexts} *)

type ctxt
(** A free-variable context used to pick fresh names when opening binders. *)

val empty_ctxt : ctxt

val free_vars : 'a box -> ctxt
(** Context reserving the names of the free variables of a box. *)

val reserve_name : string -> ctxt -> ctxt

val new_var_in : ctxt -> ('a var -> 'a) -> string -> 'a var * ctxt
(** [new_var_in c mkfree name] creates a variable with a name fresh in [c]. *)

val new_mvar_in :
  ctxt -> ('a var -> 'a) -> string array -> 'a mvar * ctxt

val unbind_in : ctxt -> ('a, 'b) binder -> 'a var * 'b * ctxt

val unbind2_in :
  ctxt -> ('a, 'b) binder -> ('a, 'c) binder -> 'a var * 'b * 'c * ctxt

val unmbind_in : ctxt -> ('a, 'b) mbinder -> 'a mvar * 'b * ctxt

val unmbind2_in :
  ctxt ->
  ('a, 'b) mbinder ->
  ('a, 'c) mbinder ->
  'a mvar * 'b * 'c * ctxt

module type Renaming = sig
  type ctxt

  val empty_ctxt : ctxt

  val reset_context_for_closed_terms : bool
  val skip_constant_binders : bool
  val constant_binder_name : string option

  val new_name : string -> ctxt -> string * ctxt
  val reserve_name : string -> ctxt -> ctxt
end

module Ctxt (R : Renaming) : sig
  include Renaming with type ctxt = R.ctxt

  val free_vars : 'a box -> ctxt
  val new_var_in : ctxt -> ('a var -> 'a) -> string -> 'a var * ctxt

  val new_mvar_in :
    ctxt -> ('a var -> 'a) -> string array -> 'a mvar * ctxt

  val unbind_in : ctxt -> ('a, 'b) binder -> 'a var * 'b * ctxt

  val unbind2_in :
    ctxt -> ('a, 'b) binder -> ('a, 'c) binder -> 'a var * 'b * 'c * ctxt

  val unmbind_in : ctxt -> ('a, 'b) mbinder -> 'a mvar * 'b * ctxt

  val unmbind2_in :
    ctxt ->
    ('a, 'b) mbinder ->
    ('a, 'c) mbinder ->
    'a mvar * 'b * 'c * ctxt
end
